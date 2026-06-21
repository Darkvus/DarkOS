# darkOS — bashrc
case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# Colores
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'

# Desarrollo
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# darkOS
alias darkos-ai='/usr/local/bin/darkos-ai'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='ss -tulnp'

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Editor default
export EDITOR=code
export VISUAL=code

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# Neofetch al iniciar sesión SSH
if [[ -n "$SSH_CONNECTION" ]] && command -v neofetch &>/dev/null; then
    neofetch --source /etc/skel/.config/neofetch/ascii.txt 2>/dev/null || neofetch
fi
