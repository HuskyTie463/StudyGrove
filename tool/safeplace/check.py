"""
Safeplace — local secret-leak checker for Study Grove.

Prints file path + secret TYPE only. Never prints values.
Does not upload anything. --serve binds 127.0.0.1 only.

From the repo root:

    python tool/safeplace/check.py
    python tool/safeplace/check.py --serve

Then open http://127.0.0.1:8765
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Split so this file is not itself a hit for the patterns it searches.
ANT_PREFIX = "sk-" + "ant-"
PROJ_PREFIX = "sk-" + "proj-"
SVC_TYPE = '"type": "service_account"'

ANTHROPIC_RE = re.compile(re.escape(ANT_PREFIX) + r"[A-Za-z0-9_-]{24,}")
OPENAI_RE = re.compile(r"sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}")
PEM_RE = re.compile(
    r"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?" + re.escape("PRIVATE KEY-----")
)
AWS_RE = re.compile(r"AKIA[0-9A-Z]{16}")
GITHUB_RE = re.compile(r"(?:ghp|gho|ghu|ghs)_[A-Za-z0-9]{20,}")
GITHUB_FINE_RE = re.compile(r"github_pat_[A-Za-z0-9_]{20,}")
STRIPE_LIVE_RE = re.compile(r"sk_live_[A-Za-z0-9]{16,}")
STRIPE_TEST_RE = re.compile(r"sk_test_[A-Za-z0-9]{16,}")
GOOGLE_OAUTH_RE = re.compile(r"GOCSPX-[A-Za-z0-9_-]{10,}")
FIREBASE_RE = re.compile(r"AIzaSy[A-Za-z0-9_-]{20,}")
SVC_TYPE_RE = re.compile(r'"type"\s*:\s*"service_account"')
SVC_PK_RE = re.compile(r'"private_key"\s*:')

SIGNING_EXTS = {
    ".p8",
    ".p12",
    ".pfx",
    ".key",
    ".mobileprovision",
    ".provisionprofile",
    ".cer",
    ".certsigningrequest",
}
BINARY_EXTS = {
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".a",
    ".apk",
    ".aab",
    ".ipa",
    ".snapshot",
}
SKIP_DIRS = {
    ".git",
    ".dart_tool",
    ".pub-cache",
    ".pub",
    ".venv",
    "node_modules",
    "pods",
    "ephemeral",
    "cmakefiles",
    "obj",
    ".idea",
    ".vs",
    "coverage",
}
SKIP_FILES = {"flutter_windows.dll", "flutter_windows.dll.pdb"}
SKIP_DIR_PARTS = {
    "extracted",
    "firebase_cpp_sdk_windows",
    "firebase_cpp_sdk",
    "intermediates",
    "gradle",
    ".plugin_symlinks",
}
MAX_TEXT = 8 * 1024 * 1024
MAX_BIN = 40 * 1024 * 1024

FIREBASE_NOTE = (
    "Expected in apps. Protect data with Firestore rules + API restrictions."
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def rel(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def skip_dir(name: str) -> bool:
    n = name.lower()
    return n in SKIP_DIRS or n.startswith("cmakefiles")


def signing_type(ext: str) -> str:
    return {
        ".p8": "Apple AuthKey / .p8 private key file",
        ".p12": "PKCS#12 signing certificate (.p12)",
        ".pfx": "PKCS#12 signing certificate (.p12)",
        ".mobileprovision": "Apple provisioning profile",
        ".provisionprofile": "Apple provisioning profile",
        ".cer": "Apple certificate (.cer)",
        ".key": "Private key file (.key)",
        ".certsigningrequest": "Certificate signing request",
    }.get(ext, f"Signing material ({ext})")


class Finding:
    def __init__(
        self,
        path: str,
        type: str,
        where: str,
        severity: str = "critical",
        note: str | None = None,
    ) -> None:
        self.path = path
        self.type = type
        self.where = where
        self.severity = severity
        self.note = note

    @property
    def key(self) -> str:
        return f"{self.severity}|{self.type}|{self.path}|{self.where}"

    def as_dict(self) -> dict:
        d = {
            "path": self.path,
            "type": self.type,
            "where": self.where,
            "severity": self.severity,
        }
        if self.note:
            d["note"] = self.note
        return d


class Report:
    def __init__(
        self, root: str, findings: list[Finding], scanned_files: int, scanned_binaries: int
    ) -> None:
        self.root = root
        self.findings = findings
        self.scanned_files = scanned_files
        self.scanned_binaries = scanned_binaries

    @property
    def has_critical(self) -> bool:
        return any(f.severity == "critical" for f in self.findings)

    def to_plain_text(self) -> str:
        lines = [
            "Safeplace scan  (values are never printed)",
            f"Root: {self.root}",
            f"Scanned {self.scanned_files} text files, {self.scanned_binaries} binaries/artifacts.",
            "",
        ]
        if not self.findings:
            lines.append("No matching secrets found.")
            return "\n".join(lines) + "\n"
        crit = [f for f in self.findings if f.severity == "critical"]
        info = [f for f in self.findings if f.severity != "critical"]
        if crit:
            lines.append("CRITICAL — extractable / signing material")
            for f in crit:
                lines.append(f"  {f.type}  in  {f.path}  [{f.where}]")
                if f.note:
                    lines.append(f"    {f.note}")
            lines.append("")
        if info:
            lines.append("INFO — expected in client apps (not Apple/AI private keys)")
            for f in info:
                lines.append(f"  {f.type}  in  {f.path}  [{f.where}]")
                if f.note:
                    lines.append(f"    {f.note}")
        return "\n".join(lines) + "\n"

    def to_json(self) -> dict:
        return {
            "root": self.root,
            "scannedFiles": self.scanned_files,
            "scannedBinaries": self.scanned_binaries,
            "hasCritical": self.has_critical,
            "findings": [f.as_dict() for f in self.findings],
        }


def walk_files(root: Path) -> list[Path]:
    out: list[Path] = []

    def rec(d: Path) -> None:
        try:
            entries = list(d.iterdir())
        except OSError:
            return
        for p in entries:
            name = p.name
            if p.is_dir():
                if skip_dir(name) or name.lower() in SKIP_DIR_PARTS:
                    continue
                rec(p)
                continue
            if not p.is_file():
                continue
            if name.lower() in SKIP_FILES:
                continue
            if name.lower().endswith((".pdb", ".ilk", ".obj", ".map.json", ".symbols")):
                continue
            out.append(p)

    rec(root)
    bundled = root / ".bundled_keys"
    if bundled.is_file():
        out.append(bundled)
    return out


def looks_like_key_tail(data: bytes, start: int, min_len: int) -> bool:
    n = 0
    for i in range(start, min(len(data), start + min_len + 8)):
        c = data[i]
        if not (48 <= c <= 57 or 65 <= c <= 90 or 97 <= c <= 122 or c in (45, 95)):
            break
        n += 1
    return n >= min_len


def find_ascii(data: bytes, needle: bytes):
    start = 0
    while True:
        i = data.find(needle, start)
        if i < 0:
            return
        yield i
        start = i + 1


def scan_bytes(data: bytes, path: str, where: str, add) -> None:
    ant = ANT_PREFIX.encode()
    proj = PROJ_PREFIX.encode()
    for i in find_ascii(data, ant):
        if looks_like_key_tail(data, i + len(ant), 24):
            add(Finding(path, "Anthropic API key", where))
            break
    for i in find_ascii(data, proj):
        if looks_like_key_tail(data, i + len(proj), 24):
            add(Finding(path, "OpenAI API key", where))
            break
    sk = b"sk-"
    for i in find_ascii(data, sk):
        if data.startswith(ant, i) or data.startswith(proj, i):
            continue
        if looks_like_key_tail(data, i + 3, 32):
            add(Finding(path, "OpenAI-like API key", where))
            break
    if b"BEGIN PRIVATE KEY" in data or b"BEGIN RSA PRIVATE KEY" in data:
        add(Finding(path, "PEM private key", where))
    for i in find_ascii(data, b"AIzaSy"):
        if looks_like_key_tail(data, i + 6, 20):
            add(
                Finding(
                    path,
                    "Firebase / Google client API key",
                    where,
                    severity="info",
                    note=FIREBASE_NOTE,
                )
            )
            break


def only_anthropic_sk(text: str) -> bool:
    hits = list(OPENAI_RE.finditer(text))
    if not hits:
        return True
    return all(m.group(0).startswith(ANT_PREFIX) for m in hits)


def scan_text(text: str, path: str, where: str, add) -> None:
    if ANTHROPIC_RE.search(text):
        add(Finding(path, "Anthropic API key", where))
    if OPENAI_RE.search(text) and not only_anthropic_sk(text):
        add(Finding(path, "OpenAI API key", where))
    if PEM_RE.search(text):
        add(Finding(path, "PEM private key", where))
    if SVC_TYPE_RE.search(text) and SVC_PK_RE.search(text):
        add(Finding(path, "Google service-account JSON (private_key)", where))
    elif SVC_PK_RE.search(text) and PEM_RE.search(text):
        add(Finding(path, "JSON private_key field", where))
    if AWS_RE.search(text):
        add(Finding(path, "AWS access key id", where))
    if GITHUB_RE.search(text) or GITHUB_FINE_RE.search(text):
        add(Finding(path, "GitHub personal access token", where))
    if STRIPE_LIVE_RE.search(text):
        add(Finding(path, "Stripe live secret key", where))
    if STRIPE_TEST_RE.search(text):
        add(Finding(path, "Stripe test secret key", where))
    if GOOGLE_OAUTH_RE.search(text):
        add(Finding(path, "Google OAuth client secret", where))
    if FIREBASE_RE.search(text):
        add(
            Finding(
                path,
                "Firebase / Google client API key",
                where,
                severity="info",
                note=FIREBASE_NOTE,
            )
        )


def git(root: Path, args: list[str]) -> str:
    try:
        r = subprocess.run(
            ["git", *args],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
    except OSError:
        return ""
    if r.returncode not in (0, 1):
        return ""
    return r.stdout


def scan_git_history(root: Path, add) -> None:
    if not (root / ".git").exists():
        return
    # Literal pickaxe (no -p): filenames only, values never printed.
    probes = [
        (ANT_PREFIX + "api", "Anthropic API key"),
        (PROJ_PREFIX, "OpenAI API key"),
        ("BEGIN PRIVATE KEY", "PEM private key"),
        (SVC_TYPE, "Google service-account JSON (private_key)"),
    ]
    for needle, typ in probes:
        out = git(
            root,
            ["log", "--all", "-S", needle, "--name-only", "--pretty=format:"],
        )
        for line in out.splitlines():
            path = line.strip()
            if path:
                add(Finding(path, typ, "git history"))
    out = git(
        root,
        [
            "log",
            "--all",
            "--name-only",
            "--pretty=format:",
            "--",
            "*.p8",
            "*.p12",
            "*.pfx",
            "*.mobileprovision",
            "*.provisionprofile",
        ],
    )
    for line in out.splitlines():
        path = line.strip()
        if path:
            add(Finding(path, signing_type(Path(path).suffix.lower()), "git history (filename tracked)"))


def should_scan_binary(rel_path: str, ext: str) -> bool:
    if ext in BINARY_EXTS:
        lower = rel_path.lower()
        if "/cmakefiles/" in lower or "/obj/" in lower:
            return False
        # Engine / plugin noise — still scan the app binary and app.so.
        if ext == ".dll" and not any(
            x in lower for x in ("/runner/release/", "/runner/debug/", "studygrove")
        ):
            if "flutter_windows" in lower:
                return False
        return True
    name = Path(rel_path).name.lower()
    if name in {"studygrove", "flutter_organiser"}:
        return True
    return False


def scan(root: Path) -> Report:
    seen: set[str] = set()
    findings: list[Finding] = []

    def add(f: Finding) -> None:
        if f.key not in seen:
            seen.add(f.key)
            findings.append(f)

    text_n = 0
    bin_n = 0
    files = walk_files(root)
    for path in files:
        rpath = rel(root, path)
        ext = path.suffix.lower()
        if ext in SIGNING_EXTS:
            add(Finding(rpath, signing_type(ext), "working tree (file present)"))
            continue
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if should_scan_binary(rpath, ext) or path.name.lower() == "kernel_blob.bin":
            bin_n += 1
            if size > MAX_BIN:
                continue
            try:
                data = path.read_bytes()
            except OSError:
                continue
            scan_bytes(data, rpath, "built artifact", add)
            continue
        if size > MAX_TEXT:
            continue
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if b"\x00" in data[:4096]:
            bin_n += 1
            scan_bytes(data, rpath, "binary", add)
            continue
        text_n += 1
        text = data.decode("utf-8", errors="replace")
        scan_text(text, rpath, "working tree", add)

    scan_git_history(root, add)
    findings.sort(key=lambda f: (f.severity, f.type, f.path, f.where))
    return Report(str(root), findings, text_n, bin_n)


def html_report(report: Report) -> str:
    def esc(s: str) -> str:
        return (
            s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    rows = []
    for f in report.findings:
        cls = "crit" if f.severity == "critical" else "info"
        note = f'<div class="note">{esc(f.note)}</div>' if f.note else ""
        rows.append(
            f'<tr class="{cls}"><td>{esc(f.severity)}</td>'
            f"<td>{esc(f.type)}{note}</td><td><code>{esc(f.path)}</code></td>"
            f"<td>{esc(f.where)}</td></tr>"
        )
    empty = "<p>No matching secrets found.</p>" if not report.findings else ""
    table = (
        ""
        if not report.findings
        else (
            "<table><thead><tr><th>Level</th><th>Type</th><th>Path</th><th>Where</th></tr></thead>"
            f"<tbody>{''.join(rows)}</tbody></table>"
        )
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Safeplace</title>
<style>
  body {{ font-family: ui-sans-serif, system-ui, sans-serif; margin: 2rem; background: #0f1410; color: #e8efe6; }}
  h1 {{ font-size: 1.4rem; }}
  .sub {{ color: #9aab96; margin-bottom: 1.5rem; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ text-align: left; padding: .5rem .6rem; border-bottom: 1px solid #2a3328; vertical-align: top; }}
  code {{ font-size: .9rem; }}
  tr.crit td:first-child {{ color: #ffb4a8; }}
  tr.info td:first-child {{ color: #9ad4aa; }}
  .note {{ color: #9aab96; font-size: .85rem; margin-top: .25rem; }}
</style>
</head>
<body>
  <h1>Safeplace</h1>
  <p class="sub">Local leak check. Types and paths only — values are never shown. This page is 127.0.0.1 only.</p>
  <p>Scanned {report.scanned_files} text files and {report.scanned_binaries} binaries under <code>{esc(report.root)}</code>.</p>
  {empty}
  {table}
</body>
</html>"""


