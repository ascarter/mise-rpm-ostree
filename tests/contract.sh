#!/usr/bin/env bash
set -euo pipefail

luac -p metadata.lua lib/rpm_ostree.lua hooks/*.lua
grep -Fq 'requires = ["rpm-ostree", "rpm"]' mise.plugin.toml
grep -Fq 'supports_version_pins = false' mise.plugin.toml
grep -Fq 'os = ["linux"]' mise.plugin.toml

if rg -n 'sudo|--apply-live|reboot' hooks lib; then
  echo 'forbidden command found in implementation' >&2
  exit 1
fi

test "$(rg -l 'function PLUGIN:Package' hooks | wc -l | tr -d ' ')" = 4
