#!/usr/bin/env python3
"""Idempotently merges the AIEye post-skill Stop hook into ~/.claude/settings.json."""
import json, os, sys

if len(sys.argv) != 3:
    print("Usage: register-post-skill-hook.py <settings_path> <hook_bin_path>", file=sys.stderr)
    sys.exit(1)

settings_path = sys.argv[1]
hook_cmd = sys.argv[2]

data = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        data = json.load(f)

stop_hooks = data.setdefault("hooks", {}).setdefault("Stop", [])
for entry in stop_hooks:
    for h in entry.get("hooks", []):
        if "aieye-live-hook" in h.get("command", ""):
            print("already registered")
            sys.exit(0)

stop_hooks.append({"matcher": "", "hooks": [{"type": "command", "command": hook_cmd}]})
os.makedirs(os.path.dirname(os.path.abspath(settings_path)), exist_ok=True)
with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("registered")
