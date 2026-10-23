import json
import os
import subprocess
import tarfile
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "scripts" / "mirror-claude.sh"

FAKE_SSH = """#!/bin/bash
echo "ssh $*" >> "$FAKE_LOG"
case "$*" in
  *"mktemp -d"*) echo "$FAKE_REMOTE" ;;
  *uname*) echo "MISSING:${FAKE_MISSING:-}" ;;
  *) echo "ran" ;;
esac
"""
FAKE_SCP = """#!/bin/bash
echo "scp $*" >> "$FAKE_LOG"
args=("$@"); n=${#args[@]}
cp -R "${args[$((n-2))]}" "${args[$((n-1))]#*:}"
"""


def setup(tmp_path, settings=None, with_settings=True):
    home = tmp_path / "home"
    claude = home / ".claude"
    (claude / "skills" / "s").mkdir(parents=True)
    (claude / "skills" / "s" / "SKILL.md").write_text("x")
    (claude / "CLAUDE.md").write_text("instructions")
    if with_settings:
        (claude / "settings.json").write_text(json.dumps(settings or {"enabledPlugins": {"handoff@scale-ai": True}}))
    (claude / "settings.local.json").write_text(json.dumps({"env": {"MY_TOKEN": "tok", "EDITOR": "vim"}}))
    market = claude / "plugins" / "marketplaces" / "scale-ai"
    (market / ".claude-plugin").mkdir(parents=True)
    (market / ".claude-plugin" / "marketplace.json").write_text(json.dumps({"name": "scale-ai"}))
    (claude / "plugins" / "known_marketplaces.json").write_text(json.dumps({"scale-ai": {}}))
    (claude / "plugins" / "installed_plugins.json").write_text(json.dumps({"plugins": {"handoff@scale-ai": []}}))
    bindir = tmp_path / "bin"
    bindir.mkdir()
    for name, body in (("ssh", FAKE_SSH), ("scp", FAKE_SCP)):
        (bindir / name).write_text(body)
        (bindir / name).chmod(0o755)
    remote = tmp_path / "remote"
    remote.mkdir()
    env = {**os.environ, "HOME": str(home), "PATH": f"{bindir}:{os.environ['PATH']}",
           "FAKE_LOG": str(tmp_path / "log"), "FAKE_REMOTE": str(remote)}
    return env, remote, tmp_path / "log"


def run(env):
    return subprocess.run(["bash", str(SCRIPT), "devbox"], env=env, capture_output=True, text=True)


def test_mirror_uploads_to_a_private_remote_dir_and_runs_the_setup_script_there(tmp_path):
    env, remote, log = setup(tmp_path)

    result = run(env)

    assert result.returncode == 0, result.stderr
    commands = log.read_text()
    assert "/tmp/claude-mirror" not in commands
    assert f"bash '{remote}/remote-setup.sh' '{remote}'" in commands
    for name in ("remote-setup.sh", "merge_settings.py", "claude.tgz", "plugins.txt", "renames.json"):
        assert (remote / name).exists(), name


def test_mirror_never_uploads_credentials_from_either_settings_file(tmp_path):
    env, remote, _ = setup(tmp_path, settings={"env": {"ANTHROPIC_API_KEY": "sk-secret"}, "apiKeyHelper": "x.sh"})

    result = run(env)

    assert result.returncode == 0, result.stderr
    uploaded = (remote / "settings.mac.json").read_text() + (remote / "settings.local.json").read_text()
    assert "sk-secret" not in uploaded and "apiKeyHelper" not in uploaded and "tok" not in uploaded
    assert "EDITOR" in uploaded
    assert "ANTHROPIC_API_KEY" in result.stderr
    with tarfile.open(remote / "claude.tgz") as t:
        assert not any(n.endswith("settings.local.json") for n in t.getnames())


def test_mirror_works_when_the_mac_has_no_settings_json(tmp_path):
    env, remote, _ = setup(tmp_path, with_settings=False)

    result = run(env)

    assert result.returncode == 0, result.stderr
    assert json.loads((remote / "settings.mac.json").read_text()) == {}


def test_mirror_stops_before_uploading_when_the_host_lacks_a_requirement(tmp_path):
    env, remote, log = setup(tmp_path)
    env["FAKE_MISSING"] = " python3"

    result = run(env)

    assert result.returncode == 1
    assert "python3" in result.stderr
    assert "scp" not in log.read_text()
