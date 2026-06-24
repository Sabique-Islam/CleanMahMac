# CleanMahMac

**Reclaim disk space from dev junk — without the black box.**

CleanMahMac is a macOS CLI that cleans **regenerable** development caches and abandoned dependencies.

The command is **`cmm`**, not `CleanMahMac`.

## Why this exists

Your Mac didn't run out of space because you wrote too much code. It ran out because:

- Xcode DerivedData has been fermenting since 2019
- Docker.raw became a small moon
- Seventeen abandoned side projects each have a 2 GB `node_modules`
- Gradle, npm, and Homebrew caches formed a sediment layer

CleanMahMac finds that stuff, shows you exactly what it is, and only deletes after you say so.

## Safety guarantees

- **Dry-run by default** — nothing is deleted unless you pass `--force`
- **Confirmation prompts** — destructive actions ask before proceeding
- **Allowlist validation** — only known-safe paths can be removed
- **Protected paths** — home, system dirs, and source roots are blocked
- **No blind `rm -rf`** — targeted removal with path checks
- **Never deletes source code** — only caches, build artifacts, and `node_modules`
- **No telemetry** — your disk shame stays local (lol)

## Install

```bash
git clone https://github.com/Sabique-Islam/CleanMahMac.git
cd CleanMahMac
./install.sh
```

`install.sh` runs `chmod +x` on all scripts automatically. If you clone without installing and get "Permission denied", run:

```bash
cmm fix-permissions
# or manually:
chmod +x cmm install.sh uninstall.sh
find . -type f \( -name '*.sh' -o -name cmm \) ! -path './tests/fixtures/*' -exec chmod +x {} +
```

When a script is not executable, `cmm` prints the exact fix command and asks whether to repair permissions automatically.

Ensure `~/.local/bin` is on your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Uninstall:

```bash
./uninstall.sh
```

## Usage

```bash
# Scan everything (safe, no deletes)
cmm scan

# Readable report grouped by module
cmm report

# Detect disk hogs and anomalies
cmm doctor

# Configure which folders to scan (arrow-key picker — include ~/Downloads if you use it)
cmm configure

# Fix script permissions if needed
cmm fix-permissions

# Preview cleanup for a module (dry-run)
cmm clean xcode
cmm clean docker
cmm clean abandoned-node-modules

# Actually delete (with confirmation)
cmm clean xcode --force
cmm clean abandoned-node-modules --force

# Skip prompts (CI / power users)
cmm clean node --force --yes

# Clean everything
cmm clean all --force
```

## Supported cleanup targets

| Module | What it cleans |
|--------|----------------|
| `xcode` | DerivedData, Archives, DeviceSupport, CoreSimulator, SwiftPM caches |
| `docker` | Build cache, dangling images, stopped containers; optional volumes with `--volumes` |
| `android` | Android Studio caches, AVDs, Gradle caches, SDK temp files |
| `flutter` | Pub cache, `build/` artifacts in dev folders |
| `node` | npm, pnpm, and Yarn caches |
| `python` | pip, uv, and Poetry caches |
| `rust` | Cargo registry and git cache |
| `go` | Go build and module cache |
| `java` | Gradle and Maven caches |
| `homebrew` | Old downloads, cleanup, autoremove |
| `abandoned-node-modules` | Stale `node_modules` in idle projects (see below) |

## Abandoned `node_modules` (the killer feature)

**You choose which folders to scan** — nothing is assumed. Run `cmm configure` to pick from every dev folder found on your Mac (including `~/Downloads` if it exists and contains projects):

```bash
cmm configure
```

The picker shows all discovered folders. Use **↑/↓** to move, **Space** to toggle `(x)`, **Enter** to confirm, then confirm again before saving. Settings are saved to `~/.config/cleanmahmac/scan-roots.txt`.

It finds Node projects (via `package.json` or lockfiles), and if:

1. The project has a `node_modules` directory, and
2. The project hasn't been accessed or modified in **15+ days** (configurable in `configs/rules.json`)

…it marks that `node_modules` as reclaimable.

**Safety:** `~/Downloads` and other user folders are protected from wholesale deletion — only `node_modules` inside projects you opted into can be removed, and only after confirmation.

Example output:

```
Found abandoned projects

~/Projects/chat-app
Last active: 48 days ago
node_modules: 1.8 GB

~/Projects/old-dashboard
Last active: 92 days ago
node_modules: 3.4 GB

Total reclaimable: 5.2 GB
```

Run `npm install` (or your package manager) anytime to restore dependencies. Your source code is never touched.

## Doctor

`cmm doctor` detects anomalies without deleting anything:

- Non-executable repo scripts (run `cmm fix-permissions`)
- Huge `Docker.raw` VM disks
- Excessive iOS simulators
- Abandoned `node_modules`
- Giant log files (>500 MB)
- Duplicate Android SDK versions
- Oversized caches (Xcode, Gradle, npm, Homebrew)
- Orphaned Docker volumes
- Large forgotten Xcode archives

## Example reclaimed space

Typical results on a well-used dev Mac (your mileage will vary):

| Target | Typical savings |
|--------|-----------------|
| Xcode DerivedData | 5–30 GB |
| Abandoned node_modules | 2–15 GB |
| Docker system prune | 1–20 GB |
| npm + Homebrew caches | 500 MB–5 GB |
| Android Gradle cache | 1–10 GB |

Run `cmm scan` to see your actual numbers before deleting anything.

## Configuration

- `configs/rules.json` — thresholds, scan roots, module list
- `configs/safe-paths.txt` — paths allowed for deletion
- `configs/protected-paths.txt` — paths never touched

## Adding a new cleaner

1. Create `scripts/dev/my-tool.sh` with two functions:
   - `cmm_scan_my_tool()` — populate results via `cmm_add_scan_result`
   - `cmm_clean_my_tool()` — scan, show totals, confirm, call `cmm_safe_remove`
2. Add `"my-tool"` to `configs/rules.json` → `modules`
3. Add safe paths to `configs/safe-paths.txt`
4. Run `cmm scan` to verify

See `scripts/dev/node.sh` for a minimal example.

## Project structure

```
clean-mah-mac/
├── cmm                 # CLI entrypoint (the command you run)
├── install.sh
├── uninstall.sh
├── configs/
├── scripts/
│   ├── scan.sh
│   ├── report.sh
│   ├── doctor.sh
│   ├── clean.sh
│   ├── all.sh
│   ├── dev/            # One module per cleaner
│   └── utils/          # Shared helpers
├── tests/
└── docs/
```

## Development

```bash
# Run tests
./tests/run-tests.sh

# Lint
shellcheck -x cmm scripts/**/*.sh
```

---
