# Windows support

`pg-sync` is a Bash script. Bash isn't on Windows out of the box, but you have two well-supported options today, and a third path in the future.

## Option 1 — WSL 2 (recommended)

Windows Subsystem for Linux runs a real Linux kernel and userland. `pg-sync` runs there exactly like it does on Linux.

```powershell
# In PowerShell as Administrator (one-time setup)
wsl --install
```

Restart, finish the WSL setup, then inside the WSL shell:

```bash
curl -fsSL https://raw.githubusercontent.com/nixrajput/pg-sync/main/scripts/install.sh | bash
pg-sync --help
```

The WSL filesystem can read `C:\` via `/mnt/c/`, so dumps and configs work across both worlds.

## Option 2 — Git Bash

[Git for Windows](https://git-scm.com/download/win) ships a Bash environment adequate for `pg-sync`. After installing Git for Windows:

```bash
# In Git Bash
curl -fsSL https://raw.githubusercontent.com/nixrajput/pg-sync/main/scripts/install.sh | bash
pg-sync --help
```

You'll also need PostgreSQL client tools on `PATH`. Install via the official PostgreSQL Windows installer and add `C:\Program Files\PostgreSQL\16\bin` to your `PATH`.

## Option 3 — Native PowerShell port (future)

A faithful PowerShell rewrite would let `pg-sync` run on plain Windows without WSL or Git Bash. It is not implemented yet — see the project roadmap.

If you want to contribute one:

1. Mirror the menu structure and interactive flow exactly (so users moving between OSes don't get a different experience).
2. Use `Get-Process` / `Start-Process` in place of `pgrep` / background jobs.
3. Use the `Npgsql.Cmdlets` or `Invoke-Sqlcmd`-style cmdlets for the SQL queries — DO NOT shell out to `psql.exe` line by line, the latency adds up.
4. Match the `--help`, `--version`, `--dry-run` flag semantics.

PRs welcome.
