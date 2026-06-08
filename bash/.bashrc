#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.emacs.d/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/lorenzo/miniconda3/bin/conda' 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
  eval "$__conda_setup"
else
  if [ -f "/home/lorenzo/miniconda3/etc/profile.d/conda.sh" ]; then
    . "/home/lorenzo/miniconda3/etc/profile.d/conda.sh"
  else
    export PATH="/home/lorenzo/miniconda3/bin:$PATH"
  fi
fi
unset __conda_setup
# <<< conda initialize <<<


#[ -f /opt/miniconda3/etc/profile.d/conda.sh ] && source /opt/miniconda3/etc/profile.d/conda.sh

. "$HOME/.local/share/../bin/env"

# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

case ":$PATH:" in
    *:/home/lorenzo/.juliaup/bin:*)
        ;;

    *)
        export PATH=/home/lorenzo/.juliaup/bin${PATH:+:${PATH}}
        ;;
esac
# Tab completion for juliaup and julia channel selection
[ -f "/home/lorenzo/.julia/juliaup/completions/bash.sh" ] && source "/home/lorenzo/.julia/juliaup/completions/bash.sh"

# <<< juliaup initialize <<<
