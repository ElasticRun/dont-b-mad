#!/usr/bin/env python3
"""Idempotently merges the AIEye stop hook into ~/.cursor/hooks.json."""
import json
import os
import sys

if len(sys.argv) != 3:
    print(
        "Usage: register-cursor-aieye-stop-hook.py <hooks_json_path> <hook_bin_path>",
        file=sys.stderr,
    )
    sys.exit(1)

hooks_path = sys.argv[1]
hook_cmd = os.path.abspath(sys.argv[2])

data = {"version": 1, "hooks": {}}
if os.path.exists(hooks_path):
    with open(hooks_path, encoding="utf-8") as f:
        data = json.load(f)

data.setdefault("version", 1)
if data.get("version") != 1:
    data["version"] = 1

hooks = data.setdefault("hooks", {})
stop_hooks = hooks.get("stop")
if not isinstance(stop_hooks, list):
    stop_hooks = []
    hooks["stop"] = stop_hooks

for entry in stop_hooks:
    if not isinstance(entry, dict):
        continue
    cmd = entry.get("command", "")
    if cmd and "aieye-live-hook" in cmd:
        print("already registered")
        sys.exit(0)

stop_hooks.append({"command": hook_cmd})

parent = os.path.dirname(os.path.abspath(hooks_path))
if parent:
    os.makedirs(parent, exist_ok=True)
with open(hooks_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("registered")
