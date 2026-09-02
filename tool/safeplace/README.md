# Safeplace

Local leak checker for Study Grove. Reports **secret type + file path only**. It never prints key values, and it does not upload anything.

From the repo root:

```
python tool/safeplace/check.py
```

Local browser report (listens on 127.0.0.1 only — not the public internet):

```
python tool/safeplace/check.py --serve
```

Then open http://127.0.0.1:8765

Dart equivalent (avoid `dart run` here — that triggers Flutter plugin build hooks):

```
dart tool/safeplace/check.dart
dart tool/safeplace/check.dart --serve
```

Exit code `1` means a critical finding (API keys, PEM, `.p8` / `.p12`). Firebase client keys are listed as info; they are expected in apps.
