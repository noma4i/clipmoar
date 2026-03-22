#!/bin/bash
set -euo pipefail

CMD="${1:-help}"
TAB="${2:-}"
OUT="/tmp/clipmoar_screenshot.png"

open_prefs() {
    osascript -e '
    tell application "System Events"
        tell process "ClipMoar"
            set frontmost to true
            click menu bar item 1 of menu bar 2
            delay 0.3
            click menu item "Preferences..." of menu 1 of menu bar item 1 of menu bar 2
        end tell
    end tell' 2>/dev/null
}

click_tab() {
    local tab_name="$1"
    local row
    case "$tab_name" in
        general|General)       row=1 ;;
        hotkeys|Hotkeys)       row=2 ;;
        look|Look)             row=3 ;;
        rules|Rules)           row=5 ;;
        transforms|Transforms) row=6 ;;
        regex|Regex)           row=7 ;;
        images|Images)         row=8 ;;
        ignore|Ignore)         row=9 ;;
        ai|AI)                 row=10 ;;
        about|About)           row=12 ;;
        *) echo "Unknown tab: $tab_name"; return 1 ;;
    esac
    osascript -e "
    tell application \"System Events\"
        tell process \"ClipMoar\"
            set frontmost to true
            delay 0.2
            tell window 1
                tell group 1
                    tell splitter group 1
                        tell group 1
                            tell scroll area 1
                                tell outline 1
                                    select row $row
                                end tell
                            end tell
                        end tell
                    end tell
                end tell
            end tell
        end tell
    end tell" 2>/dev/null
}

take_shot() {
    osascript -e '
    tell application "System Events"
        tell process "ClipMoar"
            set frontmost to true
        end tell
    end tell' 2>/dev/null
    sleep 0.3
    screencapture -x "$OUT"
    echo "$OUT"
}

case "$CMD" in
    prefs)
        open_prefs
        sleep 0.5
        if [ -n "$TAB" ]; then
            click_tab "$TAB"
            sleep 0.3
        fi
        take_shot
        ;;
    panel)
        osascript -e '
        tell application "System Events"
            tell process "ClipMoar"
                set frontmost to true
                click menu bar item 1 of menu bar 2
                delay 0.3
                click menu item "Show ClipMoar" of menu 1 of menu bar item 1 of menu bar 2
            end tell
        end tell' 2>/dev/null
        sleep 0.5
        take_shot
        ;;
    shot)
        take_shot
        ;;
    debug)
        echo "Dumping accessibility tree of preferences window..."
        osascript -e '
        tell application "System Events"
            tell process "ClipMoar"
                set frontmost to true
                tell window 1
                    return entire contents
                end tell
            end tell
        end tell' 2>&1
        ;;
    *)
        echo "Usage: ./scripts/ui.sh <command> [tab]"
        echo ""
        echo "Commands:"
        echo "  prefs [tab]   Open Preferences (tab: general, hotkeys, look, rules,"
        echo "                transforms, regex, images, ignore, ai, about)"
        echo "  panel         Show floating clipboard panel"
        echo "  shot          Screenshot current state"
        echo "  debug         Dump accessibility tree of preferences window"
        ;;
esac
