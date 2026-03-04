from datetime import date
from pathlib import Path

from app.config import settings


def get_daily_note_path(target_date: date) -> Path:
    filename = target_date.strftime(settings.obsidian_date_format) + ".md"
    return settings.daily_notes_path / filename


def read_existing_daily_note(target_date: date) -> str | None:
    """Read an existing Obsidian daily note for the given date."""
    path = get_daily_note_path(target_date)
    if path.exists():
        return path.read_text(encoding="utf-8")
    return None


def find_recent_notes(days: int = 7) -> dict[str, str]:
    """Find recent daily notes from the Obsidian vault."""
    from datetime import timedelta

    today = date.today()
    notes: dict[str, str] = {}

    for i in range(days):
        d = today - timedelta(days=i)
        content = read_existing_daily_note(d)
        if content:
            notes[d.isoformat()] = content

    return notes


def list_vault_notes(subfolder: str = "") -> list[str]:
    """List markdown files in the vault (or a subfolder)."""
    search_path = settings.vault_path / subfolder if subfolder else settings.vault_path
    if not search_path.exists():
        return []
    return [str(p.relative_to(settings.vault_path)) for p in search_path.rglob("*.md")]
