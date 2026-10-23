"""Merge the Mac's settings into the host's: the Mac's keys win, the host's own keys stay, plugin ids follow renames."""
import json
import os
import shutil
import sys


def merge(box, mac, renames):
    def rename(pid):
        name, _, market = pid.rpartition("@")
        return f"{name}@{renames.get(market, market)}" if name else pid

    enabled = {**box.get("enabledPlugins", {}), **{rename(k): v for k, v in mac.get("enabledPlugins", {}).items()}}
    return {**box, **mac, "enabledPlugins": enabled}


def main(mac_path, renames_path, target):
    box = json.load(open(target)) if os.path.exists(target) else {}
    if os.path.exists(target) and not os.path.exists(target + ".pre-mirror"):
        shutil.copy(target, target + ".pre-mirror")
    merged = merge(box, json.load(open(mac_path)), json.load(open(renames_path)))
    json.dump(merged, open(target, "w"), indent=2)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.claude/settings.json"))
