from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel

from app.auth import verify_token
from app.services.note_generator import generate_daily_note, save_daily_note, save_memo
from app.services.notifier import send_notification
from app.services.obsidian import read_existing_daily_note, find_recent_notes

router = APIRouter(prefix="/api", tags=["daily-note"])


class TaskInput(BaseModel):
    tasks: list[str]
    memo: str = ""
    date: str = ""  # YYYY-MM-DD, defaults to today


class DailyNoteResponse(BaseModel):
    date: str
    content: str
    saved_path: str
    notification_sent: bool


@router.post("/daily-note", response_model=DailyNoteResponse, dependencies=[Depends(verify_token)])
async def create_daily_note(input_data: TaskInput):
    """Create a daily note from task list and memo text."""
    target_date = _parse_date(input_data.date)

    content = generate_daily_note(
        target_date=target_date,
        tasks=input_data.tasks,
        memo_text=input_data.memo,
    )

    saved_path = save_daily_note(target_date, content)
    save_memo(input_data.memo, target_date)

    notified = await send_notification(
        title=f"Daily Note: {target_date.isoformat()}",
        message=_build_notification_message(input_data.tasks, target_date),
    )

    return DailyNoteResponse(
        date=target_date.isoformat(),
        content=content,
        saved_path=saved_path,
        notification_sent=notified,
    )


@router.post("/daily-note/upload", response_model=DailyNoteResponse, dependencies=[Depends(verify_token)])
async def create_daily_note_from_file(
    file: UploadFile = File(...),
    target_date: str = Form(""),
):
    """Create a daily note from an uploaded text/markdown memo file."""
    content_bytes = await file.read()
    memo_text = content_bytes.decode("utf-8")

    tasks = _extract_tasks_from_text(memo_text)
    d = _parse_date(target_date)

    note_content = generate_daily_note(
        target_date=d,
        tasks=tasks,
        memo_text=memo_text,
    )

    saved_path = save_daily_note(d, note_content)
    save_memo(memo_text, d)

    notified = await send_notification(
        title=f"Daily Note: {d.isoformat()}",
        message=_build_notification_message(tasks, d),
    )

    return DailyNoteResponse(
        date=d.isoformat(),
        content=note_content,
        saved_path=saved_path,
        notification_sent=notified,
    )


class ExistingNoteResponse(BaseModel):
    date: str
    content: str | None
    exists: bool


@router.get("/daily-note/{note_date}", response_model=ExistingNoteResponse, dependencies=[Depends(verify_token)])
async def get_daily_note(note_date: str):
    """Get an existing daily note."""
    d = _parse_date(note_date)
    content = read_existing_daily_note(d)
    return ExistingNoteResponse(
        date=d.isoformat(),
        content=content,
        exists=content is not None,
    )


class RecentNotesResponse(BaseModel):
    notes: dict[str, str]


@router.get("/recent-notes", response_model=RecentNotesResponse, dependencies=[Depends(verify_token)])
async def get_recent_notes(days: int = 7):
    """Get recent daily notes."""
    notes = find_recent_notes(days)
    return RecentNotesResponse(notes=notes)


def _parse_date(date_str: str) -> date:
    if not date_str:
        return date.today()
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {date_str}. Use YYYY-MM-DD.")


def _extract_tasks_from_text(text: str) -> list[str]:
    """Extract task items from free-form text."""
    tasks: list[str] = []
    for line in text.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        # Match common task formats: "- [ ] task", "- task", "* task", "1. task", "・task"
        for prefix in ["- [ ] ", "- [x] ", "- ", "* ", "・"]:
            if line.startswith(prefix):
                tasks.append(line[len(prefix):].strip())
                break
        else:
            # Check numbered list: "1. task", "2. task"
            if len(line) > 2 and line[0].isdigit() and ". " in line[:5]:
                tasks.append(line.split(". ", 1)[1].strip())
            else:
                # Treat non-empty lines as tasks
                tasks.append(line)
    return tasks


def _build_notification_message(tasks: list[str], target_date: date) -> str:
    if not tasks:
        return f"{target_date.isoformat()} のDaily Noteを作成しました。"
    task_list = "\n".join(f"  - {t}" for t in tasks[:10])
    suffix = f"\n  ...他 {len(tasks) - 10} 件" if len(tasks) > 10 else ""
    return f"{target_date.isoformat()} のタスク ({len(tasks)}件):\n{task_list}{suffix}"
