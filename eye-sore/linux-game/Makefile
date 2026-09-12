CC := gcc
CFLAGS := -std=c11 -O2 -Wall -Wextra $(shell pkg-config --cflags sdl2)
LDLIBS := $(shell pkg-config --libs sdl2) -lm
OUT := build/eye-sore
CPP := g++
CPPFLAGS := -std=c++17 -O2 -Wall -Wextra $(shell pkg-config --cflags sdl2)
GL_LDLIBS := $(shell pkg-config --libs sdl2) -lGL -lm
OUT3D := build/eye-sore-3d
PACKAGE := build/eye-sore-linux-x86_64.tar.gz

$(OUT): src/main.c
	mkdir -p build
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS)

run: $(OUT)
	./$(OUT)

$(OUT3D): src/engine3d.cpp
	mkdir -p build
	$(CPP) $(CPPFLAGS) $< -o $@ $(GL_LDLIBS)

run-3d: $(OUT3D)
	./$(OUT3D)

run-3d-record: $(OUT3D)
	./$(OUT3D) --record

enemy-directional-assets:
	./tools/build_enemy_directional_frames.sh

enemy-combat-assets:
	./tools/build_enemy_combat_frames.sh

weapon-assets:
	./tools/build_weapon_frames.sh

weapon-sounds:
	./tools/build_weapon_sounds.sh

music:
	./tools/build_furnace_music.sh

projectile-assets:
	./tools/build_projectile_sprites.sh

verify-enemy-assets:
	./tools/verify_enemy_directional_frames.sh
	./tools/verify_enemy_combat_frames.sh

verify-weapon-assets:
	./tools/verify_weapon_assets.sh

verify-projectile-assets:
	./tools/verify_projectile_assets.sh

verify-audio-assets:
	./tools/verify_audio_assets.sh

package: $(OUT)
	rm -rf build/package
	mkdir -p build/package/eye-sore/assets
	cp $(OUT) README.md build/package/eye-sore/
	cp assets/*.bmp build/package/eye-sore/assets/
	tar -C build/package -czf $(PACKAGE) eye-sore

clean:
	rm -rf build

.PHONY: run run-3d run-3d-record package clean enemy-directional-assets enemy-combat-assets weapon-assets weapon-sounds music projectile-assets verify-enemy-assets verify-weapon-assets verify-projectile-assets verify-audio-assets
