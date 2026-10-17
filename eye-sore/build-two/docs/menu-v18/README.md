# Menu preview and score selector (v18)

The title screen renders the selected campaign level's authored geometry in the same 640 × 360 viewport used by play. An independent camera moves through four short room shots and fades between them so it never crosses a closed gameplay door. The world stays paused. Creature instances are hidden during the title preview and restored, along with the player's camera, when Play begins. Returning to title builds a fresh world and starts the preview again. The original concept title art remains an image fallback if a camera preview cannot start.

The left-side menu keeps the world visible. Settings are collapsed until opened. The soundtrack arrows cycle through the original title cue and nine level cues; the selected title and style are shown and the choice persists. Cycling replaces the menu player's loop. Starting a level stops that player and starts the level's own music; returning to title resumes the selected preview cue.

Actual menu frames for Pale Ward, Ash Citadel and Occupied Line are in `concepts/menu-v18/`. `tools/check_menu_v18.gd` exercises title/play/return ownership, enemy visibility, camera restoration and track controls. `tools/capture_menu_v18.gd` captures actual renderer frames. Camera framing, pacing and music appeal still require player review.
