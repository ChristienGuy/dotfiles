source ~/.zsh/.zsh_core

export PATH="$HOME/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Machine-specific overrides (not tracked)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# pnpm
export PNPM_HOME="/Users/christien.guy/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
