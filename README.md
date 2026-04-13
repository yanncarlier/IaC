# Google Cloud Project Automation

Simple Python automation to create Google Cloud projects using the Cloud Resource Manager API.

## What This Repo Does

- Creates a new Google Cloud project from a TOML config file.
- Supports either:
- explicit `project_id`
- or generated project IDs from a `project_id_prefix` (+ optional timestamp)

Main script: `01-create_gcloud_project.py`

## Prerequisites

- Python `>=3.11`
- [`uv`](https://docs.astral.sh/uv/)
- Google Cloud credentials via Application Default Credentials (ADC)

## Install Dependencies

```bash
uv sync
```

## Authentication (Local Dev)

Use ADC so `google.auth.default()` can authenticate:

```bash
# If you use project-local gcloud like this repo setup:
CLOUDSDK_CONFIG=$PWD/.gcloud-config .tools/google-cloud-sdk/bin/gcloud auth application-default login --no-launch-browser
```

Then run scripts with:

```bash
GOOGLE_APPLICATION_CREDENTIALS=$PWD/.gcloud-config/application_default_credentials.json
```

## Configure Project Creation

Edit `project_config.toml`:

```toml
display_name = "Automated Project"
quota_project_id = "your-bootstrap-project-id"

# Option 1: Generate a unique project ID
project_id_prefix = "automated-project"
append_timestamp = true

# Option 2: Use an explicit project ID
# project_id = "automated-project-id"
```

Notes:
- Project IDs must be 6-30 chars, lowercase letters/numbers/hyphens.
- Must start with a letter and not end with a hyphen.
- `quota_project_id` should be a stable existing project used for API quota/billing context.

## Bootstrap/Admin Project (Recommended)

Use one stable project for automation quota/billing context (for example `bootstrap-admin-...`), and keep creating workload projects separately.

Why:
- `projects.create` needs an already-existing active quota project.
- New projects should not be used as their own quota project during creation.

## Run

Default config:

```bash
GOOGLE_APPLICATION_CREDENTIALS=$PWD/.gcloud-config/application_default_credentials.json uv run 01-create_gcloud_project.py
```

Custom config path:

```bash
GOOGLE_APPLICATION_CREDENTIALS=$PWD/.gcloud-config/application_default_credentials.json uv run 01-create_gcloud_project.py --config my-config.toml
```

## Typical Errors

- `DefaultCredentialsError`: ADC not set up yet. Run `gcloud auth application-default login`.
- `SERVICE_DISABLED` for `cloudresourcemanager.googleapis.com`: enable that API on your ADC quota project.
- `Config file not found`: wrong `--config` path.
- `USER_PROJECT_DENIED`: your ADC quota project was deleted; set `quota_project_id` to an active project.

## Create Gemini API Key

`02-create-gemini-api-key.py` automates Gemini key creation for a target project.

What it does:
- Uses ADC and optional `quota_project_id` from `project_config.toml`
- Ensures required services are enabled on the target project:
- `apikeys.googleapis.com`
- `generativelanguage.googleapis.com`
- Creates a restricted API key for `generativelanguage.googleapis.com`

Run:

```bash
GOOGLE_APPLICATION_CREDENTIALS=$PWD/.gcloud-config/application_default_credentials.json \
uv run 02-create-gemini-api-key.py --project-id YOUR_PROJECT_ID --display-name gemini-api-key
```

Example:

```bash
GOOGLE_APPLICATION_CREDENTIALS=$PWD/.gcloud-config/application_default_credentials.json \
uv run 02-create-gemini-api-key.py --project-id automated-project-1776063049 --display-name gemini-api-key
```

Important:
- The key is saved to `generated_keys/<project-id>_gemini_api_key.txt`.
- Treat key files as secrets and never commit them.

## Delete Projects from Command Line

Delete a project (moves it to `DELETE_REQUESTED` first):

Using `gcloud`:

```bash
.tools/google-cloud-sdk/bin/gcloud projects delete YOUR_PROJECT_ID --quiet
```

Using API (`curl` + ADC token):

```bash
ACCESS_TOKEN=$(CLOUDSDK_CONFIG=$PWD/.gcloud-config .tools/google-cloud-sdk/bin/gcloud auth application-default print-access-token)
curl -X DELETE -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://cloudresourcemanager.googleapis.com/v3/projects/YOUR_PROJECT_ID"
```

Verify deletion state:

```bash
ACCESS_TOKEN=$(CLOUDSDK_CONFIG=$PWD/.gcloud-config .tools/google-cloud-sdk/bin/gcloud auth application-default print-access-token)
curl -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://cloudresourcemanager.googleapis.com/v3/projects/YOUR_PROJECT_ID"
```

Expected state after delete request: `"state": "DELETE_REQUESTED"`.

## Security Notes

Local credential/tool folders are intentionally gitignored:
- `.gcloud-config/`
- `.tools/`

Do not commit credential files.

## Repo Scripts

- `01-create_gcloud_project.py`: create a GCP project from TOML config
- `02-create-gemini-api-key.py`: enable required APIs and create a Gemini API key
