import argparse
import re
import time
import tomllib
from pathlib import Path

import google.auth
from google.auth.exceptions import DefaultCredentialsError
from googleapiclient import discovery


PROJECT_ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]{4,28}[a-z0-9]$")


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9-]+", "-", value)
    value = re.sub(r"-{2,}", "-", value)
    return value.strip("-")


def validate_project_id(project_id: str) -> None:
    if not PROJECT_ID_PATTERN.match(project_id):
        raise ValueError(
            "Invalid project_id. Use 6-30 characters, lowercase letters, numbers, "
            "hyphens, start with a letter, and do not end with a hyphen."
        )


def build_project_id(config: dict) -> str:
    explicit_project_id = config.get("project_id", "").strip()
    if explicit_project_id:
        validate_project_id(explicit_project_id)
        return explicit_project_id

    prefix = config.get("project_id_prefix", "").strip() or config["display_name"]
    prefix = slugify(prefix) or "new-project"
    append_timestamp = bool(config.get("append_timestamp", True))

    if append_timestamp:
        timestamp = str(int(time.time()))
        max_prefix_len = 30 - len(timestamp) - 1
        prefix = prefix[:max_prefix_len].rstrip("-") or "project"
        project_id = f"{prefix}-{timestamp}"
    else:
        project_id = prefix[:30].rstrip("-")
        if len(project_id) < 6:
            project_id = f"{project_id}-proj"[:30].rstrip("-")

    validate_project_id(project_id)
    return project_id


def load_config(config_path: Path) -> dict:
    if not config_path.exists():
        raise FileNotFoundError(
            f"Config file not found: {config_path}. Create it from project_config.toml."
        )

    with config_path.open("rb") as f:
        config = tomllib.load(f)

    display_name = str(config.get("display_name", "")).strip()
    if not display_name:
        raise ValueError("Config must include display_name.")

    return config


def create_google_project(
    project_id: str, display_name: str, quota_project_id: str | None = None
):
    try:
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    except DefaultCredentialsError as exc:
        raise RuntimeError(
            "Application Default Credentials (ADC) not found. "
            "Run: gcloud auth application-default login"
        ) from exc

    if quota_project_id:
        if hasattr(credentials, "with_quota_project"):
            credentials = credentials.with_quota_project(quota_project_id)
        else:
            raise RuntimeError(
                "Loaded credentials do not support quota-project override."
            )

    service = discovery.build("cloudresourcemanager", "v3", credentials=credentials)

    project_body = {
        "projectId": project_id,
        "displayName": display_name,
    }

    if quota_project_id:
        print(f"Using quota project: {quota_project_id}")
    print(f"Creating project: {project_id} ({display_name})")
    operation = service.projects().create(body=project_body).execute()
    print("Create operation:", operation.get("name", operation))
    return operation


def main():
    parser = argparse.ArgumentParser(description="Create a Google Cloud project.")
    parser.add_argument(
        "--config",
        default="project_config.toml",
        help="Path to TOML config file (default: project_config.toml)",
    )
    args = parser.parse_args()

    config = load_config(Path(args.config))
    project_id = build_project_id(config)
    quota_project_id = str(config.get("quota_project_id", "")).strip() or None
    create_google_project(project_id, config["display_name"], quota_project_id)


if __name__ == "__main__":
    main()
