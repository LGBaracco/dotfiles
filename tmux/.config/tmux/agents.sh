#!/usr/bin/env bash
# Per-project agent sessions. Project session P gets a companion session P-agents holding one
# window per Claude agent (new windows there start `claude`). Claude hooks write each agent's
# state to its window option @agent_state; tmux.conf shows it on window tabs and as a strip in P.
# No nested clients: agents are viewed by switching to P-agents, by linking an agent's window
# into P (link-window: the same window in both sessions), or from a separate terminal.
#
#   agents.sh toggle                  switch the client between P and P-agents
#   agents.sh menu <client>           prefix A: agents of P with their state, plus actions
#   agents.sh agent-menu <client> <window_id>   switch / link or unlink / rename / kill
#   agents.sh link <client> <window_id>         show an agent window in P
#   agents.sh unlink [window_id]      remove one (default: all) agent windows from P
#   agents.sh term                    open P-agents in a new terminal window
#   agents.sh new                     start one more agent in P-agents
#   agents.sh forks [dir]             open a window per background/fork session (claude attach)
#   agents.sh strip <P> <colours…>    status segment: one pill per agent of P
#   agents.sh status-format           splice the strip after the window list
#   agents.sh hook                    Claude Code hook entry (event JSON on stdin); a claude
#                                     started in P moves to P-agents
set -u

SUFFIX=-agents
SELF="$(realpath "${BASH_SOURCE[0]}")"
CLIENT="" # set by commands that get the client from their key binding

msg() { tmux display-message ${CLIENT:+-c "$CLIENT"} "agents: $*"; }

agents_of() { printf '%s%s' "$1" "$SUFFIX"; }

# ensure <P> <dir> [cmd [name]]: create P-agents if missing. Its first window runs cmd
# (default: a new claude); new windows there always start claude.
ensure() {
    local p=$1 dir=$2 a
    a=$(agents_of "$p")
    tmux has-session -t "=$a" 2>/dev/null && return 0
    if [[ -n ${4:-} ]]; then
        tmux new-session -d -s "$a" -n "$4" -c "$dir" "$3"
    else
        tmux new-session -d -s "$a" -c "$dir" "${3:-claude}"
    fi
    # Option commands take a pane target: "=name:" is the exact session.
    tmux set-option -t "=$a:" default-command claude
    tmux set-option -t "=$a:" @agents_parent "$p"
    tmux set-option -t "=$a:" @agents_dir "$dir"
    # Last agent exits: move the client back instead of detaching it from tmux.
    tmux set-option -t "=$a:" detach-on-destroy previous
    # Name agent windows after the terminal title claude sets (tmux defaults it to the host).
    tmux set-hook -t "=$a:" after-new-window "run-shell '$SELF name-window #{window_id}'"
    name_window "$(tmux display-message -p -t "=$a:" '#{window_id}')"
}

name_window() {
    tmux set-option -w -t "$1" automatic-rename-format \
        '#{?#{||:#{==:#{pane_title},#{host}},#{==:#{pane_title},#{host_short}}},#{pane_current_command},#{=24;s/^✳ //:pane_title}}'
    color_window "$1"
}

# Current tab of an agent window in the active-agent colour, in P-agents and wherever it is
# linked: the window formats read @theme_purple, and a window option shadows the global one.
color_window() {
    tmux set-option -w -t "$1" @theme_purple "$(tmux display-message -p '#{E:@agents_active}')"
}

# Project session and its directory for the client, also when inside P-agents.
current_project() {
    local s
    s=$(tmux display-message ${CLIENT:+-c "$CLIENT"} -p '#S')
    if [[ $s == *"$SUFFIX" ]]; then
        P=$(tmux show-options -t "=$s:" -qv @agents_parent)
        P=${P:-${s%"$SUFFIX"}}
        DIR=$(tmux show-options -t "=$s:" -qv @agents_dir)
    else
        P=$s
        DIR=$(tmux display-message ${CLIENT:+-c "$CLIENT"} -p '#{session_path}')
    fi
}

