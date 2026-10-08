# Home Manager session variables (GTK/QT theming, PATH, ...).
# HM only ships the POSIX version once programs.fish is off, so translate it.
if type -q babelfish
    for f in /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh \
        $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
        if test -r $f
            babelfish <$f | source
            break
        end
    end
end

fish_add_path -g $HOME/.local/bin $HOME/.config/emacs/bin # Doom emacs

status is-interactive; or exit

set -gx EDITOR nvim
set -gx VISUAL nvim
set -g fish_greeting

# ── Aliases ──────────────────────────────────────────────────────────────────
alias ll eza
alias ls 'eza -lah --icons auto'
alias tree 'eza --tree --icons'
alias cd z # zoxide
alias gs 'git status'
alias ga 'git add'
alias gc 'git commit'
alias vi nvim
alias vim nvim
alias neovim nvim
# SSHFS mount for workstation and JURECA
alias mws 'sshfs lbaracco@medpc057.ime.kfa-juelich.de:/home/lbaracco /mnt/workpc/ && sshfs lbaracco@medpc057.ime.kfa-juelich.de:/ /mnt/workroot/'
alias mju 'sshfs -o AddressFamily=inet -o IdentityFile=$HOME/.ssh/id_jureca -o follow_symlinks,reconnect,ServerAliveInterval=15 baracco1@jureca.fz-juelich.de:/p /mnt/jureca/'
# Claude Code read-only Ask mode (agent + Bash hook in ~/.claude)
alias ask 'CLAUDE_ASK_MODE=1 claude --agent ask'
# Rebuild shortcuts
alias nfu 'cd ~/nixos && nix flake update --commit-lock-file'
alias nrs 'nh os switch $HOME/nixos#$hostname'
alias nrt 'nh os test $HOME/nixos#$hostname'
alias nrb 'nh os boot $HOME/nixos#$hostname'

# ── Oxocarbon (base16-oxocarbon-dark) ────────────────────────────────────────
set -g fish_color_normal f2f4f8
set -g fish_color_command 42be65
set -g fish_color_keyword be95ff
set -g fish_color_quote 33b1ff
set -g fish_color_redirection ff7eb6
set -g fish_color_end ee5396
set -g fish_color_error ee5396 --bold
set -g fish_color_param f2f4f8
set -g fish_color_comment 525252
set -g fish_color_operator ff7eb6
set -g fish_color_escape 82cfff
set -g fish_color_autosuggestion 525252
set -g fish_color_cwd 42be65
set -g fish_color_cwd_root ee5396
set -g fish_color_option 78a9ff
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=393939
set -g fish_color_search_match --background=393939
set -g fish_pager_color_prefix 42be65 --bold
set -g fish_pager_color_completion f2f4f8
set -g fish_pager_color_description 525252
set -g fish_pager_color_progress ee5396 --bold

# ── Tools ────────────────────────────────────────────────────────────────────
type -q zoxide; and zoxide init fish | source
if type -q starship; and test "$TERM" != dumb
    starship init fish | source
end
