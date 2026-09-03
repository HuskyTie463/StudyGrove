"""Study Grove AI proxy. Provider keys stay on this machine — never in the app."""

from __future__ import annotations

import json
import os
import time
import urllib.request
from typing import Any

import httpx
import jwt
from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware

PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "study-app-18492").strip()
CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)

_cert_cache: dict[str, Any] = {"certs": None, "exp": 0.0}

app = FastAPI(title="Study Grove AI proxy", docs_url=None, redoc_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _load_env_file() -> None:
    path = os.path.join(os.path.dirname(__file__), ".env")
    if not os.path.isfile(path):
        return
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = val


_load_env_file()
PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", PROJECT_ID).strip() or PROJECT_ID


def _certs() -> dict[str, str]:
    now = time.time()
    cached = _cert_cache["certs"]
    if isinstance(cached, dict) and now < float(_cert_cache["exp"]):
        return cached
    with urllib.request.urlopen(CERTS_URL, timeout=12) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        max_age = 3600.0
        cc = resp.headers.get("Cache-Control", "")
        for part in cc.split(","):
            part = part.strip()
            if part.startswith("max-age="):
                try:
                    max_age = float(part[8:])
                except ValueError:
                    pass
    _cert_cache["certs"] = data
    _cert_cache["exp"] = now + max(60.0, max_age)
    return data


def verify_firebase_token(token: str) -> dict[str, Any]:
    try:
        header = jwt.get_unverified_header(token)
        kid = header.get("kid")
        certs = _certs()
        pem = certs.get(kid) if isinstance(kid, str) else None
        if not pem:
            raise HTTPException(status_code=401, detail="Sign-in token was not recognised.")
        return jwt.decode(
            token,
            pem,
            algorithms=["RS256"],
            audience=PROJECT_ID,
            issuer=f"https://securetoken.google.com/{PROJECT_ID}",
        )
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Sign in again to use Study AI.") from None


async def require_user(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    if not auth.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sign in required.")
    token = auth.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Sign in required.")
    claims = verify_firebase_token(token)
    uid = claims.get("sub")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(status_code=401, detail="Sign in required.")
    return uid


def _need(name: str) -> str:
    val = os.environ.get(name, "").strip()
    if not val:
        raise HTTPException(
            status_code=503,
            detail="Study AI is not configured on the server yet.",
        )
    return val


@app.get("/health")
async def health() -> dict[str, str]:
    return {"ok": "true", "service": "studygrove-ai-proxy"}


@app.post("/v1/openai/chat/completions")
async def openai_chat(request: Request, _uid: str = Depends(require_user)) -> Response:
    key = _need("OPENAI_API_KEY")
    body = await request.body()
    async with httpx.AsyncClient(timeout=120.0) as client:
        res = await client.post(
            "https://api.openai.com/v1/chat/completions",
            content=body,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
        )
    return Response(
        content=res.content,
        status_code=res.status_code,
        media_type=res.headers.get("content-type", "application/json"),
    )


@app.post("/v1/anthropic/messages")
async def anthropic_messages(request: Request, _uid: str = Depends(require_user)) -> Response:
    key = _need("ANTHROPIC_API_KEY")
    body = await request.body()
    headers = {
        "x-api-key": key,
        "anthropic-version": request.headers.get("anthropic-version", "2023-06-01"),
        "Content-Type": "application/json",
    }
    beta = request.headers.get("anthropic-beta")
    if beta:
        headers["anthropic-beta"] = beta
    async with httpx.AsyncClient(timeout=180.0) as client:
        res = await client.post(
            "https://api.anthropic.com/v1/messages",
            content=body,
            headers=headers,
        )
    return Response(
        content=res.content,
        status_code=res.status_code,
        media_type=res.headers.get("content-type", "application/json"),
    )


@app.post("/v1/openai/audio/speech")
async def openai_speech(request: Request, _uid: str = Depends(require_user)) -> Response:
    key = _need("OPENAI_API_KEY")
    body = await request.body()
    async with httpx.AsyncClient(timeout=120.0) as client:
        res = await client.post(
            "https://api.openai.com/v1/audio/speech",
            content=body,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
        )
    return Response(
        content=res.content,
        status_code=res.status_code,
        media_type=res.headers.get("content-type", "audio/mpeg"),
    )


@app.post("/v1/openai/realtime/sessions")
async def openai_realtime_session(
    request: Request, _uid: str = Depends(require_user)
) -> Response:
    key = _need("OPENAI_API_KEY")
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    body = {
        "model": payload.get("model") or "gpt-realtime",
        "voice": payload.get("voice") or "sage",
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        res = await client.post(
            "https://api.openai.com/v1/realtime/sessions",
            json=body,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
                "OpenAI-Beta": "realtime=v1",
            },
        )
    return Response(
        content=res.content,
        status_code=res.status_code,
        media_type=res.headers.get("content-type", "application/json"),
    )