cmd_toggle() {
    local s
    s=$(tmux display-message ${CLIENT:+-c "$CLIENT"} -p '#S')
    current_project
    if [[ $s == *"$SUFFIX" ]]; then
        if tmux has-session -t "=$P" 2>/dev/null; then
            tmux switch-client ${CLIENT:+-c "$CLIENT"} -t "=$P"
        else
            tmux switch-client ${CLIENT:+-c "$CLIENT"} -l
        fi
    else
        ensure "$P" "$DIR"
        tmux switch-client ${CLIENT:+-c "$CLIENT"} -t "=$(agents_of "$P")"
    fi
}

glyph_of() {
    case $1 in
        blocked) printf '●' ;;
        working) printf '⦿' ;;
        "done" | idle) printf '○' ;;
        *) printf ' ' ;;
    esac
}

# Menu labels are formats: a literal # must be ##.
label() { printf '%s' "${1//#/##}"; }

cmd_menu() {
    CLIENT=$1
    local a id idx name state args=()
    current_project
    a=$(agents_of "$P")
    if tmux has-session -t "=$a" 2>/dev/null; then
        while IFS=$'\t' read -r id idx state name; do
            local key=""
            ((idx <= 9)) && key=$idx
            args+=("$(label "$idx $(glyph_of "$state")  $name")" "$key" "run-shell '$SELF agent-menu $CLIENT $id'")
        done < <(tmux list-windows -t "=$a" -F '#{window_id}	#{window_index}	#{@agent_state}	#{window_name}')
        args+=("")
        args+=("new agent" n "run-shell '$SELF new'")
        args+=("unlink all from project" u "run-shell '$SELF unlink'")
        args+=("open forks" f "run-shell -b '$SELF forks'")
        args+=("switch to agents" a "run-shell '$SELF toggle'")
        args+=("terminal window" t "run-shell -b '$SELF term'")
    else
        args+=("new agent" n "run-shell '$SELF new'")
    fi
    tmux display-menu -c "$CLIENT" -T "#[align=centre] agents: $(label "$P") " "${args[@]}"
}

# linked_in <window_id> <session>: is the window (also) part of session?
linked_in() {
    local list
    list=$(tmux display-message -p -t "$1" '#{window_linked_sessions_list}')
    [[ ",$list," == *",$2,"* ]]
}

cmd_agent_menu() {
    CLIENT=$1
    local win=$2 a idx name args=()
    current_project
    a=$(agents_of "$P")
    idx=$(tmux list-windows -t "=$a" -F '#{window_id} #{window_index}' | awk -v w="$win" '$1 == w { print $2 }')
    [[ -z $idx ]] && return 0
    name=$(tmux display-message -p -t "$win" '#{window_name}')
    args+=("switch to it" a "switch-client -c '$CLIENT' -t '=$a:$idx'")
    if linked_in "$win" "$P"; then
        args+=("unlink from project" w "run-shell '$SELF unlink $win'")
    else
        args+=("link into project" w "run-shell '$SELF link $CLIENT $win'")
    fi
    args+=("rename" r "command-prompt -p 'rename agent:' \"rename-window -t $win -- '%%'\"")
    args+=("kill" x "confirm-before -p 'kill agent $idx? (y/n)' 'kill-window -t $win'")
    tmux display-menu -c "$CLIENT" -T "#[align=centre] $(label "$name") " "${args[@]}"
}

# link <client> <window_id>: the agent's window also becomes a window of P, and the client
# goes there. Already linked: just go there.
cmd_link() {
    CLIENT=$1
    local win=$2 idx
    current_project
    if ! linked_in "$win" "$P"; then
        tmux link-window -d -s "$win" -t "=$P:"
    fi
    idx=$(tmux list-windows -t "=$P" -F '#{window_id} #{window_index}' | awk -v w="$win" '$1 == w { print $2 }')
    tmux switch-client -c "$CLIENT" -t "=$P:$idx"
}

# unlink [window_id]: remove agent windows from P only; they stay in P-agents.
cmd_unlink() {
    local only=${1:-} a id idx agents
    current_project
    a=$(agents_of "$P")
    agents=$(tmux list-windows -t "=$a" -F '#{window_id}' 2>/dev/null)
    while read -r id idx; do
        [[ -n $only && $id != "$only" ]] && continue
        grep -qxF "$id" <<<"$agents" && tmux unlink-window -t "=$P:$idx"
    done < <(tmux list-windows -t "=$P" -F '#{window_id} #{window_index}')
}

