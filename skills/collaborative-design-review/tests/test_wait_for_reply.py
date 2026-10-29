import subprocess
import threading
import time
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "scripts" / "wait-for-reply.sh"
ME = "aaaa1111-0000-4000-8000-000000000000"
OTHER = "bbbb2222-0000-4000-8000-000000000000"
THREAD = f"# Feedback\n\n## Reviewer {ME} — t0\n\nF1. A finding.\n\n## Author {OTHER} — t1\n\nF1: fixed.\n"


def after(delay, action):
    timer = threading.Timer(delay, action)
    timer.start()
    return timer


def append(path, text):
    with path.open("a") as handle:
        handle.write(text)


def wait(path, max_seconds, poll=1, settle=1):
    start = time.monotonic()
    result = subprocess.run(
        ["bash", str(SCRIPT), str(path), ME, str(max_seconds)],
        capture_output=True,
        text=True,
        env={"PATH": "/usr/bin:/bin", "POLL": str(poll), "SETTLE": str(settle)},
        timeout=max_seconds + 10,
    )
    return result, time.monotonic() - start


def test_times_out_with_exit_1_when_nothing_changes(tmp_path):
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)

    result, elapsed = wait(feedback, max_seconds=2)

    assert result.returncode == 1
    assert "TIMEOUT" in result.stdout
    assert elapsed < 4


def test_reports_only_the_new_heading_from_another_agent(tmp_path):
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)
    after(1, lambda: append(feedback, f"\n## Author {OTHER} — t2\n\nF2: disagree.\n"))

    result, _ = wait(feedback, max_seconds=15)

    assert result.returncode == 0
    new = [line for line in result.stdout.splitlines() if line.startswith("NEW ENTRY")]
    assert new == [f"NEW ENTRY L11:## Author {OTHER} — t2"]


def test_waits_until_a_reply_written_in_bursts_has_settled(tmp_path):
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)
    after(1, lambda: append(feedback, f"\n## Author {OTHER} — t2\n\nfirst half\n"))
    after(2.5, lambda: append(feedback, "second half\n"))

    result, elapsed = wait(feedback, max_seconds=20, settle=2)

    assert result.returncode == 0
    assert elapsed >= 4.5
    assert "settled" not in result.stdout


def test_own_edits_and_inline_edits_report_a_change_without_new_entries(tmp_path):
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)
    after(1, lambda: append(feedback, f"\n## Reviewer {ME} — t3\n\nmore from me\n"))

    result, _ = wait(feedback, max_seconds=15)

    assert result.returncode == 0
    assert "CHANGED" in result.stdout
    assert "NEW ENTRY" not in result.stdout


def test_exits_2_when_the_file_is_missing_or_removed(tmp_path):
    missing, _ = wait(tmp_path / "absent.md", max_seconds=5)
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)
    after(1, feedback.unlink)

    removed, _ = wait(feedback, max_seconds=10)

    assert (missing.returncode, removed.returncode) == (2, 2)
    assert "MISSING" in missing.stdout and "REMOVED" in removed.stdout


def test_deadline_is_hard_while_a_writer_never_stops(tmp_path):
    feedback = tmp_path / "feedback.md"
    feedback.write_text(THREAD)
    stop = threading.Event()

    def keep_writing():
        count = 0
        while not stop.wait(0.5):
            count += 1
            append(feedback, f"\n## Author {OTHER} — w{count}\n")

    writer = threading.Thread(target=keep_writing)
    writer.start()
    try:
        result, elapsed = wait(feedback, max_seconds=4, settle=2)
    finally:
        stop.set()
        writer.join()

    assert result.returncode == 0
    assert "deadline" in result.stdout
    assert elapsed < 6
