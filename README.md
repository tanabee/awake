# awake

Keep your Mac awake even with the lid closed.

A tiny shell script that combines `pmset` and `caffeinate` so you can close your MacBook lid without putting it to sleep — useful for long-running builds, downloads, training jobs, or remote sessions.

## Requirements

- macOS (uses `pmset` and `caffeinate`)
- `sudo` access (required by `pmset disablesleep`)

## Installation

### Option 1: curl (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

This clones the repo into `~/.local/share/awake` and symlinks the script into `~/.local/bin/awake`.

Override paths with env vars if you want:

```bash
AWAKE_HOME=~/src/awake AWAKE_BIN_DIR=~/bin \
  curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

### Option 2: git clone + symlink (manual)

```bash
git clone https://github.com/tanabee/awake.git ~/dev/awake
ln -s ~/dev/awake/bin/awake ~/.local/bin/awake
```

Adjust the symlink target if you keep user binaries elsewhere (e.g. `~/bin`, `/usr/local/bin`). Make sure the target directory is on your `PATH`.

### Verify

```bash
which awake
awake --help
```

### Update

If you installed with **curl**, re-run the same one-liner to fetch the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

The installer runs `git pull` on the existing checkout, so your local config (paths, symlink) is preserved.

If you installed with **git clone + symlink**, pull in your clone directory:

```bash
git -C ~/dev/awake pull
```

The symlink keeps pointing at the latest script — no re-linking needed.

### Uninstall

```bash
rm ~/.local/bin/awake
rm -rf ~/.local/share/awake   # only if you used the curl installer
rm -rf ~/.local/state/awake   # PID file and logs (background mode)
```

## Usage

### Foreground

```bash
awake
```

You'll be prompted for your `sudo` password. Once the "running" message appears, you can close the lid — the Mac will stay awake.

When you're done, open the lid, return to the terminal where `awake` is running, and press **Ctrl+C**. The script restores the original sleep settings on exit.

### Background

Run detached from the current shell — useful when you want to close the terminal:

```bash
awake start      # primes sudo, then runs in the background
awake status     # check whether it's running (PID, uptime, pmset state)
awake stop       # stop it; sleep settings are restored automatically
```

State is kept under `~/.local/state/awake/` (`awake.pid`, `awake.log`). Override with `AWAKE_STATE_DIR=…`.

`awake status` also reports `pmset disablesleep`. If it shows `1` while no awake process is tracked (e.g. a previous run was `kill -9`'d), restore manually with `sudo pmset -a disablesleep 0`.

### Help

```bash
awake --help
```

## How it works

1. `sudo pmset -a disablesleep 1` — disables clamshell (lid-close) sleep on both AC and battery power.
2. `caffeinate -is` — also prevents system idle sleep while the script is running.
3. A `trap` on `INT` / `TERM` / `HUP` / `EXIT` always runs `sudo pmset -a disablesleep 0` on exit, so sleep behavior is restored even if you Ctrl+C or the shell closes.

## Caveats

- **Heat**: closing the lid traps heat in the chassis. Avoid sustained heavy CPU/GPU loads in clamshell mode for long periods.
- **Battery**: with `-a` (both AC and battery), the Mac will not sleep on battery either. Plug in for long sessions.
- **Force-killed**: if `awake` is killed with `SIGKILL` (`kill -9`) or the machine crashes, the cleanup trap won't run. Recover manually:

  ```bash
  sudo pmset -g | grep -i disablesleep   # check current state (1 = still disabled)
  sudo pmset -a disablesleep 0           # restore
  ```

- **Who's holding sleep open**: inspect active power assertions with:

  ```bash
  pmset -g assertions
  ```

## License

MIT
