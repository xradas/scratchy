#pragma once
#include <SDL2/SDL.h>
#include <array>
#include <vector>

// Clips are converted once, before playback. Keep them alive until mixer shutdown.
struct AudioClip { std::vector<Sint16> samples; bool load(const char *path); };
enum AudioClass { AudioWeapon, AudioCombat, AudioInterface, AudioClassCount };
struct AudioStats { float pre_ceiling_peak=0; Uint64 output_frames=0, limited_frames=0, stolen_voices=0, dropped_voices=0; };
class AudioMixer {
public:
  AudioMixer() = default;
  ~AudioMixer() { close(); }
  AudioMixer(const AudioMixer &) = delete;
  AudioMixer &operator=(const AudioMixer &) = delete;
  bool open();
  void close();
  void play(const AudioClip &, AudioClass, int priority, float gain,
            bool positioned=false, float x=0, float z=0);
  void set_listener(float x, float z, float yaw);
  void set_background(const AudioClip *);
  void set_gains(float effects, float background);
  void set_muted(bool);
  void reset(); // Clears effects and restarts the background under device lock.
  AudioStats stats();
private:
  struct Voice {
    const AudioClip *clip=nullptr, *tail=nullptr;
    size_t cursor=0, tail_cursor=0;
    float gain=0, left=0, right=0, target_left=0, target_right=0;
    float tail_left=0, tail_right=0; int tail_remaining=0;
    float x=0,z=0; bool positioned=false;
    int priority=0, category=0; Uint64 age=0;
  };
  static void callback(void *, Uint8 *, int);
  void mix(Sint16 *, int);
  void update_pan(Voice &);
  SDL_AudioDeviceID device_=0;
  std::array<Voice,24> voices_{};
  const AudioClip *background_=nullptr; size_t background_cursor_=0;
  float listener_x_=0,listener_z_=0,listener_yaw_=0;
  float effects_=0.95f,background_gain_=0.14f,master_=0.60f,master_current_=0;
  float ceiling_gain_=1; bool muted_=false;
  Uint64 next_age_=0;
  AudioStats stats_{};
};
