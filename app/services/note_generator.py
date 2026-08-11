import re
from datetime import date

from jinja2 import Environment, FileSystemLoader, select_autoescape

from app.config import settings
from app.services.obsidian import read_existing_daily_note, read_action_log, read_diary_prompt, read_diary


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
    """Generate or update a daily note.

    If an existing Obsidian daily note is found, tasks are appended
    into it (preserving the original content). Otherwise a new note is created
    from the diary-prompt template (or fallback Jinja2 template).

    The action log from 01_Temporary/Temporary-memo.md is included as reference.
    """
    existing_note = read_existing_daily_note(target_date)

    if existing_note:
        return _append_to_existing(existing_note, tasks, memo_text)

    # Read action log and diary prompt from vault
    action_log = read_action_log()
    diary_prompt = read_diary_prompt()

    if diary_prompt:
        # Use diary-prompt.md from vault as the template
        from jinja2 import Environment
        env = Environment()
        template = env.from_string(diary_prompt)
        return template.render(
            date=target_date.isoformat(),
            weekday=_weekday_ja(target_date),
            tasks=tasks,
            action_log=action_log,
        )

    # Fallback — use built-in Jinja2 template
    template = _env.get_template("daily_note.md.j2")
    return template.render(
        date=target_date.isoformat(),
        weekday=_weekday_ja(target_date),
        tasks=tasks,
        action_log=action_log,
        existing_sections={},
        existing_note="",
    )


def _append_to_existing(existing: str, tasks: list[str], memo_text: str) -> str:
    """Append tasks and memo into an existing Obsidian daily note.

    Strategy:
      1. If the note already has a Tasks / タスク section → append there
      2. Otherwise → append a new Tasks section at the end
      3. If memo_text is provided → append a Memo section at the end
    """
    result = existing.rstrip()

    # Build task lines
    task_lines = "\n".join(f"- [ ] {t}" for t in tasks) if tasks else ""

    # Try to find an existing Tasks heading and append under it
    tasks_pattern = re.compile(
        r"(^##\s*(?:今日のto\s*do|Tasks|タスク|Todo|TODO|To-Do).*$)",
        re.MULTILINE | re.IGNORECASE,
    )
    match = tasks_pattern.search(result)

    if match and task_lines:
        # Find the end of the tasks section (next heading or EOF)
        section_start = match.end()
        next_heading = re.search(r"^##\s", result[section_start:], re.MULTILINE)
        if next_heading:
            insert_pos = section_start + next_heading.start()
            result = (
                result[:insert_pos].rstrip()
                + "\n"
                + task_lines
                + "\n\n"
                + result[insert_pos:]
            )
        else:
            result = result.rstrip() + "\n" + task_lines
    elif task_lines:
        result += "\n\n## 今日のto do\n" + task_lines

    # Memo is saved separately to 01_Temporary/Temporary-memo.md

    return result + "\n"


def save_memo(memo_text: str, target_date: date | None = None) -> str | None:
    """Append memo text to 02_Diary/YYYY-MM-DD.md in the vault."""
    if not memo_text or not memo_text.strip():
        return None
    if not settings.obsidian_vault_path:
        return None

    if target_date is None:
        target_date = date.today()

    diary_dir = settings.vault_path / "02_Diary"
    diary_dir.mkdir(parents=True, exist_ok=True)
    filename = target_date.strftime(settings.obsidian_date_format) + ".md"
    diary_file = diary_dir / filename

    # Append to existing diary file (create if not exists)
    existing = ""
    if diary_file.exists():
        existing = diary_file.read_text(encoding="utf-8")

    new_content = existing.rstrip() + "\n\n" + memo_text.strip() + "\n" if existing.strip() else memo_text.strip() + "\n"
    diary_file.write_text(new_content, encoding="utf-8")
    return str(diary_file)


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
