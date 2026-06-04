# Plan: Nix-based Laptop Setup Repository

## Summary
A Nix Flakes + Home Manager repo that bootstraps a brand-new Linux or macOS machine from scratch —
installing global tools, dotfiles, fonts — and provides per-project development environments via
direnv-activated devShells. A Makefile is the single entry point for all operations.

---

## Architecture

### Global tools (Home Manager — always installed)
**Core:** git, tmux, eza, bat, fd, fzf, ripgrep, jq, yq, zoxide, direnv, nix-direnv, node, npm
**Ops:** kubectl, awscli2, google-cloud-sdk, azure-cli, stern, k9s
**macOS only:** colima, docker-client (CLI), ghostty, rectangle
**Linux only:** docker (full, with daemon)
**Post-install via npm:** claude-code

### Per-project tools (devShell templates — activated by direnv)
go, python, rust, ruby, ansible, terraform, opentofu

### Dotfiles (existing files, managed by Home Manager)
.zshrc, p10k.zsh, .tmux.conf, .gitconfig (with __GIT_USER__/__GIT_EMAIL__ placeholders), .emacs

### oh-my-zsh plugins
git, docker, kubectl, gcloud, aws, fzf, z

---

## Repository Layout

```
laptop-setup/
├── Makefile                        # bootstrap, switch, update, build, diff, rollback
├── flake.nix                       # Flake: home-manager input + template outputs
├── flake.lock                      # Pinned dependencies
│
├── home/
│   ├── default.nix                 # Base: imports all modules, stateVersion
│   ├── linux.nix                   # Linux profile: extends default, adds docker
│   ├── darwin.nix                  # macOS profile: extends default, adds colima/ghostty/rectangle
│   └── modules/
│       ├── packages.nix            # Core global packages (common to both OS)
│       ├── packages-ops.nix        # Ops tools: kubectl, awscli2, gcloud, azure-cli, stern, k9s
│       ├── zsh.nix                 # ZSH + oh-my-zsh + p10k + zoxide + direnv hooks
│       ├── git.nix                 # programs.git with builtins.getEnv for identity
│       ├── tmux.nix                # home.file wiring for tmux.conf
│       ├── emacs.nix               # home.file wiring for .emacs
│       └── fonts.nix               # MesloLGS Nerd Font (nerd-fonts.meslo-lg)
│
├── dotfiles/
│   ├── zsh/
│   │   ├── zshrc                   # Existing .zshrc (user-provided)
│   │   └── p10k.zsh                # Powerlevel10k config (user-provided or generated)
│   ├── tmux/
│   │   └── tmux.conf               # Existing .tmux.conf (user-provided)
│   ├── git/
│   │   └── gitconfig               # Existing .gitconfig with __GIT_USER__/__GIT_EMAIL__
│   └── emacs/
│       └── emacs                   # Existing .emacs (user-provided)
│
├── templates/                      # Nix flake templates for per-project devShells
│   ├── go/flake.nix
│   ├── python/flake.nix
│   ├── rust/flake.nix
│   ├── ruby/flake.nix
│   ├── ansible/flake.nix
│   ├── terraform/flake.nix
│   └── opentofu/flake.nix
│
└── scripts/
    ├── bootstrap.sh                # One-time: install Nix → home-manager → make switch → npm install claude-code
    └── mkdev.sh                    # Create new project or add toolchain to existing project
```

---

## Makefile Targets

| Target | What it does |
|--------|-------------|
| `make bootstrap` | Run once on new machine |
| `make switch` | Apply config (requires GIT_USER_NAME + GIT_USER_EMAIL env vars) |
| `make build` | Dry-run build without activating |
| `make update` | `nix flake update` then `make switch` |
| `make diff` | Show what would change vs current generation |
| `make rollback` | Roll back to previous home-manager generation |

---

## Key Implementation Notes

### Git identity
`flake.nix` uses `--impure` flag so `home/modules/git.nix` can call `builtins.getEnv "GIT_USER_NAME"`
and `builtins.getEnv "GIT_USER_EMAIL"`. Makefile documents the required env vars. The raw
`dotfiles/git/gitconfig` keeps `__GIT_USER__`/`__GIT_EMAIL__` as human-readable markers; the actual
wiring is done via `programs.git` in Nix (not file substitution).

### Docker on macOS
`colima` provides the Linux VM that runs the Docker daemon. On macOS: `colima start` before using docker.
On Linux: docker daemon runs natively as a system service. The `bootstrap.sh` enables the docker service
on Linux; on macOS it prints a reminder to run `colima start`.

### direnv activation
`home/modules/zsh.nix` adds `eval "$(direnv hook zsh)"` and `eval "$(zoxide init zsh)"` to shell init.
`nix-direnv` is installed globally so devShells are cached (fast re-activation after first build).

### Version pinning (devShell templates)
Templates use `pkgs.go_1_23`, `pkgs.python312`, etc. — nixpkgs selectors that pin to the latest
patch of a specified minor version. The nixpkgs input in each template's flake can be pinned to a
specific commit for exact reproducibility when needed.

