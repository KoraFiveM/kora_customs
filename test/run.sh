#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
lua test/catalog.lua
lua test/server.lua
