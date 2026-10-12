# Minimal bash config for HPC (JSC) hosts, mirroring fish/config.fish.
# Dependency-free: only coreutils + bash; nvim/starship/git used if present.

# System defaults (provides `module` on JSC)
[ -f /etc/bashrc ] && . /etc/bashrc

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Keep scp/rsync/sftp sessions clean
[[ $- == *i* ]] || return

# ── Host profile ─────────────────────────────────────────────────────────────
# Set DOTFILES_PROFILE beforehand to override. Read by tmux (hpc.conf).
# TODO understand this
if [ -z "${DOTFILES_PROFILE:-}" ]; then
    case "${HOSTNAME%%.*}" in
    jr* | jw* | jusuf*) DOTFILES_PROFILE=hpc ;;
    *) [ -n "${SYSTEMNAME:-}" ] && DOTFILES_PROFILE=hpc || DOTFILES_PROFILE=desktop ;;
    esac
fi
export DOTFILES_PROFILE

# ── Terminal ─────────────────────────────────────────────────────────────────
# Unknown TERM (e.g. xterm-ghostty without terminfo) breaks tmux/less/vim.
# Only downgrades when infocmp exists and positively reports the entry missing.
if command -v infocmp >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "$TERM" != dumb ] &&
    ! infocmp "$TERM" >/dev/null 2>&1; then
    export TERM=xterm-256color
fi

# ── Editor ───────────────────────────────────────────────────────────────────
for _ed in nvim vim vi; do
    if command -v "$_ed" >/dev/null 2>&1; then
        export EDITOR="$_ed" VISUAL="$_ed"
        break
    fi
done
unset _ed

# ── Shell options ────────────────────────────────────────────────────────────
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize globstar autocd cdspell

# ── Aliases ──────────────────────────────────────────────────────────────────
alias ls='ls --color=auto -lah'
alias ll='command ls --color=auto'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
if command -v nvim >/dev/null 2>&1; then
    alias vi=nvim vim=nvim neovim=nvim
fi

# ── Prompt ───────────────────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1 && [ "$TERM" != dumb ]; then
    [ "$DOTFILES_PROFILE" = hpc ] && export STARSHIP_CONFIG="$HOME/.config/starship-hpc.toml"
    eval "$(starship init bash)"
else
    # Oxocarbon: green host, blue cwd, purple branch
    __git_branch() {
        local b
        b=$(git symbolic-ref --short HEAD 2>/dev/null) || return
        printf ' (%s)' "$b"
    }
    command -v git >/dev/null 2>&1 || __git_branch() { :; }
    PS1='\n\[\e[38;2;66;190;101m\]\u@\h\[\e[0m\] \[\e[38;2;120;169;255m\]\w\[\e[38;2;190;149;255m\]$(__git_branch)\[\e[0m\]\n\$ '
fi
