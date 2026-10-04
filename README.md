# awake

Keep your Mac awake even with the lid closed.

A tiny shell script that combines `pmset` and `caffeinate` so you can close your MacBook lid without putting it to sleep — useful for long-running builds, downloads, training jobs, or remote sessions.

## Requirements

- macOS (uses `pmset` and `caffeinate`)
- `sudo` access (required by `pmset disablesleep`)

## Installation

### Option 1: Homebrew (recommended)

```bash
brew install tanabee/tap/awake
```

On Homebrew 7+, third-party taps must be trusted first; if prompted, run `brew trust tanabee/tap` and retry.

### Option 2: git clone + symlink

```bash
git clone https://github.com/tanabee/awake.git ~/.local/share/awake
ln -s ~/.local/share/awake/bin/awake ~/.local/bin/awake
```

Pick different paths if you prefer — for example clone into `~/src/awake` and link to `~/bin/awake`. Just make sure the symlink target directory is on your `PATH`.

### Option 3: curl (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

This runs the same steps as Option 2 (clone into `~/.local/share/awake`, symlink into `~/.local/bin/awake`).

Override paths with env vars if you want:

```bash
AWAKE_HOME=~/src/awake AWAKE_BIN_DIR=~/bin \
  curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

### Verify

```bash
which awake
awake --help
```

### Update

If you installed with **Homebrew**:

```bash
brew upgrade awake
```

If you installed with **git clone + symlink**, pull in your clone directory:

```bash
git -C ~/.local/share/awake pull
```

The symlink keeps pointing at the latest script — no re-linking needed.

If you installed with **curl**, re-run the same one-liner to fetch the latest version:

```bash
curl -fsSL https://raw.githubusercontent.com/tanabee/awake/main/install.sh | bash
```

The installer runs `git pull` on the existing checkout, so your local config (paths, symlink) is preserved.

### Uninstall

Homebrew:

```bash
brew uninstall awake
rm -rf ~/.local/state/awake   # PID file and logs (background mode)
```

Manual install:

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

You'll be prompted for your `sudo` password — **only once, at startup**. Once the "running" message appears, you can close the lid — the Mac will stay awake.

When you're done, open the lid, return to the terminal where `awake` is running, and press **Ctrl+C**. The script restores the original sleep settings on exit, without asking for your password again.

### Background

Run detached from the current shell — useful when you want to close the terminal:

```bash
awake start      # primes sudo, then runs in the background
awake status     # check whether it's running (PID, uptime, pmset state)
awake stop       # stop it; sleep settings are restored automatically
```

State is kept under `~/.local/state/awake/` (`awake.pid`, `awake.deadline`, `awake.battery`, `awake.safe`, `awake.log`). Override with `AWAKE_STATE_DIR=…`.

`awake status` also reports `pmset disablesleep`. If it shows `1` while no awake process is tracked (e.g. another tool holds it, or a run predating the root helper was force-killed), restore manually with `sudo pmset -a disablesleep 0`.

### Time limit (`-t` / `--timeout`)

Pass a duration to auto-stop after a fixed time. Works in both foreground and background mode:

```bash
awake -t 1h            # foreground, stop after 1 hour
awake -t 30m           # foreground, stop after 30 minutes
awake -t 1h30m         # combined units (hours / minutes / seconds)
awake -t 3600          # bare integer = seconds (== 1h)

awake start -t 2h      # background, auto-stop after 2 hours
awake status           # shows remaining time and deadline
```

When the timer fires, `awake` exits the same way as `awake stop` / Ctrl+C — sleep settings are restored automatically by the root helper (see below), with **no sudo password prompt** at the deadline. You can start `awake -t 8h`, walk away, and sleep settings will be back to normal when the timer fires.

### Battery limit (`-b` / `--battery`)

Pass an integer percent (1–99) to auto-stop when the battery drops to or below that level. Checks every 60s. **Skipped while on AC power**, so charging won't trigger an unwanted stop.

```bash
awake -b 20             # foreground, stop when battery <= 20% (on battery)
awake start -b 15       # background, same idea
awake -t 8h -b 20       # combine: stop after 8h OR when battery <= 20%
```

`awake status` shows the threshold along with the current battery level and power source. Like timeout, the battery monitor signals SIGTERM to the main process so the standard cleanup path restores `pmset`.

### Safe mode (`-s` / `--safe`)

Closing the lid traps heat. Pass `-s` to auto-stop when macOS reports **thermal pressure at "serious" or worse for 3 minutes straight**. It reads `NSProcessInfo.thermalState` (nominal / fair / serious / critical), so it works on Apple Silicon and Intel with no extra tools and no sudo. Checks every 60s; a short spike that cools down resets the timer.

```bash
awake -s                # foreground, stop if the Mac stays hot for 3 minutes
awake start -s          # background, same idea
awake -t 8h -b 20 -s    # combine: whichever condition fires first stops awake
```

`awake status` shows `safe mode: on` along with the current thermal state. Note that macOS already throttles and protects the hardware by itself; `-s` just stops keeping the Mac awake once it is too hot to do useful work.

### Help

```bash
awake --help
```

## How it works

1. A single `sudo` authentication at startup launches a small **root helper** process. The helper runs `pmset -a disablesleep 1` — disabling clamshell (lid-close) sleep on both AC and battery power — and then blocks on a FIFO held open by the main `awake` process.
2. `caffeinate -is` — also prevents system idle sleep while the script is running.
3. When `awake` exits for any reason — Ctrl+C, `awake stop`, `-t` timeout, `-b` battery limit, `-s` thermal limit, `SIGTERM`, even `kill -9` — the FIFO reaches EOF and the helper restores `pmset -a disablesleep 0` with the root privileges it already holds. Because the helper never needs a fresh `sudo` credential, **no password prompt appears at exit**, so timed runs release automatically even when you're away from the machine.

## Caveats

- **Heat**: closing the lid traps heat in the chassis. Avoid sustained heavy CPU/GPU loads in clamshell mode for long periods, or run with `-s` to auto-stop once thermal pressure stays high.
- **Battery**: with `-a` (both AC and battery), the Mac will not sleep on battery either. Plug in for long sessions.
- **Force-killed**: `kill -9` is handled — the root helper notices the FIFO EOF and restores sleep settings (and reaps the orphaned `caffeinate`). If the machine crashes outright, though, no process survives to clean up. Recover manually:

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
