# Initial continuous route failure

Source command (Godot 4.7.2, source project, fixed simulation rate):

```sh
tools/godot.sh --headless --fixed-fps 60 -- --campaign-route-test --campaign-all-levels --release-report-dir=/tmp/eyesore-campaign-route-dev
```

Ward Intake completed from the normal loadout (32 kills, 91 shots, health 100). Main's Continue loaded Ward Containment with carried state. The route driver then stalled in arena one while attempting a hardcoded outer closet flank at `(-13.962, -0.149, -73.521)`. It had 7 kills and 27 shots in that level. The receipt is copied here verbatim before adapting the driver to each level's authored `combat_paths`. This failure concerns a physical navigation assumption; the driver did not bypass enemies, damage, ammo, or level controls.

Follow-up survivor logging exposed a separate level issue: four Ward Containment arena-one enemies fell through the floor to approximately `y=-80183`, leaving that arena impossible to clear. The level geometry is being corrected before the continuous route is rerun.
