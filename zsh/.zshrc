source ~/.zsh/.zsh_core

export PATH="$HOME/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Machine-specific overrides (not tracked)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
