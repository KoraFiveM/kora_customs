#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
lua test/catalog.lua
lua test/camera.lua
lua test/hornconfig.lua
lua test/pauseconfig.lua
lua test/server.lua
lua test/selfrepair.lua
