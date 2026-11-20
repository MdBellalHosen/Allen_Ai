"""Central settings. Every secret comes from environment variables, never the APK."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    secret_key: str = "change-me"
    database_url: str = "postgresql+psycopg://maya:maya@db:5432/maya"
    redis_url: str = "redis://redis:6379/0"
    anthropic_api_key: str = ""
    llm_model: str = ""  # configurable, never hardcoded in code paths


@lru_cache
def get_settings() -> Settings:
    return Settings()
