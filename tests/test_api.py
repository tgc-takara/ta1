import os
import tempfile
from datetime import date
from unittest.mock import patch, AsyncMock

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def setup_env(tmp_path):
    """Set up test environment with a temporary vault."""
    vault_path = tmp_path / "vault"
    daily_notes = vault_path / "Daily Notes"
    daily_notes.mkdir(parents=True)

    env_vars = {
        "DN_OBSIDIAN_VAULT_PATH": str(vault_path),
        "DN_OBSIDIAN_DAILY_NOTES_FOLDER": "Daily Notes",
        "DN_API_TOKEN": "test-token",
        "DN_NOTIFICATION_METHOD": "none",
        "DN_OUTPUT_PATH": str(daily_notes),
    }

    with patch.dict(os.environ, env_vars):
        # Re-import to pick up new env vars
        import importlib
        import app.config
        importlib.reload(app.config)
        import app.services.obsidian
        importlib.reload(app.services.obsidian)
        import app.services.note_generator
        importlib.reload(app.services.note_generator)
        import app.auth
        importlib.reload(app.auth)
        import app.routers.daily_note
        importlib.reload(app.routers.daily_note)
        import app.main
        importlib.reload(app.main)

        yield {
            "vault_path": vault_path,
            "daily_notes_path": daily_notes,
            "token": "test-token",
        }


@pytest.fixture
def client(setup_env):
    from app.main import app
    return TestClient(app)


@pytest.fixture
def auth_headers(setup_env):
    return {"Authorization": f"Bearer {setup_env['token']}"}


def test_health_check(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_create_daily_note(client, auth_headers, setup_env):
    resp = client.post(
        "/api/daily-note",
        json={
            "tasks": ["タスク1: メール確認", "タスク2: コードレビュー"],
            "memo": "今日の重要事項",
            "date": "2025-01-15",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["date"] == "2025-01-15"
    assert "タスク1" in data["content"]
    assert "タスク2" in data["content"]
    assert data["notification_sent"] is True

    # Verify file was created
    saved = setup_env["daily_notes_path"] / "2025-01-15.md"
    assert saved.exists()


def test_create_daily_note_default_date(client, auth_headers):
    resp = client.post(
        "/api/daily-note",
        json={"tasks": ["test task"]},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["date"] == date.today().isoformat()


def test_upload_memo_file(client, auth_headers, setup_env):
    memo_content = "- タスクA\n- タスクB\n・タスクC\n1. タスクD"
    resp = client.post(
        "/api/daily-note/upload",
        files={"file": ("memo.txt", memo_content.encode("utf-8"), "text/plain")},
        data={"target_date": "2025-02-01"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "タスクA" in data["content"]
    assert "タスクB" in data["content"]
    assert "タスクC" in data["content"]
    assert "タスクD" in data["content"]


def test_get_existing_note(client, auth_headers, setup_env):
    # Create a note file first
    note_file = setup_env["daily_notes_path"] / "2025-03-01.md"
    note_file.write_text("# Existing Note\nSome content", encoding="utf-8")

    resp = client.get("/api/daily-note/2025-03-01", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["exists"] is True
    assert "Existing Note" in data["content"]


def test_get_nonexistent_note(client, auth_headers):
    resp = client.get("/api/daily-note/2099-12-31", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["exists"] is False
    assert data["content"] is None


def test_unauthorized_access(client):
    resp = client.post(
        "/api/daily-note",
        json={"tasks": ["test"]},
        headers={"Authorization": "Bearer wrong-token"},
    )
    assert resp.status_code == 401


def test_missing_auth(client):
    resp = client.post("/api/daily-note", json={"tasks": ["test"]})
    assert resp.status_code == 422


def test_invalid_date_format(client, auth_headers):
    resp = client.post(
        "/api/daily-note",
        json={"tasks": ["test"], "date": "invalid"},
        headers=auth_headers,
    )
    assert resp.status_code == 400


def test_merge_with_existing_obsidian_note(client, auth_headers, setup_env):
    # Create an existing Obsidian note
    existing = setup_env["daily_notes_path"] / "2025-04-01.md"
    existing.write_text(
        "# 2025-04-01\n## Meeting Notes\n- 10:00 Team sync\n## Ideas\n- New feature proposal",
        encoding="utf-8",
    )

    resp = client.post(
        "/api/daily-note",
        json={
            "tasks": ["新しいタスク"],
            "date": "2025-04-01",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    # Should contain both new tasks and existing content
    assert "新しいタスク" in data["content"]
    assert "Meeting Notes" in data["content"]
    assert "Team sync" in data["content"]
