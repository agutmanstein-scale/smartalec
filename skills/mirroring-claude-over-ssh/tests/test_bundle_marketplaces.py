import json
import tarfile

import bundle_marketplaces


def make_marketplace(path, name):
    (path / ".claude-plugin").mkdir(parents=True)
    (path / ".claude-plugin" / "marketplace.json").write_text(json.dumps({"name": name}))
    (path / ".git").mkdir()
    (path / ".git" / "HEAD").write_text("ref")


def test_bundle_archives_each_marketplace_under_its_key_and_records_the_declared_name(tmp_path):
    plugins = tmp_path / "plugins"
    checkout = tmp_path / "work" / "claude-code"
    make_marketplace(checkout, "scale-ai")
    plugins.mkdir()
    (plugins / "known_marketplaces.json").write_text(json.dumps({
        "scale-ai": {"installLocation": str(checkout)},
        "claude-plugins-official": {"installLocation": str(tmp_path / "unused")},
    }))
    (plugins / "installed_plugins.json").write_text(json.dumps({"plugins": {"handoff@scale-ai": [], "x@claude-plugins-official": []}}))
    out = tmp_path / "out"

    bundle_marketplaces.bundle(str(plugins), str(out))

    names = tarfile.open(out / "marketplaces" / "scale-ai.tgz").getnames()
    assert ".claude-plugin/marketplace.json" in [n.split("/", 1)[1] for n in names if "/" in n]
    assert not any(".git" in n.split("/") for n in names)
    assert not (out / "marketplaces" / "claude-plugins-official.tgz").exists()
    assert json.loads((out / "renames.json").read_text()) == {"scale-ai": "scale-ai"}
    assert (out / "plugins.txt").read_text().splitlines() == ["handoff@scale-ai", "x@claude-plugins-official"]


def test_bundle_rewrites_plugin_ids_when_the_declared_name_differs_from_the_local_key(tmp_path):
    plugins = tmp_path / "plugins"
    checkout = plugins / "marketplaces" / "scale-ai-agents"
    make_marketplace(checkout, "scale-ai")
    (plugins / "known_marketplaces.json").write_text(json.dumps({"scale-ai-agents": {}}))
    (plugins / "installed_plugins.json").write_text(json.dumps({"plugins": {"handoff@scale-ai-agents": []}}))
    out = tmp_path / "out"

    bundle_marketplaces.bundle(str(plugins), str(out))

    assert (out / "plugins.txt").read_text().strip() == "handoff@scale-ai"
    assert (out / "marketplaces" / "scale-ai-agents.tgz").exists()


def test_bundle_treats_missing_registries_as_empty(tmp_path):
    plugins = tmp_path / "plugins"
    plugins.mkdir()
    out = tmp_path / "out"

    bundle_marketplaces.bundle(str(plugins), str(out))

    assert json.loads((out / "renames.json").read_text()) == {}
    assert (out / "plugins.txt").read_text() == ""
