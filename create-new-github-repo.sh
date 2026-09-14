#!/usr/bin/env bash
set -euo pipefail

VISIBILITY="${1:-}"
REPO_NAME="${2:-Defender-Enrollment}"
OWNER="${GITHUB_OWNER:-00Corwin}"
TAG="v1.0.0"

usage() {
    echo "Usage: $0 <public|private> [repository-name]" >&2
    echo "Example: $0 public Defender-Enrollment" >&2
}

if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
    usage
    exit 2
fi

for cmd in git gh; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: '$cmd' is required." >&2
        exit 1
    }
done

if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI is not authenticated. Run: gh auth login" >&2
    exit 1
fi

LOGIN="$(gh api user --jq '.login')"
if [[ -z "$LOGIN" ]]; then
    echo "ERROR: Could not determine the authenticated GitHub account." >&2
    exit 1
fi

if [[ "$LOGIN" != "$OWNER" ]]; then
    echo "WARNING: gh is authenticated as '$LOGIN', but this package defaults to owner '$OWNER'." >&2
    echo "To intentionally use '$LOGIN', run:" >&2
    echo "  GITHUB_OWNER='$LOGIN' $0 '$VISIBILITY' '$REPO_NAME'" >&2
    exit 1
fi

if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
    echo "ERROR: GitHub repository '$OWNER/$REPO_NAME' already exists." >&2
    echo "This helper only creates NEW repositories and will not update an existing repository." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -d .git ]]; then
    echo "ERROR: This directory already contains a .git repository." >&2
    echo "Extract a fresh copy of the package and run the helper there." >&2
    exit 1
fi

# Configure a repository-local Git identity only when the user has not already
# configured one. The GitHub no-reply address is derived from the authenticated
# account ID and username.
GITHUB_ID="$(gh api user --jq '.id')"
DEFAULT_EMAIL="${GITHUB_ID}+${LOGIN}@users.noreply.github.com"

GLOBAL_NAME="$(git config --global --get user.name 2>/dev/null || true)"
GLOBAL_EMAIL="$(git config --global --get user.email 2>/dev/null || true)"

# Initialise first so local config can be written.
git init -b main

if [[ -n "$GLOBAL_NAME" ]]; then
    git config user.name "$GLOBAL_NAME"
else
    git config user.name "$LOGIN"
fi

if [[ -n "$GLOBAL_EMAIL" ]]; then
    git config user.email "$GLOBAL_EMAIL"
else
    git config user.email "$DEFAULT_EMAIL"
fi

# Ensure no archive/build leftovers become part of the repository.
find . -maxdepth 1 -type f \( -name '*.zip' -o -name '*.bundle' -o -name '*.tar.gz' \) -delete

git add -A

echo
echo "Files to be committed:"
git status --short

git commit -m "Initial Defender-Enrollment release"
git tag -a "$TAG" -m "Defender-Enrollment $TAG"

DESCRIPTION="PowerShell tooling for Microsoft Defender for Endpoint migration, validation, Intune device classification and MDE tier tagging."

echo
echo "Creating GitHub repository: https://github.com/$OWNER/$REPO_NAME"
gh repo create "$OWNER/$REPO_NAME" \
    "--$VISIBILITY" \
    --description "$DESCRIPTION" \
    --source=. \
    --remote=origin \
    --push

git push origin "$TAG"

echo
echo "SUCCESS"
echo "Repository: https://github.com/$OWNER/$REPO_NAME"
echo "Branch: main"
echo "Tag: $TAG"
