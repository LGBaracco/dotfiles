if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# Keep scp/rsync/sftp sessions clean
[[ $- == *i* ]] || return

# Set DOTFILES_PROFILE beforehand to override. Read by tmux (hpc.conf) and
# Neovim (lua/config/pack.lua: plugin/tool profile).
if [ -z "${DOTFILES_PROFILE:-}" ]; then
    case "${HOSTNAME%%.*}" in
    jr* | jw* | jusuf*) DOTFILES_PROFILE=hpc ;;
    *) [ -n "${SYSTEMNAME:-}" ] && DOTFILES_PROFILE=hpc || DOTFILES_PROFILE=desktop ;;
    esac
fi
export DOTFILES_PROFILE

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
alias ll='ls --color=auto -lah'
alias ls='command ls --color=auto'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
# Drop PYTHONPATH: modules (e.g. Python-bundle-PyPI) inject py3.12 site-packages
# that shadow the uv env's packages and break on its newer Python
alias start-server='env -u PYTHONPATH uv run --with jupyter jupyter server --no-browser --ip=0.0.0.0 --port 8888 --MappingKernelManager.default_kernel_name=atlas'
if command -v nvim >/dev/null 2>&1; then
    alias vi=nvim vim=nvim neovim=nvim
    # Off-Nix plugin/tool/parser sync (lua/config/tools.lua); exits 1 on failure
    alias packsync='nvim --headless +PackSync +qa'
fi

# Sets $project
jutil env activate -p cjinm16

if [ -d "$PROJECT/home_ext" ]; then
    export HOME_EXT=$PROJECT/home_ext
    export XDG_CONFIG_HOME=$HOME_EXT/.config
    export XDG_DATA_HOME=$HOME_EXT/.local/share
    export XDG_STATE_HOME=$HOME_EXT/.local/state
    export NPM_CONFIG_CACHE=$HOME_EXT/.npm
    export CONDA_PKGS_DIRS=$HOME_EXT/.conda/pkgs
    export CONDA_ENVS_PATH=$HOME_EXT/.conda/envs
fi
if [ -d "$SCRATCH/$USER" ]; then
    export XDG_CACHE_HOME=$SCRATCH/$USER/.cache
    export APPTAINER_CACHEDIR=$XDG_CACHE_HOME/apptainer
fi

# Galaxy
# Currently disabled because of file conflicts (currently forces old revisions)
#[ -r "$HOME/galaxy/init.sh" ] && . "$HOME/galaxy/init.sh"
#module try-load atlas

# Loading modules
module try-load uv
module try-load tmux/3.5a

# ── Prompt (starship only if installed)
if command -v starship >/dev/null 2>&1 && [ "$TERM" != dumb ]; then
    [ "$DOTFILES_PROFILE" = hpc ] && [ -f "$HOME/.config/starship-hpc.toml" ] &&
        export STARSHIP_CONFIG="$HOME/.config/starship-hpc.toml"
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
