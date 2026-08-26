#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
xattr -cr "$DIR/StudyGrove.app" >/dev/null 2>&1
open "$DIR/StudyGrove.app"
