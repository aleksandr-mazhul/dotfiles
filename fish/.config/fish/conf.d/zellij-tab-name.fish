# Port tmux's automatic-rename (on by default, tmux/.tmux.conf never turns
# it off) to zellij: rename THIS pane's tab after the program it runs, back
# to "fish" once it exits, so the PowerKit bar shows "nvim"/"claude"/"npm"
# instead of "Tab #N" forever. Active only inside zellij ($ZELLIJ set).
#
# Like tmux, a manual rename turns auto-rename off for that tab: we only
# ever touch a tab whose current name is still zellij's default ("Tab #N")
# or the last name we set ourselves, tracked per session+tab under
# $XDG_RUNTIME_DIR/zellij-autoname/ so a later command leaves a manual name
# alone. Targets the tab by stable ID (never the focused tab): a command
# can finish while the user has moved on to another tab.
#
# The zellij/jq calls run in a separate `fish --no-config` process that
# sources this same file: fish cannot background a function or a begin/end
# block (`&` on one still runs in the foreground), and these hooks fire on
# every command.
set -g __zjautoname_file (status filename)

function __zjautoname_dir
    set -l rt $XDG_RUNTIME_DIR
    test -n "$rt"; or set rt /tmp
    echo "$rt/zellij-autoname"
end

# __zjautoname_progname CMDLINE: basename of the program that would
# actually run, skipping leading VAR=val assignments and any
# env/sudo/command/builtin/exec wrappers.
function __zjautoname_progname
    set -l tokens
    for tok in (string split ' ' -- $argv[1])
        test -n "$tok"; and set -a tokens $tok
    end
    test (count $tokens) -gt 0; or return 1

    set -l i 1
    while test $i -le (count $tokens)
        switch $tokens[$i]
            case env sudo command builtin exec
                set i (math $i + 1)
                continue
        end
        if string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- $tokens[$i]
            set i (math $i + 1)
            continue
        end
        break
    end
    test $i -le (count $tokens); or return 1
    path basename $tokens[$i]
end

# __zjautoname_apply NEWNAME: rename $ZELLIJ_PANE_ID's tab to NEWNAME,
# unless that tab has been renamed manually since we last touched it.
# Resolves the tab by stable ID so a background pane's rename lands on
# its own tab, not on whichever tab currently has focus.
# __zjautoname_apply NEWNAME SEQ: runs serialised under flock (see spawn).
# SEQ orders this shell's events; a worker older than the last one applied
# for this pane is stale and does nothing, so the latest event always wins.
function __zjautoname_apply
    set -q ZELLIJ_PANE_ID; or return 1
    set -l sess (string replace -a / _ -- "$ZELLIJ_SESSION_NAME")
    set -l seq_file (__zjautoname_dir)/"$sess-pane$ZELLIJ_PANE_ID.seq"
    set -l last_seq 0
    test -f "$seq_file"; and read last_seq <"$seq_file"
    test "$argv[2]" -gt "$last_seq" 2>/dev/null; or return 0
    echo $argv[2] >"$seq_file"

    set -l info (zellij action list-panes -a --json 2>/dev/null \
            | jq -r --arg id "$ZELLIJ_PANE_ID" \
                '.[] | select(.is_plugin == false and (.id | tostring) == $id) | "\(.tab_id)\t\(.tab_name)"' 2>/dev/null)
    test -n "$info"; or return 1
    set -l tab_id (string split -f1 \t -- $info)
    set -l cur_name (string split -f2 \t -- $info)
    test -n "$tab_id"; or return 1

    set -l state_file (__zjautoname_dir)/"$sess-$tab_id"
    set -l last_auto
    test -f "$state_file"; and set last_auto (cat "$state_file" 2>/dev/null)

    if not string match -qr '^Tab #[0-9]+$' -- "$cur_name"
        and test "$cur_name" != "$last_auto"
        return 0 # renamed by hand since — leave it alone, like tmux
    end

    zellij action rename-tab-by-id "$tab_id" "$argv[1]" >/dev/null 2>&1
    echo "$argv[1]" >"$state_file" 2>/dev/null
end

# __zjautoname_spawn NEWNAME: run __zjautoname_apply in a detached process.
# Workers queue on one flock, so a quick command's preexec/postexec pair
# cannot interleave; the sequence number drops whichever arrives stale.
set -g __zjautoname_seq 0
function __zjautoname_spawn
    set -g __zjautoname_seq (math $__zjautoname_seq + 1)
    set -l dir (__zjautoname_dir)
    test -d $dir; or mkdir -p $dir
    command flock $dir/lock fish --no-config \
        -c 'source $argv[1]; __zjautoname_apply $argv[2] $argv[3]' \
        $__zjautoname_file $argv[1] $__zjautoname_seq </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
end

if status is-interactive
    function __zjautoname_preexec --on-event fish_preexec
        set -q ZELLIJ; or return
        command -q zellij; or return
        command -q jq; or return
        command -q flock; or return
        set -l prog (__zjautoname_progname $argv[1])
        test -n "$prog"; or return
        __zjautoname_spawn $prog
    end

    function __zjautoname_postexec --on-event fish_postexec
        set -q ZELLIJ; or return
        command -q zellij; or return
        command -q jq; or return
        command -q flock; or return
        __zjautoname_spawn fish
    end
end
