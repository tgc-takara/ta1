from datetime import date

from jinja2 import Environment, FileSystemLoader, select_autoescape

from app.config import settings
from app.services.obsidian import read_existing_daily_note

_template_dir = str((settings.vault_path / "templates").resolve()) if settings.obsidian_vault_path else "templates"
_env = Environment(
    loader=FileSystemLoader(["templates", _template_dir]),
    autoescape=select_autoescape([]),
)


def _weekday_ja(d: date) -> str:
    days = ["月", "火", "水", "木", "金", "土", "日"]
    return days[d.weekday()]


def generate_daily_note(
    target_date: date,
    tasks: list[str],
    memo_text: str = "",
) -> str:
    """Generate a daily note by merging tasks with existing Obsidian notes."""
    existing_note = read_existing_daily_note(target_date) or ""

    # Extract existing sections from the Obsidian note
    existing_sections = _parse_sections(existing_note)

    template = _env.get_template("daily_note.md.j2")
    rendered = template.render(
        date=target_date.isoformat(),
        weekday=_weekday_ja(target_date),
        tasks=tasks,
        memo=memo_text,
        existing_sections=existing_sections,
        existing_note=existing_note,
    )
    return rendered


def save_daily_note(target_date: date, content: str) -> str:
    """Save the generated daily note to the output directory."""
    output_dir = settings.resolved_output_path
    output_dir.mkdir(parents=True, exist_ok=True)

    filename = target_date.strftime(settings.obsidian_date_format) + ".md"
    output_file = output_dir / filename
    output_file.write_text(content, encoding="utf-8")
    return str(output_file)


def _parse_sections(content: str) -> dict[str, str]:
    """Parse markdown content into sections by heading."""
    if not content.strip():
        return {}

    sections: dict[str, str] = {}
    current_heading = "_top"
    current_lines: list[str] = []

    for line in content.split("\n"):
        if line.startswith("# ") or line.startswith("## ") or line.startswith("### "):
            if current_lines:
                sections[current_heading] = "\n".join(current_lines).strip()
            current_heading = line.lstrip("#").strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_lines:
        sections[current_heading] = "\n".join(current_lines).strip()

    return sections
