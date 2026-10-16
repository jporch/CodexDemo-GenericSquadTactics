# Project guidance

## Purpose and technology
- Build a small, playable proof of concept. Prioritize the core gameplay and easy iteration.
- Use Godot 4.7.2 (verified build: 4.7.2.stable.official.ed1daf0bf) and GDScript.
- Use 2D with a fixed top-down camera and the Compatibility renderer for the Web/HTML5 target.
- Discuss engine upgrades and third-party plugins with the user before introducing them.
- Keep scenes and resources editable in the Godot editor.

## Design and scope
- DESIGN.md records agreed gameplay rules, scope, and acceptance criteria.
- Unanswered worksheet items are unresolved, not approved game requirements.
- Establish the concept and first playable scope with the user before implementing gameplay.
- Implement the smallest complete playable version of each agreed feature.
- Use placeholders until replacements are requested. Make reasonable minor assumptions and report them; ask about ambiguities that materially change gameplay or scope.

## Implementation
- Use reusable scenes for distinct gameplay objects where useful. Keep scripts focused and avoid unnecessary abstractions.
- Expose useful gameplay tuning values in the Inspector.
- Define gameplay controls through Godot's Input Map.
- Keep important scene structure editable in the editor; avoid unrelated changes.
- Track required .uid and .import sidecars and original assets. Ignore .godot/ caches.
- Record third-party asset sources and licenses in assets/README.md if assets are added.

## Validation
- Godot executable: /Applications/Godot.app/Contents/MacOS/Godot.
- From the project root: `sh scripts/godot.sh check` imports resources, runs battle, patrol, and scene integration tests, then runs 60 headless iterations.
- Inspect command output and .godot/logs/ for errors; the wrapper checks import, test, and startup logs for errors as well as exit statuses.
- Use `sh scripts/godot.sh run` for visual playtesting and `sh scripts/godot.sh editor` for the editor.
- The wrapper supports a GODOT_BIN environment override and puts logs inside the workspace.
- Headless startup does not verify rendering, input, sound, or game feel. Test affected gameplay interactively when available.
- Add tests when they meaningfully verify gameplay logic. Report checks actually performed and remaining manual checks.

- Web build: `sh scripts/godot.sh export`; local preview: `sh scripts/godot.sh serve` at http://127.0.0.1:8060. Matching 4.7.2 single-threaded Web templates are installed locally. Keep builds/ generated and ignored, including a .gdignore to prevent reimporting exported assets.
- Unit stats are Inspector-editable resources in resources/. Visual placeholders live in files with a _placeholder suffix.

## Project records and completion
- COMMANDS.md is a historical record. Command recording has stopped at the user's request; do not append new requests unless the user asks to resume.
- Keep README.md current with setup, exact engine version, run instructions, and controls.
- Update DESIGN.md when agreed rules change; preserve explicit scope limits.
- When finishing a task, briefly explain what changed, how to try it, what was verified, and any limitations.
