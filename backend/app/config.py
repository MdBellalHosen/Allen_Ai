"""Central settings. Every secret comes from environment variables, never the APK."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    secret_key: str = "change-me"
    database_url: str = "postgresql+psycopg://allen:allen@db:5432/allen"
    redis_url: str = "redis://redis:6379/0"

    # LLM agent (Phase 4)
    anthropic_api_key: str = ""
    anthropic_base_url: str = "https://api.anthropic.com"
    llm_model: str = ""  # configurable, never hardcoded in code paths
    # "anthropic" (paid) or "openai_compat" (Groq / Gemini / OpenRouter / Ollama: free options)
    llm_provider: str = "anthropic"
    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_max_tokens: int = 1024
    agent_max_steps: int = 15
    agent_session_ttl_s: int = 600

    # Device auth: if set, /v1/auth/device requires this code (stops strangers minting tokens).
    registration_code: str = ""
    device_token_ttl_days: int = 90

    # Cloud STT fallback
    openai_api_key: str = ""
    stt_model: str = "whisper-1"
    stt_max_bytes: int = 10 * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    return Settings()