cmd_term() {
    current_project
    ensure "$P" "$DIR"
    # stdin too: run-shell's job socket is its stdin as well, and a terminal holding it open
    # keeps the job "running", which blocks the client that ran it. No TMUX: the new terminal
    # is a separate client, not one inside this one.
    env -u TMUX -u TMUX_PANE setsid -f ghostty -e tmux attach-session -t "=$(agents_of "$P")" \
        </dev/null >/dev/null 2>&1
}

cmd_new() {
    local a
    current_project
    a=$(agents_of "$P")
    if tmux has-session -t "=$a" 2>/dev/null; then
        tmux new-window -d -t "=$a:" -c "$DIR"
    else
        ensure "$P" "$DIR"
    fi
    msg "new agent in $a"
}

# forks [dir]: one window per live background session (forks, --bg) of dir, if not open yet.
cmd_forks() {
    local dir=${1:-} a id sid name win
    if [[ -n $dir ]]; then
        # From a hook: the agents session for dir, else the project session started there.
        a=$(tmux list-sessions -F '#{session_name}	#{@agents_dir}' | awk -F '\t' -v d="$dir" '$2 == d { print $1; exit }')
        if [[ -n $a ]]; then
            P=$(tmux show-options -t "=$a:" -qv @agents_parent)
        else
            P=$(tmux list-sessions -F '#{session_name}	#{session_path}' | awk -F '\t' -v d="$dir" -v s="$SUFFIX" '$2 == d && $1 !~ s"$" { print $1; exit }')
            [[ -z $P ]] && return 0
        fi
    else
        current_project
        dir=$DIR
    fi
    a=$(agents_of "$P")

    local opened=0
    while IFS=$'\t' read -r id sid name; do
        [[ -z $id ]] && continue
        tmux list-windows -a -F '#{@agent_session_id}' | grep -qxF "$sid" && continue
        if tmux has-session -t "=$a" 2>/dev/null; then
            win=$(tmux new-window -d -P -F '#{window_id}' -t "=$a:" -n "fork:${name:0:20}" -c "$dir" "claude attach $id")
        else
            # No agents session yet: the fork becomes its first window (no extra claude).
            ensure "$P" "$dir" "claude attach $id" "fork:${name:0:20}"
            win=$(tmux display-message -p -t "=$a:" '#{window_id}')
        fi
        tmux set-option -w -t "$win" @agent_session_id "$sid"
        color_window "$win"
        opened=$((opened + 1))
    done < <(claude agents --json --cwd "$dir" 2>/dev/null |
        jq -r '.[] | select(.kind == "background") | [.id, .sessionId, (.name // .id)] | @tsv')
    [[ -z ${1:-} ]] && msg "$opened fork window(s) opened in $a"
    return 0
}

