from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Obsidian Vault path
    obsidian_vault_path: str = ""
    # Obsidian daily notes subfolder (relative to vault root)
    obsidian_daily_notes_folder: str = "Daily Notes"
    # Daily note date format (used in filenames)
    obsidian_date_format: str = "%Y-%m-%d"

    # Output path for generated daily notes (defaults to obsidian daily notes folder)
    output_path: str = ""

    # Notification settings
    notification_method: str = "none"  # "google_chat", "line", "slack", "pushover", "none"

    # Google Chat
    google_chat_webhook_url: str = ""

    # LINE Notify
    line_notify_token: str = ""

    # Slack
    slack_webhook_url: str = ""

    # Pushover
    pushover_user_key: str = ""
    pushover_api_token: str = ""

    # API authentication
    api_token: str = "changeme"

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    model_config = {"env_file": ".env", "env_prefix": "DN_"}

    @property
    def vault_path(self) -> Path:
        return Path(self.obsidian_vault_path)

    @property
    def daily_notes_path(self) -> Path:
        return self.vault_path / self.obsidian_daily_notes_folder

    @property
    def resolved_output_path(self) -> Path:
        if self.output_path:
            return Path(self.output_path)
        return self.daily_notes_path


settings = Settings()
