---
name: github-app-persona
description: Replace a classic PAT with a GitHub App installation token for org-wide automation. Trigger when the user asks for a bot identity, hits PAT-scope walls (admin:org, workflows), wants to purge personal credentials from the machine, needs commit-time credentials without cached HTTPS auth, or asks to create/install a GitHub App. Covers the app-creation form values, 1Password stash, `gh-app` wrapper script that mints installation tokens on demand, git credential helper that feeds the same token to plain `git`, alias-`gh` install, and the noreply-email swap.
---

# GitHub App persona

Replace the user's classic PAT with a GitHub App installation token. The token
lives one hour, scopes to one installation, and never touches the shell's
history because a small wrapper mints it on demand from a private key stored in
1Password. Plain `git`, `gh`, and `repo sync` all use the same token.

## When to reach for it

- The user asks to create a GitHub App, install one, or "act as a bot".
- A classic PAT hits a scope wall (`admin:org` for rulesets and org secrets,
  `workflows` for `.github/workflows/*.yml`) and re-scoping the PAT would
  widen its blast radius on unrelated repos.
- The user purges GitHub credentials (`gh auth logout`, keychain wipe) and
  still needs private-repo access from git for `repo sync` or CI.
- The user wants commits pushed without their personal HTTPS credentials
  cached anywhere on disk.

## What the app carries

For general org automation (transfers, merges, workflow edits, ruleset audit),
these permissions are the working set. `Metadata: read` is mandatory; every
other line covers one verb the user was hitting with the PAT.

    Repository:
      Actions: Read and write         (workflow runs)
      Administration: Read and write  (transfer, archive, rename)
      Checks: Read and write          (check runs)
      Commit statuses: Read and write (CI-style statuses)
      Contents: Read and write        (read files, push commits and branches)
      Issues: Read and write
      Metadata: Read
      Pull requests: Read and write   (open, review, merge)
      Workflows: Read and write       (edit .github/workflows/*.yml)
    Organization:
      Administration: Read and write  (rulesets and org settings)
      Members: Read
      Secrets: Read and write         (org-level Actions secrets)
      Variables: Read and write

Webhooks off. Installation restricted to the owning org. No callback URL.

## After creation, on the app's settings page

1. Copy the **App ID** (top of the page).
2. Click **Generate a private key**. A `.pem` downloads.
3. Stash the `.pem` in 1Password immediately as an attachment on an
   `API_CREDENTIAL` item; do not leave it in `~/Downloads`. Note the
   `op://` reference: `op://<vault>/<item-id>/<filename>`.
4. Click **Install App** in the left sidebar and install onto the target org
   with "All repositories".
5. Note the **Installation ID** from the URL after install.

## The wrapper and helper

Two scripts and one alias. Both scripts read a shared config.

**~/.config/gh-app/config** (mode 0600):

    APP_ID=<app id>
    INSTALLATION_ID=<installation id>
    OP_REF="op://<vault>/<item-id>/<pem filename>"

**~/.local/bin/gh-app** (mode 0700): mints an installation token by signing a
short-lived JWT with the pem streamed from `op read`, caches the token at
`~/.cache/gh-app/token.json` (mode 0600), re-mints when the cached token has
under five minutes left, then execs the real `gh` at `/opt/homebrew/bin/gh`
with `GH_TOKEN` set for the one call. Every argument passes through.

**~/.local/bin/git-credential-gh-app** (mode 0700): git credential helper that
reads the same cache and outputs `username=x-access-token` and
`password=<token>` when git asks for `https://github.com`. Any other host
returns nothing so git falls back to the next configured helper.

Wire them together:

    git config --global credential.https://github.com.helper ""
    git config --global --add credential.https://github.com.helper "!git-credential-gh-app"
    echo 'alias gh=gh-app' >> ~/.zshrc

The empty-string first line resets any inherited helper chain for
`github.com` so `osxkeychain` no longer answers for that host.

## Commit identity

The wrapper authenticates the push. It does not rewrite commit metadata.
Commits made with `git commit` keep the local `user.name` and `user.email`
from `~/.gitconfig`. To stop leaking a real email address, switch to the
personal noreply:

    git config --global user.email '<numeric id>+<login>@users.noreply.github.com'

The numeric id comes from `gh-app api users/<login> --jq .id`. Set
Settings → Emails → "Keep my email addresses private" and "Block command-line
pushes that expose my email" so a misconfigured shell cannot undo this.

To commit as the bot instead, set both `user.name` and `user.email` to the
app's synthetic identity:

    user.name  = <app-slug>[bot]
    user.email = <app id>+<app-slug>[bot]@users.noreply.github.com

## What the app cannot do

- Personal endpoints (`/user`, `viewer` in GraphQL). The app has no user;
  `gh-app auth status` reads as "not logged in". Repo and org endpoints work.
- Delete a repo. Requires `delete_repo` on a PAT; app installations cannot.
- Widen its own permissions. Editing the app definition requires the app
  owner's session, not the installation token.

## Blast radius of the setup

- The pem is the credential. Anyone with the pem and the App ID can act as
  the app across every installation. Storing it in 1Password (attachment on
  an API_CREDENTIAL item) keeps it off disk in cleartext.
- Cached installation tokens at `~/.cache/gh-app/token.json` live one hour,
  scope to one installation, and are useless to anyone who does not also have
  local access as the user.
- `gh-app auth logout` is a no-op — there is no persistent auth to revoke
  locally. To revoke the installation, uninstall from the org's Settings →
  Applications → Installed GitHub Apps. To revoke the pem, generate a new
  private key on the app's settings page and delete the old one; existing
  cached installation tokens continue to work for their remaining TTL but
  cannot be renewed.
