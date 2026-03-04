from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.routers.daily_note import router as daily_note_router

app = FastAPI(
    title="Daily Note Generator",
    description="iPhoneからタスクメモを送信してObsidian Daily Noteを生成・通知するAPI",
    version="1.0.0",
)

app.include_router(daily_note_router)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {str(exc)}"},
    )
