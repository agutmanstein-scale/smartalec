"""Archive every local marketplace except claude-plugins-official and list the plugins to install on the host.

Writes <out>/marketplaces/<key>.tgz (one top-level directory, named after the local checkout), renames.json
(local key -> the name its marketplace.json declares) and plugins.txt (plugin ids under the declared names).
"""
import json
import os
import subprocess
import sys


def bundle(plugins, out):
    known = json.load(open(os.path.join(plugins, "known_marketplaces.json")))
    os.makedirs(os.path.join(out, "marketplaces"), exist_ok=True)
    renames = {}
    for key, m in known.items():
        if key == "claude-plugins-official":
            continue
        loc = m.get("installLocation") or os.path.join(plugins, "marketplaces", key)
        manifest = json.load(open(os.path.join(loc, ".claude-plugin", "marketplace.json")))
        renames[key] = manifest.get("name", key)
        subprocess.run(["tar", "--exclude=.git", "--exclude=.DS_Store", "-czf",
                        os.path.join(out, "marketplaces", f"{key}.tgz"), "-C", os.path.dirname(loc), os.path.basename(loc)],
                       check=True, env={**os.environ, "COPYFILE_DISABLE": "1"})
    json.dump(renames, open(os.path.join(out, "renames.json"), "w"))
    ids = json.load(open(os.path.join(plugins, "installed_plugins.json")))["plugins"]
    with open(os.path.join(out, "plugins.txt"), "w") as fh:
        for pid in sorted(ids):
            name, _, market = pid.rpartition("@")
            fh.write(f"{name}@{renames.get(market, market)}\n")


if __name__ == "__main__":
    bundle(sys.argv[1], sys.argv[2])
