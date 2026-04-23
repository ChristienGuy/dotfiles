# dotfiles

Personal dotfiles for zsh, Claude Code, and Starship — managed with [GNU Stow](https://www.gnu.org/software/stow/).

Each top-level directory (`zsh/`, `claude/`, `starship/`) is a **stow package** whose contents mirror the target layout in `$HOME`. Running `stow <pkg>` creates symlinks from the package into `$HOME`.

## Packages

### `zsh/`
Zsh config, sourced from `~/.zshrc` which lives in the repo.

- **`.zshrc`** — entry point. Sources `.zsh_core`, sets PATH, then sources `~/.zshrc.local` for machine-specific stuff (not tracked).
- **`.zsh/.zsh_core`** — main config: history, Starship, fzf, zoxide, antidote, git-spice completion, `grb-sign`, NVM.
- **`.zsh/.zsh_aliases`** — aliases (`cod`, `curs`, git shortcuts, branch helpers).
- **`.zsh/.zsh_functions`** — functions (`fsb`, `fsbd`, `fslog` — fzf-based git branch helpers).
- **`.zsh/.zsh_plugins.txt`** — antidote plugin list.
- **`.zsh/*.test.zsh`** — ztr tests (not symlinked into `$HOME`; run via `make test`).

### `claude/`
Global Claude Code config. Per-project state, sessions, history, and plugins are intentionally gitignored.

- **`.claude/CLAUDE.md`** — global instructions Claude reads on every session.
- **`.claude/settings.json`** — permissions, hooks, env.
- **`.claude/keybindings.json`** — custom keybindings.
- **`.claude/statusline-command.sh`** — custom status line script.
- **`.claude/hooks/`** — custom hook scripts.

### `starship/`
Starship prompt config at the default location (`~/.config/starship.toml`).

## Install (new machine)

```bash
# 1. Clone
git clone git@github.com:ChristienGuy/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Install prereqs (see table below)
brew install stow antidote git-spice starship fzf zoxide zsh-test-runner

# 3. Back up anything that would collide
mv ~/.zshrc ~/.zshrc.backup 2>/dev/null || true

# 4. Stow everything into $HOME
make install

# 5. (Optional) create machine-specific overrides
touch ~/.zshrc.local
```

## Usage

```bash
make install           # stow all packages
make install-zsh       # stow just the zsh package
make uninstall         # remove all symlinks
make uninstall-zsh     # remove just the zsh symlinks
make restow            # re-stow everything (fixes stale links after reorg)
make lint              # zsh -n syntax check
make test              # run ztr tests
make check             # lint + test
make help              # show all targets
```

## Machine-specific config: `~/.zshrc.local`

The tracked `.zshrc` ends with:

```zsh
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Anything machine-specific — tool-specific PATHs, pyenv versions, Herd/PHP config, vite-plus env, API keys for local tooling — goes in `~/.zshrc.local`, which is **not tracked**.

## Prereqs

| Tool | Purpose | Install |
|------|---------|---------|
| **stow** | Symlink manager (this repo depends on it) | `brew install stow` |
| **antidote** | Zsh plugin manager | `brew install antidote` |
| **git-spice** | Stacked branches + `gs` completion | `brew install git-spice` |
| **starship** | Prompt | `brew install starship` |
| **fzf** | Fuzzy finder (used by `fsb` branch picker) | `brew install fzf` |
| **zoxide** | Smart directory jumper (`z`, `zi`) | `brew install zoxide` |
| **zsh-test-runner** | `make test` runs ztr | `brew install zsh-test-runner` |
| **nvm** | Node version manager (optional) | [nvm install](https://github.com/nvm-sh/nvm#installing-and-updating) |
