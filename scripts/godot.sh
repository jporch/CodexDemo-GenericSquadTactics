#!/bin/sh
# Run from any directory. Override GODOT_BIN if Godot moves.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
if [ ! -x "$GODOT_BIN" ]; then
    echo "Godot executable not found: $GODOT_BIN. Set GODOT_BIN to its path." >&2
    exit 1
fi
mkdir -p "$PROJECT_DIR/.godot/logs"
case "${1:-run}" in
    version)
        exec "$GODOT_BIN" --version
        ;;
    editor)
        exec "$GODOT_BIN" --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/editor.log" --editor
        ;;
    run)
        exec "$GODOT_BIN" --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/game.log"
        ;;
    check)
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/import.log" --import
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/tests.log" --script res://tests/test_battle.gd
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/patrol-tests.log" --script res://tests/test_patrol.gd
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/scene-tests.log" --script res://tests/test_scene.gd
        "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/smoke.log" --quit-after 60
        if grep -E 'SCRIPT ERROR:|ERROR:' "$PROJECT_DIR/.godot/logs/import.log" "$PROJECT_DIR/.godot/logs/tests.log" "$PROJECT_DIR/.godot/logs/patrol-tests.log" "$PROJECT_DIR/.godot/logs/scene-tests.log" "$PROJECT_DIR/.godot/logs/smoke.log"; then
            exit 1
        fi
        ;;
    export)
        mkdir -p "$PROJECT_DIR/builds/web"
        touch "$PROJECT_DIR/builds/.gdignore"
        exec "$GODOT_BIN" --headless --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/export.log" --export-release Web "$PROJECT_DIR/builds/web/index.html"
        ;;
    serve)
        exec python3 -m http.server 8060 --bind 127.0.0.1 --directory "$PROJECT_DIR/builds/web"
        ;;
    preview-effects)
        exec "$GODOT_BIN" --path "$PROJECT_DIR" --log-file "$PROJECT_DIR/.godot/logs/effects-preview.log" --script res://tools/render_attack_effects.gd
        ;;
    *)
        echo "Usage: sh scripts/godot.sh [version|editor|run|check|export|serve|preview-effects]" >&2
        exit 2
        ;;
esac