### mkdev.sh behaviour
- `mkdev.sh <type> <name>` — creates `~/work/<name>/`, runs `nix flake init -t <laptop-setup>#<type>`,
  creates `.envrc` with `use flake`, runs `direnv allow`. Prints next steps.
- `mkdev.sh add <type>` — run inside an existing project dir; merges the new toolchain's devShell
  packages into the existing `flake.nix`.

---

## Phases

### Phase 1: Scaffold + Bootstrap
**Files:** `Makefile`, `scripts/bootstrap.sh`, `flake.nix`, `home/default.nix`
**Est. ~120 lines**
- Makefile with all targets (switch uses `--impure`, documents env var requirements)
- `bootstrap.sh`: detect OS → install Nix via Determinate Systems installer → install home-manager
  as standalone → call `make switch` → `npm install -g @anthropic-ai/claude-code`
- `flake.nix`: inputs (nixpkgs unstable, home-manager), outputs for linux + darwin profiles,
  templates output block pointing at `./templates/*`
- `home/default.nix`: `imports = [ ./modules/packages.nix ./modules/packages-ops.nix ... ]`,
  `home.stateVersion`
- **Verify:** `nix flake check` passes; `nix flake show` lists both profiles and all templates

### Phase 2: Global packages
**Files:** `home/modules/packages.nix`, `home/modules/packages-ops.nix`, `home/linux.nix`, `home/darwin.nix`
**Est. ~80 lines**
- `packages.nix`: core tools list (git, tmux, eza, bat, fd, fzf, ripgrep, jq, yq, zoxide,
  direnv, nix-direnv, nodejs)
- `packages-ops.nix`: kubectl, awscli2, google-cloud-sdk, azure-cli, stern, k9s
- `linux.nix`: extends default, adds `pkgs.docker`, enables docker service
- `darwin.nix`: extends default, adds colima, docker-client, ghostty, rectangle
- **Verify:** `nix build .#homeConfigurations."<user>@linux"` and darwin variant both succeed

### Phase 3: Dotfiles + Home Manager modules
**Files:** `dotfiles/**` (5 files), `home/modules/zsh.nix`, `git.nix`, `tmux.nix`, `emacs.nix`, `fonts.nix`
**Est. ~100 lines of Nix + user-provided dotfiles**
- Place user's existing dotfiles into `dotfiles/` verbatim
- `zsh.nix`: `programs.zsh.enable`, oh-my-zsh with plugin list, source p10k, direnv hook, zoxide init
- `git.nix`: `programs.git` with `userName = builtins.getEnv "GIT_USER_NAME"`, `userEmail = ...`
- `tmux.nix`, `emacs.nix`: `home.file` pointing at dotfiles source paths
- `fonts.nix`: `home.packages = [ pkgs.nerd-fonts.meslo-lg ]`
- **Verify:** `make switch` (with env vars set) → dotfiles symlinked, `git config user.name` returns correct value, zsh launches with p10k prompt

### Phase 4: Dev environment system
**Files:** `scripts/mkdev.sh`, `templates/go/flake.nix`, `templates/python/flake.nix`,
`templates/rust/flake.nix`, `templates/ruby/flake.nix`, `templates/ansible/flake.nix`,
`templates/terraform/flake.nix`, `templates/opentofu/flake.nix`
**Est. ~250 lines**
- Each template: minimal `flake.nix` with `devShells.default` declaring the toolchain packages
  using nixpkgs selectors (e.g. `pkgs.go_1_23`), plus a `devShell` shellHook that prints the
  active tool versions on entry
- `mkdev.sh`: arg parsing, create/validate project dir under `~/work/`, `nix flake init`,
  write `.envrc`, `direnv allow`; `add` subcommand reads existing flake and merges packages
- **Verify:** `mkdev.sh go test-app` → `cd ~/work/test-app` → direnv activates → `go version` shows 1.23.x;
  `mkdev.sh add python` from inside the dir → `python3 --version` also available

---

## Testing Strategy
- Phase 1: `nix flake check` + `nix flake show`
- Phase 2: `nix build` for both linux and darwin profiles
- Phase 3: `make switch` end-to-end; spot-check symlinks and git identity
- Phase 4: `mkdev.sh` smoke test per template type; `direnv` auto-activation check

---

## Assumptions
- ASSUMPTION: nixpkgs unstable used (not stable) — gives access to latest tool versions and k9s/stern
- ASSUMPTION: `GIT_USER_NAME` and `GIT_USER_EMAIL` env vars must be exported before running `make switch`
- ASSUMPTION: User will copy their existing dotfile content into `dotfiles/` before Phase 3
- ASSUMPTION: ghostty and rectangle are macOS-only; no Linux equivalents needed
- ASSUMPTION: colima is the macOS docker VM (not OrbStack or Rancher Desktop)
- ASSUMPTION: `nerd-fonts.meslo-lg` is the correct nixpkgs attribute for MesloLGS NF
- ASSUMPTION: templates use nixpkgs unstable; individual projects can override with their own nixpkgs pin
