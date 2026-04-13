import argparse
import time
import tomllib
from pathlib import Path

import google.auth
from google.auth.exceptions import DefaultCredentialsError
from googleapiclient import discovery


def load_quota_project_from_config(config_path: Path) -> str | None:
    if not config_path.exists():
        return None

    with config_path.open("rb") as f:
        config = tomllib.load(f)

    return str(config.get("quota_project_id", "")).strip() or None


def get_credentials(quota_project_id: str | None = None):
    try:
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    except DefaultCredentialsError as exc:
        raise RuntimeError(
            "Application Default Credentials (ADC) not found. "
            "Run: gcloud auth application-default login"
        ) from exc

    if quota_project_id and hasattr(credentials, "with_quota_project"):
        credentials = credentials.with_quota_project(quota_project_id)

    return credentials


def wait_for_operation(operations_service, operation_name: str, timeout_seconds: int = 180):
    deadline = time.time() + timeout_seconds
    while True:
        operation = operations_service.get(name=operation_name).execute()
        if operation.get("done"):
            if "error" in operation:
                raise RuntimeError(f"Operation failed: {operation['error']}")
            return operation
        if time.time() >= deadline:
            raise TimeoutError(f"Timed out waiting for operation: {operation_name}")
        time.sleep(2)


def ensure_service_enabled(serviceusage, project_id: str, service_name: str):
    name = f"projects/{project_id}/services/{service_name}"
    service = serviceusage.services().get(name=name).execute()
    if service.get("state") == "ENABLED":
        print(f"Service already enabled: {service_name}")
        return

    print(f"Enabling service: {service_name}")
    operation = serviceusage.services().enable(name=name, body={}).execute()
    wait_for_operation(serviceusage.operations(), operation["name"], timeout_seconds=300)
    print(f"Enabled service: {service_name}")


def get_project_number(resourcemanager, project_id: str) -> str:
    project = resourcemanager.projects().get(name=f"projects/{project_id}").execute()
    # name is "projects/{project_number}"
    return project["name"].split("/")[-1]


def save_key_to_file(project_id: str, key_string: str, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{project_id}_gemini_api_key.txt"
    output_path.write_text(f"{key_string}\n", encoding="utf-8")
    return output_path


def create_gemini_api_key(
    apikeys, project_id: str, project_number: str, display_name: str, output_dir: Path
):
    parent = f"projects/{project_number}/locations/global"
    body = {
        "displayName": display_name,
        "restrictions": {
            "apiTargets": [
                {
                    "service": "generativelanguage.googleapis.com",
                }
            ]
        },
    }

    print(f"Creating key '{display_name}' for Gemini API...")
    operation = apikeys.projects().locations().keys().create(parent=parent, body=body).execute()
    done = wait_for_operation(apikeys.operations(), operation["name"], timeout_seconds=300)
    key = done.get("response", {})
    key_string = key.get("keyString")

    if not key_string:
        raise RuntimeError(
            "Key was created but keyString was not returned. "
            "Try creating a new key and capture output immediately."
        )

    output_path = save_key_to_file(project_id, key_string, output_dir)
    print("Key created.")
    print(f"Key resource: {key.get('name')}")
    print(f"API key saved to: {output_path}")
    return key


def main():
    parser = argparse.ArgumentParser(description="Create a Gemini API key for a project.")
    parser.add_argument("--project-id", required=True, help="Target Google Cloud project ID")
    parser.add_argument(
        "--display-name",
        default="gemini-api-key",
        help="Display name for the API key (default: gemini-api-key)",
    )
    parser.add_argument(
        "--config",
        default="project_config.toml",
        help="Optional TOML config to read quota_project_id from (default: project_config.toml)",
    )
    parser.add_argument(
        "--output-dir",
        default="generated_keys",
        help="Directory where the API key file is saved (default: generated_keys)",
    )
    args = parser.parse_args()

    quota_project_id = load_quota_project_from_config(Path(args.config))
    credentials = get_credentials(quota_project_id=quota_project_id)

    if quota_project_id:
        print(f"Using quota project: {quota_project_id}")

    resourcemanager = discovery.build("cloudresourcemanager", "v3", credentials=credentials)
    serviceusage = discovery.build("serviceusage", "v1", credentials=credentials)
    apikeys = discovery.build("apikeys", "v2", credentials=credentials)

    # Required for key creation and Gemini API usage.
    ensure_service_enabled(serviceusage, args.project_id, "apikeys.googleapis.com")
    ensure_service_enabled(serviceusage, args.project_id, "generativelanguage.googleapis.com")

    project_number = get_project_number(resourcemanager, args.project_id)
    create_gemini_api_key(
        apikeys,
        args.project_id,
        project_number,
        args.display_name,
        Path(args.output_dir),
    )


if __name__ == "__main__":
    main()