# strip <P> <bg> <fg> <gray> <active> <red> <yellow> <green> [client_width]
# With the client width, the strip fits the room the session pill and window list leave:
# names get shorter, then only indexes are shown, then nothing. A strip wider than the
# status line makes tmux drop the window list and the strip with it.
cmd_strip() {
    local p=$1 bg=$2 fg=$3 gray=$4 active=$5 red=$6 yellow=$7 green=$8 width=${9:-0}
    local a out plain prev idx name state current seg text glyph i max budget=-1 left list
    local arrow=$'\xee\x82\xb0' # powerline U+E0B0, as in the window list
    local -a idxs=() currents=() names=() states=()
    [[ $p == *"$SUFFIX" ]] && return 0
    a=$(agents_of "$p")
    tmux has-session -t "=$a" 2>/dev/null || return 0
    while IFS=$'\t' read -r idx current name state; do
        idxs+=("$idx") currents+=("$current") names+=("$name") states+=("$state")
    done < <(tmux list-windows -t "=$a" -F '#{window_index}	#{window_active}	#{window_name}	#{@agent_state}')
    if ((width > 0)); then
        read -r left list < <(tmux display-message -p -t "=$p:" \
            '#{w:#{T:status-left}} #{w:#{W:#{T:window-status-format},#{T:window-status-current-format}}}')
        budget=$((width - left - list - 1))
    fi

    for max in 24 12 6 0; do
        out="" plain=" " prev=$bg
        for i in "${!idxs[@]}"; do
            name=${names[i]}
            ((${#name} > max)) && name="${name:0:max-1}…"
            ((max == 0)) && name=""
            # Inactive agents share the gray band like inactive windows; the active one is a pill.
            if [[ ${currents[i]} == 1 ]]; then seg=$active text=$bg; else seg=$gray text=$fg; fi
            case ${states[i]} in
                blocked) glyph="#[fg=$red]● " ;;
                working) glyph="#[fg=$yellow]⦿ " ;;
                "done") glyph="#[fg=$green]○ " ;;
                "") glyph="" ;;
                *) glyph="○ " ;; # idle: uncoloured, as on window tabs
            esac
            # Arrow only where the colour changes (start, gray↔active), as in the window list.
            [[ $seg != "$prev" ]] && out+="#[fg=$prev,bg=$seg]$arrow" plain+=$arrow
            out+="#[fg=$text,bg=$seg] ${idxs[i]} ${name:+$name }$glyph"
            plain+=" ${idxs[i]} ${name:+$name }${glyph:+x }"
            prev=$seg
        done
        plain+=$arrow
        ((budget < 0 || ${#plain} <= budget)) && break
    done
    ((budget >= 0 && ${#plain} > budget)) && return 0
    # Leading space on the status background, like the gap after the session pill.
    printf '#[bg=%s] %s#[fg=%s,bg=%s]%s#[default]' "$bg" "$out" "$prev" "$bg" "$arrow"
}

# status-format: put #{E:@agents_strip} right after the window list. Rebuilt from tmux's
# default every time, so reloading the config never splices it in twice.
cmd_status_format() {
    local f
    tmux set-option -gu status-format
    f=$(tmux show-options -gv 'status-format[0]')
    [[ $f == *'#[nolist align=right'* ]] || return 0
    f=${f/'#[nolist align=right'/'#[nolist]#{E:@agents_strip}#[align=right'}
    tmux set-option -g 'status-format[0]' "$f"
}

# from_pane_shell <pane_pid>: the claude running this hook (an ancestor) is the pane's command
# or a child of its shell, and is interactive (no -p). Not when it runs inside another program.
from_pane_shell() {
    local pid=$PPID parent _
    for _ in 1 2 3 4 5 6; do
        parent=$(ps -o ppid= -p "$pid" | tr -d ' ')
        if [[ $pid == "$1" || $parent == "$1" ]]; then
            [[ $(ps -o comm= -p "$pid") == *claude* ]] || return 1
            ! tr '\0' '\n' <"/proc/$pid/cmdline" | grep -qxE -- '-p|--print'
            return
        fi
        [[ -z $parent || $parent == 1 ]] && return 1
        pid=$parent
    done
    return 1
}

# push: a claude started in a pane of project session P moves to P-agents (its whole window,
# or just its pane if the window has others), and the clients showing it follow it there.
# Only a claude run from the pane's shell: not one inside another program (e.g. a Neovim
# terminal, whose tmux pane is Neovim's), not an agent window linked into P, not P's last window.
push() {
    local pane=$TMUX_PANE s win panes wins linked ppid dir a tmp="" c clients
    IFS=$'\t' read -r s win panes wins linked ppid dir < <(tmux display-message -p -t "$pane" \
        '#{session_name}	#{window_id}	#{window_panes}	#{session_windows}	#{window_linked}	#{pane_pid}	#{session_path}')
    [[ -z $s || $s == *"$SUFFIX" || $linked == 1 ]] && return 0
    ((panes == 1 && wins == 1)) && return 0
    from_pane_shell "$ppid" || return 0

    a=$(agents_of "$s")
    if ! tmux has-session -t "=$a" 2>/dev/null; then
        # The session needs a first window; a placeholder, gone once the agent is in.
        ensure "$s" "$dir" "sleep 60"
        tmp=$(tmux display-message -p -t "=$a:" '#{window_id}')
    fi
    clients=$(tmux list-clients -F '#{client_name}	#{window_id}' | awk -F '\t' -v w="$win" '$2 == w { print $1 }')
    if ((panes == 1)); then
        tmux move-window -d -s "$win" -t "=$a:"
    else
        tmux break-pane -d -s "$pane" -t "=$a:"
    fi
    [[ -n $tmp ]] && tmux kill-window -t "$tmp"
    name_window "$(tmux display-message -p -t "$pane" '#{window_id}')"
    for c in $clients; do tmux switch-client -c "$c" -t "$pane"; done
}

# forget_session <sid> <window_id>: unset the session's id and state on all other windows.
forget_session() {
    local id
    tmux list-windows -a -F '#{window_id}	#{@agent_session_id}' |
        awk -F '\t' -v s="$1" -v w="$2" '$2 == s && $1 != w { print $1 }' | sort -u |
        while read -r id; do
            tmux set-option -w -u -t "$id" @agent_session_id
            tmux set-option -w -u -t "$id" @agent_state
        done
}

# hook: Claude Code hook entry. Never prints (stdout of some events is fed to the model).
cmd_hook() {
    local event ntype source sid agent cwd state="" win=""
    command -v tmux >/dev/null || return 0
    # \x1f, not tab: whitespace IFS collapses empty fields and shifts the rest.
    IFS=$'\x1f' read -r event ntype source sid agent cwd < <(
        jq -r '[.hook_event_name // "", .notification_type // "", .source // "",
                .session_id // "", .agent_id // "", .cwd // ""] | join("\u001f")'
    )

    case $event in
        SessionStart) state=idle ;;
        UserPromptSubmit | PreToolUse | PostToolUse) state=working ;;
        PermissionRequest) state=blocked ;;
        Notification)
            case $ntype in
                permission_prompt | agent_needs_input) state=blocked ;;
                idle_prompt) state=idle ;;
                *) return 0 ;;
            esac
            ;;
        Stop) state="done" ;;
        SessionEnd) state=clear ;;
        *) return 0 ;;
    esac
    # Subagents only report activity; their stop/idle must not overwrite the parent's state.
    [[ -n $agent && $state != working ]] && return 0

    # New or resumed claude in a project session (not /clear or compaction): to its agents.
    if [[ $event == SessionStart && $source =~ ^(startup|resume)$ && -n ${TMUX_PANE:-} ]]; then
        push
    fi

    if [[ -n ${TMUX_PANE:-} ]]; then
        win=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)
        if [[ -n $win && -n $sid && $state != clear ]]; then
            # A session lives in one window: drop it from any other, where a claude left without
            # SessionEnd (else fork hooks, which find windows by session id, light that one up).
            [[ $event == SessionStart ]] && forget_session "$sid" "$win"
            tmux set-option -w -t "$win" @agent_session_id "$sid"
        fi
    elif [[ -n $sid ]]; then
        # Background session (fork): runs under the claude daemon, found by its session id.
        win=$(tmux list-windows -a -F '#{window_id}	#{@agent_session_id}' 2>/dev/null |
            awk -F '\t' -v s="$sid" '$2 == s { print $1; exit }')
        if [[ -z $win && $event == SessionStart && $source == fork && -n $cwd ]]; then
            (sleep 2 && "$SELF" forks "$cwd") </dev/null >/dev/null 2>&1 &
            disown
        fi
    fi
    [[ -z $win ]] && return 0

    if [[ $state == clear ]]; then
        tmux set-option -w -u -t "$win" @agent_state
        tmux set-option -w -u -t "$win" @agent_session_id
    else
        tmux set-option -w -t "$win" @agent_state "$state"
    fi
}

case ${1:-} in
    toggle) cmd_toggle ;;
    menu) cmd_menu "${2:-}" ;;
    agent-menu) cmd_agent_menu "${2:-}" "${3:-}" ;;
    link) cmd_link "${2:-}" "${3:-}" ;;
    unlink) cmd_unlink "${2:-}" ;;
    term) cmd_term ;;
    new) cmd_new ;;
    forks) cmd_forks "${2:-}" ;;
    strip) shift; cmd_strip "$@" ;;
    status-format) cmd_status_format ;;
    hook) cmd_hook >/dev/null 2>&1 ;;
    name-window) name_window "$2" ;;
    *)
        echo "usage: agents.sh toggle|menu|agent-menu|link|unlink|term|new|forks|strip|status-format|hook" >&2
        exit 2
        ;;
esac
exit 0
