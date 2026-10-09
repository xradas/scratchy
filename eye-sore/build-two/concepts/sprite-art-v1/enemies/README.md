# Faithful approved-design enemy sprites

Two generated transparent sprite atlases faithfully extend the approved corrupted-biotech board's bottom-left Unsealed and bottom-middle Vessel into eight representative frontal poses. These preserve the approved scarred pale anatomy, long arms and split maw, and the broad caged containment body, tubes, hoses and yellow-green organ. The procedural 3D rigs are preserved separately and are not the source of these pixels.

Final files are `unsealed/atlas.png` and `vessel/atlas.png`. Each is an unchanged 1536×1024 RGBA built-in imagegen output, four columns by two rows, eight 384×512 regions in row-major order. Order: idle, left walk, right walk, committed windup, released strike/shot recovery, pain recoil, death folding, persistent collapsed corpse. There is one frontal direction, not a complete eight-direction production set. All 16 cells have zero meaningful alpha in their two-pixel cell border. No Python raster editing, cropping, painting, resampling or background removal was performed. Python only inspected source pixel data and wrote metadata.

`inspection-final.json` contains each region, per-cell alpha bounds at thresholds32/128, measured bottom contact, proposed foot pivot and an offset to a common local anchor(192,471). The generator kept a regular atlas but did not honor identical raw vertical baselines across rows. Use the per-frame `foot_pivot`, not an assumed one-size origin, to keep the same world foot plane. Draw a region at `destination_anchor - foot_pivot * render_scale`, retaining one consistent scale per creature. The common x192 anchor intentionally retains natural lateral pose movement rather than recentering each alpha bounding box. Unsealed idle visible height335px; Vessel idle312px. For comparable actor sizes choose world scale from those visible heights, not the 512px transparent canvas.

Both files have real alpha0 empty regions: about71% of Unsealed and67% of Vessel pixels. Maximum source alpha254 is a generator property and was preserved. The source viewer displays a brown background from RGB values under transparency, but actual Godot alpha composition is clean. `review/near-640.png` and `review/poses-640.png` were inspected: they are actual native640×360 Godot captures drawing atlas regions directly over a dark background with nearest filtering and per-frame pivots, not edited atlas exports. The dark background, captions and arrangement exist only in the preview scene.

## Provenance

The imagegen skill was used in built-in `image_gen.imagegen` EDIT mode, always with `transparent_background=true`. The approved board was a supplied edit reference on every call. Two initial calls created one complete pose atlas per monster. Two layout-only corrections removed cell overflow. One targeted Vessel recovery-cell correction removed remaining hand overflow. Every original output is retained byte-for-byte here and at the tool's default generated-image location. Exact prompts are in each creature folder; available tool output metadata, reference paths and original save locations are in `generation-metadata.json`. No CLI/API fallback, external art model, imported mesh or stock Doom asset was used. These are generated raster animation studies, not hand-authored pixel production sprites.

## Quality and implementation limits

The appearance is substantially closer to the approved board than the procedural mesh study, but this remains a representative pass awaiting in-game review. Walk phases are sparse and should not be presented as a smooth completed walk cycle. Materials, claw counts and tiny scar details drift between poses. The Vessel recovery pose foreshortens/occludes a throat tube and has somewhat smaller body scale after its targeted correction. The Unsealed recovery pose reads more as a settled crouched strike than a full extended attack. Nearest filtering creates a classic digitized appearance at gameplay scale; native atlas art is detailed painterly shading rather than manually cleaned palette-limited pixel art. Side/rear directions, complete attack transitions, authored hit masks and animation polish remain outstanding.

## Suggested Vessel armor treatment

Keep the exposed sac, gray-green skin, hands, throat cannons and dark rubber gaps as flesh/contact tissue unless gameplay explicitly establishes otherwise. Bare cream ceramic/metal cage plates, their narrow connecting ribs and visible fasteners are containment armor. Do not classify the whole belly rectangle, entire silhouette or convex cage hull as armor: that fills the exposed organ and gaps with a false plate.

`vessel/armor-suggestions.json` provides non-authoritative idle-frame pixel-space hardware strip suggestions for manual mask review. They are narrow hardware candidates rather than a broad armor silhouette. They must be checked against the final sprite and transformed separately per pose before gameplay use. No damage multiplier or impact cue is implemented in these assets. The controller owns hits, movement, audio and state timing.

## Reproduction

`inspect_alpha.py` reads original pixels without writing bitmap data. Pillow is required only for inspection. `review-source/review.gd` is the standalone Godot region preview; do not copy its `.godot` cache into the game. Run from this folder:

```sh
PYTHONPATH=/home/rikki/Projects/eyesore-build-two-staging/visual/_vendor python3 inspect_alpha.py
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path review-source --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy
```

No integrated runtime project or Git files were edited. This pass preserves the approved visual identity without selecting the first level's setting.
