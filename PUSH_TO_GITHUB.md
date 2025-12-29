# Push RFR App to GitHub - Manual Steps

Your repository is already configured: `https://github.com/Speed7701/RFR.git`

## Step-by-Step Instructions

Since you're using git worktrees, run these commands manually in Terminal:

### Option 1: From Your Current Worktree

```bash
# Navigate to your project
cd /Users/anthonyswan/.cursor/worktrees/RFR/zhl

# Check current status
git status

# Stage all files
git add .

# Commit your changes
git commit -m "Initial commit: RFR iOS app with watchOS support"

# Push to GitHub
git push -u origin main
```

### Option 2: If You Get "main branch already used" Error

If you get an error about the main branch being used by another worktree, try:

```bash
# Create a new branch for this worktree
git checkout -b initial-commit

# Stage and commit
git add .
git commit -m "Initial commit: RFR iOS app with watchOS support"

# Push the new branch
git push -u origin initial-commit

# Then merge to main on GitHub or run:
git checkout main
git merge initial-commit
git push origin main
```

### Option 3: If You Get SSL Certificate Error

```bash
# Temporarily disable SSL verification (not recommended for production)
git config --global http.sslVerify false

# Then try push again
git push -u origin main

# Re-enable SSL verification after
git config --global http.sslVerify true
```

### Option 4: Use SSH Instead of HTTPS

If HTTPS is giving you trouble:

```bash
# Change remote to SSH
git remote set-url origin git@github.com:Speed7701/RFR.git

# Then push
git push -u origin main
```

## Authentication

If GitHub prompts for credentials:
- **Username**: Your GitHub username (`Speed7701`)
- **Password**: Use a **Personal Access Token** (not your GitHub password)
  - Generate one at: https://github.com/settings/tokens
  - Select scopes: `repo` (full control of private repositories)

## Verify Success

After pushing, check your repository at:
https://github.com/Speed7701/RFR

You should see all your files there!

## Common Issues

### "Permission denied"
- Make sure you have write access to the repository
- Check that you're authenticated with GitHub

### "SSL certificate error"
- Try Option 3 above
- Or switch to SSH (Option 4)

### "Branch already exists"
- The repository might have a README.md already
- Try: `git pull origin main --allow-unrelated-histories` first
- Then push again

