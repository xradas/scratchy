# Continuous source campaign route

Godot 4.7.2 source run:

```sh
tools/godot.sh --headless --fixed-fps 60 -- --campaign-route-test --campaign-all-levels --release-report-dir=/tmp/eyesore-campaign-route-dev
```

Result: `CAMPAIGN_ALL_ROUTE_OK`, exit code 0, nine real exit interactions, zero failures, finale `CAMPAIGN COMPLETE`. The [receipt](source-all-9.json) records every level's scene and authored route, physical movement and combat, required controls, starting and ending health/ammo/weapon ownership, and the Main completion screen. Each exit state equals the next level's entry state. Ownership grows from the normal three guns to all six through the three Pale Ward pickups. The bot never reseeds after the first level, teleports, uses secret supplies, or injects completion signals.

`--fixed-fps 60` accelerates simulation for acceptance. The recorded simulation seconds are not human play times. The separate isolated `--campaign-level=<id> --campaign-route-test` mode uses explicit bounded [route seeds](../../../resources/campaign/route-seeds.json) for diagnosing individual levels; it is not the continuous campaign proof.
