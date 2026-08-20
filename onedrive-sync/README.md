# onedrive-sync

Workaround for syncing OneDrive on Linux through WebDAV with [rclone](https://rclone.org/). Auth cookies are pulled from Firefox; thin bash wrappers run upload/download.

## Prerequisites

- [rclone](https://rclone.org/)
- Firefox, already signed in to your OneDrive / SharePoint site
- Python 3 (stdlib only — no extra packages for the Firefox path)
- A local sync folder at `~/OneDrive/` (created automatically on first download if missing is fine; rclone will create as needed depending on version/flags)

## Install

From the repo root (GNU stow):

```bash
stow onedrive-sync
```

That links:

| Path | Role |
| --- | --- |
| `~/.config/rclone/rclone.conf` | WebDAV remote + cookie header |
| `~/.config/rclone/filters.txt` | Paths excluded from sync |
| `~/.local/bin/onedrive-download` | Pull remote → `~/OneDrive/` |
| `~/.local/bin/onedrive-upload` | Push `~/OneDrive/` → remote |
| `~/.local/share/onedrive-sync/fetch_cookie.py` | Refresh SharePoint cookies into rclone.conf |

Ensure `~/.local/bin` is on your `PATH`.

## Configure

1. **Edit `~/.config/rclone/rclone.conf`** so the `onedrive` remote matches your tenant. Typical shape:

   ```ini
   [onedrive]
   type = webdav
   url = https://TENANT-my.sharepoint.com/personal/USER_DOMAIN_TLD/Documents
   vendor = other
   user = you@example.com
   pass = <rclone obscure output>
   headers = "Cookie","FedAuth=...;rtFa=...;"
   ```

   The `headers` line must be the **last** line of the file (no trailing blank lines). `fetch_cookie.py` rewrites that line.

2. **Edit `~/.local/share/onedrive-sync/fetch_cookie.py`**: set `tennant` to your SharePoint tenant prefix, and adjust the Firefox URL in the `subprocess.Popen([...])` call to your personal Documents URL.

3. **Optional:** tweak `~/.config/rclone/filters.txt` to exclude folders/patterns you do not want synced.

## Usage

Cookies expire every few days. Both sync scripts refresh them first by running `fetch_cookie.py` (opens Firefox so you can re-authenticate if needed, then writes cookies into rclone.conf).

```bash
# Download: OneDrive → ~/OneDrive/
onedrive-download

# Upload: ~/OneDrive/ → OneDrive
onedrive-upload
```

By default both use `rclone copy` (additive). Pass `--disrupt` to use `rclone sync` instead (mirror; can delete on the destination):

```bash
onedrive-download --disrupt
onedrive-upload --disrupt
```

Extra arguments after the flags are forwarded to rclone.

Logs go to `~/Documents/backuplocal/logs.txt`. Download also uses `--backup-dir ~/Documents/backuplocal` for overwritten local files.

### Manual cookie refresh

```bash
python3 ~/.local/share/onedrive-sync/fetch_cookie.py
```

## fetch_cookie.py

Adapted from [this gist](https://gist.github.com/ozel/bb1cbdd4674445aba1c25289166afda3). Reads `rtFa` / `FedAuth` from the Firefox cookies DB and updates the last line of rclone.conf. Chromium / davfs2 paths exist in the upstream approach but are disabled in this fork.