def serve(report: Report) -> None:
    payload_html = html_report(report).encode("utf-8")
    payload_json = json.dumps(report.to_json()).encode("utf-8")

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args) -> None:
            return

        def do_GET(self) -> None:  # noqa: N802
            if self.path.startswith("/report.json"):
                body, ctype = payload_json, "application/json; charset=utf-8"
            else:
                body, ctype = payload_html, "text/html; charset=utf-8"
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

    httpd = None
    port = None
    for p in (8765, 8766, 8767):
        try:
            httpd = ThreadingHTTPServer(("127.0.0.1", p), Handler)
            port = p
            break
        except OSError:
            continue
    if httpd is None or port is None:
        print("Could not bind 127.0.0.1:8765-8767", file=sys.stderr)
        sys.exit(2)
    print(f"Safeplace is local-only. Open http://127.0.0.1:{port}/")
    print("Stop with Ctrl+C. Nothing is uploaded.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Safeplace local leak checker")
    parser.add_argument(
        "--serve",
        action="store_true",
        help="Serve the report on http://127.0.0.1:8765 (localhost only)",
    )
    args = parser.parse_args()
    root = repo_root()
    print("Scanning... (values are never printed)", file=sys.stderr)
    report = scan(root)
    if args.serve:
        print(report.to_plain_text())
        serve(report)
        return
    sys.stdout.write(report.to_plain_text())
    sys.exit(1 if report.has_critical else 0)


if __name__ == "__main__":
    main()
