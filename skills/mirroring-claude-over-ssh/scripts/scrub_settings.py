"""Strip credential-bearing keys from a Claude settings file before it leaves the Mac."""
import json
import os
import re
import sys

SECRET_NAME = re.compile(r"key|token|secret|password|credential|auth", re.I)
HELPER_KEYS = ("apiKeyHelper", "awsAuthRefresh", "awsCredentialExport", "otelHeadersHelper")


def scrub(settings):
    """Return (settings without credentials, names that were dropped)."""
    out = {k: v for k, v in settings.items() if k not in HELPER_KEYS}
    dropped = [k for k in HELPER_KEYS if k in settings]
    env = settings.get("env")
    if isinstance(env, dict):
        kept = {k: v for k, v in env.items() if not SECRET_NAME.search(k)}
        dropped += [f"env.{k}" for k in env if k not in kept]
        out["env"] = kept
    return out, dropped


def main(src, dst):
    settings = json.load(open(src)) if os.path.exists(src) else {}
    clean, dropped = scrub(settings)
    json.dump(clean, open(dst, "w"), indent=2)
    if dropped:
        print(f"NOTE: not copying credentials from {os.path.basename(src)}: {', '.join(dropped)}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
