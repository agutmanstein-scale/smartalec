import json

import merge_settings


def test_merge_mac_keys_win_and_box_keys_stay():
    box = {"theme": "light", "model": "box"}
    mac = {"model": "mac"}

    assert merge_settings.merge(box, mac, {}) == {"theme": "light", "model": "mac", "enabledPlugins": {}}


def test_merge_renames_plugin_ids_to_the_declared_marketplace_name():
    mac = {"enabledPlugins": {"handoff@local-key": True, "plain": False}}

    merged = merge_settings.merge({"enabledPlugins": {"old@x": True}}, mac, {"local-key": "scale-ai"})

    assert merged["enabledPlugins"] == {"old@x": True, "handoff@scale-ai": True, "plain": False}


def test_main_backs_up_the_box_settings_once(tmp_path):
    target = tmp_path / "settings.json"
    target.write_text(json.dumps({"theme": "light"}))
    mac = tmp_path / "mac.json"
    mac.write_text(json.dumps({"model": "mac"}))
    renames = tmp_path / "renames.json"
    renames.write_text("{}")

    merge_settings.main(str(mac), str(renames), str(target))
    merge_settings.main(str(mac), str(renames), str(target))

    assert json.loads((tmp_path / "settings.json.pre-mirror").read_text()) == {"theme": "light"}
    assert json.loads(target.read_text())["theme"] == "light"


def test_main_creates_settings_when_the_box_has_none(tmp_path):
    target = tmp_path / "settings.json"
    mac = tmp_path / "mac.json"
    mac.write_text(json.dumps({"model": "mac"}))
    renames = tmp_path / "renames.json"
    renames.write_text("{}")

    merge_settings.main(str(mac), str(renames), str(target))

    assert json.loads(target.read_text())["model"] == "mac"
    assert not (tmp_path / "settings.json.pre-mirror").exists()
