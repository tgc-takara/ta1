import httpx

from app.config import settings


async def send_notification(title: str, message: str) -> bool:
    """Send a notification using the configured method."""
    method = settings.notification_method.lower()
    if method == "line":
        return await _send_line(title, message)
    elif method == "slack":
        return await _send_slack(title, message)
    elif method == "pushover":
        return await _send_pushover(title, message)
    elif method == "none":
        return True
    else:
        raise ValueError(f"Unknown notification method: {method}")


async def _send_line(title: str, message: str) -> bool:
    """Send notification via LINE Notify."""
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://notify-api.line.me/api/notify",
            headers={"Authorization": f"Bearer {settings.line_notify_token}"},
            data={"message": f"\n{title}\n{message}"},
        )
        return resp.status_code == 200


async def _send_slack(title: str, message: str) -> bool:
    """Send notification via Slack Incoming Webhook."""
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            settings.slack_webhook_url,
            json={
                "text": f"*{title}*\n{message}",
            },
        )
        return resp.status_code == 200


async def _send_pushover(title: str, message: str) -> bool:
    """Send notification via Pushover (best for iOS push notifications)."""
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://api.pushover.net/1/messages.json",
            data={
                "token": settings.pushover_api_token,
                "user": settings.pushover_user_key,
                "title": title,
                "message": message,
            },
        )
        return resp.status_code == 200
