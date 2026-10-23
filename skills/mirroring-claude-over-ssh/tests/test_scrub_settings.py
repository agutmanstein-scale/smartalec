import json

import scrub_settings


def test_scrub_drops_secret_env_and_credential_helpers():
    settings = {
        "apiKeyHelper": "get-key.sh",
        "env": {"ANTHROPIC_API_KEY": "sk-1", "GITHUB_TOKEN": "t", "DB_PASSWORD": "p", "ANTHROPIC_AUTH_TOKEN": "a", "EDITOR": "vim"},
        "theme": "dark",
    }

    clean, dropped = scrub_settings.scrub(settings)

    assert clean == {"env": {"EDITOR": "vim"}, "theme": "dark"}
    assert set(dropped) == {"apiKeyHelper", "env.ANTHROPIC_API_KEY", "env.GITHUB_TOKEN", "env.DB_PASSWORD", "env.ANTHROPIC_AUTH_TOKEN"}


def test_scrub_leaves_settings_without_credentials_untouched():
    settings = {"enabledPlugins": {"a@b": True}, "env": {"EDITOR": "vim"}}

    clean, dropped = scrub_settings.scrub(settings)

    assert clean == settings and dropped == []


def test_main_treats_a_missing_settings_file_as_empty(tmp_path):
    dst = tmp_path / "out.json"

    scrub_settings.main(str(tmp_path / "absent.json"), str(dst))

    assert json.loads(dst.read_text()) == {}


def test_main_reports_what_it_dropped(tmp_path, capsys):
    src = tmp_path / "settings.json"
    src.write_text(json.dumps({"env": {"MY_SECRET": "x"}}))

    scrub_settings.main(str(src), str(tmp_path / "out.json"))

    assert "env.MY_SECRET" in capsys.readouterr().err
    assert "x" not in (tmp_path / "out.json").read_text().replace("env", "")
