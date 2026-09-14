# Create a brand-new GitHub repository

This package is designed for a **new** GitHub repository. It does not depend on any previous `Defender-Enrollment` repository or Git history.

## ParrotOS / Debian-based Linux

Install the required tools if necessary:

```bash
sudo apt update
sudo apt install -y git gh unzip
```

Authenticate GitHub CLI:

```bash
gh auth login
gh auth setup-git
```

From the extracted `Defender-Enrollment` directory, create the new repository:

```bash
chmod +x ./create-new-github-repo.sh
./create-new-github-repo.sh public
```

Use `private` instead of `public` if required:

```bash
./create-new-github-repo.sh private
```

By default the GitHub repository will be created as:

```text
00Corwin/Defender-Enrollment
```

To use another repository name:

```bash
./create-new-github-repo.sh public Defender-Enrollment-PowerShell
```

The helper will:

1. Verify `git` and `gh` are installed.
2. Verify GitHub CLI authentication.
3. Refuse to overwrite an new GitHub repository of the same name.
4. Initialise a new local Git repository on branch `main`.
5. Use your authenticated GitHub identity for the local commit if Git identity is not already configured.
6. Commit the complete project.
7. Create the new GitHub repository.
8. Push `main`.
9. Create and push tag `v1.0.0`.

## Manual equivalent

If you prefer to do it yourself:

```bash
git init -b main
git add -A
git commit -m "Initial Defender-Enrollment release"
gh repo create 00Corwin/Defender-Enrollment --public --source=. --remote=origin --push
git tag -a v1.0.0 -m "Defender-Enrollment v1.0.0"
git push origin v1.0.0
```
