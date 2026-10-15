# Security Policy

## Reporting a Vulnerability

Please **do not** report security vulnerabilities through public GitHub issues.

Use GitHub's private advisory reporting instead:

1. Go to <https://github.com/yanncarlier/iac/security/advisories/new>
2. If that page is unavailable, open the **Security** tab of this repository
   (<https://github.com/yanncarlier/iac/security>) and use the
   **Report a vulnerability** button.

If neither route is available, contact the maintainer directly rather than
opening a public issue.

When you report it, include:

- the affected component and version (or commit)
- steps to reproduce the issue
- the potential impact

You should receive an acknowledgement within a few days. Please allow me a
reasonable amount of time to fix the issue before any public disclosure.

## Automated Coverage

This repository uses GitHub's built-in protections:

- **Secret scanning and push protection** — enabled, for leaked credentials
- **CodeQL code scanning** — enabled; analyses the Python code under
  `gcp-project-provisioning/` on every push and pull request
- **Dependabot** — configured in `.github/dependabot.yml` to track Python
  dependencies and GitHub Actions used by this repository's workflows

These complement, but do not replace, vulnerability reports from people.

## A Note on Historical Dependencies

Dependabot raised alerts in October 2026 against Python packages under the
former `GCloud_project_automation/my-project/` path (now
`gcp-project-provisioning/`). Those update branches targeted a directory that no
longer exists and were closed rather than merged; the alerts remain open until
the dependencies are upgraded via `uv` in the new location.