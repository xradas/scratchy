#include "audio_mixer.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>

bool AudioClip::load(const char *path) {
  samples.clear(); SDL_AudioSpec spec{}; Uint8 *data=nullptr; Uint32 length=0;
  if(!SDL_LoadWAV(path,&spec,&data,&length)) {
    char *base=SDL_GetBasePath();
    if(base){char fallback[1024]; std::snprintf(fallback,sizeof(fallback),"%s../%s",base,path); SDL_LoadWAV(fallback,&spec,&data,&length); SDL_free(base);}
  }
  if(!data){std::fprintf(stderr,"Audio %s: %s\n",path,SDL_GetError());return false;}
  SDL_AudioCVT cvt{};
  int result=SDL_BuildAudioCVT(&cvt,spec.format,spec.channels,spec.freq,AUDIO_S16SYS,1,44100);
  const int frame_bytes=(SDL_AUDIO_BITSIZE(spec.format)/8)*spec.channels;
  if(result<0||!length||frame_bytes<=0||length%frame_bytes||length>static_cast<Uint32>(std::numeric_limits<int>::max()/std::max(1,cvt.len_mult))) {
    std::fprintf(stderr,"Audio %s: invalid or unsupported WAV\n",path); SDL_FreeWAV(data); return false;
  }
  if(result==0){samples.resize(length/sizeof(Sint16));std::memcpy(samples.data(),data,length);}
  else {
    std::vector<Uint8> converted(static_cast<size_t>(length)*cvt.len_mult);
    std::memcpy(converted.data(),data,length); cvt.buf=converted.data(); cvt.len=static_cast<int>(length);
    if(SDL_ConvertAudio(&cvt)<0){std::fprintf(stderr,"Audio conversion %s: %s\n",path,SDL_GetError());SDL_FreeWAV(data);return false;}
    if(cvt.len_cvt<=0||cvt.len_cvt%sizeof(Sint16)){SDL_FreeWAV(data);return false;}
    samples.resize(cvt.len_cvt/sizeof(Sint16)); std::memcpy(samples.data(),cvt.buf,cvt.len_cvt);
  }
  SDL_FreeWAV(data); return !samples.empty();
}
bool AudioMixer::open() {
  close(); SDL_AudioSpec desired{}; desired.freq=44100;desired.format=AUDIO_S16SYS;
  desired.channels=2;desired.samples=512;desired.callback=callback;desired.userdata=this;
  device_=SDL_OpenAudioDevice(nullptr,0,&desired,nullptr,0);
  if(!device_){std::fprintf(stderr,"Audio mixer: %s\n",SDL_GetError());return false;}
  SDL_PauseAudioDevice(device_,0); return true;
}
void AudioMixer::close(){if(device_){SDL_CloseAudioDevice(device_);device_=0;}voices_={};background_=nullptr;}
void AudioMixer::update_pan(Voice &v) {
  float pan=0,attenuation=1;
  if(v.positioned){float dx=v.x-listener_x_,dz=v.z-listener_z_,dist=std::hypot(dx,dz);
    pan=dist>0.01f?(dx*std::cos(listener_yaw_)-dz*std::sin(listener_yaw_))/dist:0;
    attenuation=1/(1+.075f*dist);}
  float angle=(std::clamp(pan,-1.0f,1.0f)+1)*.785398163f;
  v.target_left=v.gain*attenuation*std::cos(angle);v.target_right=v.gain*attenuation*std::sin(angle);
}
void AudioMixer::play(const AudioClip &clip,AudioClass category,int priority,float gain,bool positioned,float x,float z) {
  if(!device_||clip.samples.empty()||category<0||category>=AudioClassCount)return;
  SDL_LockAudioDevice(device_);Voice *free=nullptr,*victim=nullptr;int count=0;
  for(auto &v:voices_){if(v.clip&&v.category==category)++count;if(!v.clip&&!v.tail&&!free)free=&v;}
  constexpr int limits[]={6,14,4};bool capped=count>=limits[category];
  for(auto &v:voices_)if(v.clip&&(!capped||v.category==category)&&(!victim||v.priority<victim->priority||(v.priority==victim->priority&&v.age<victim->age)))victim=&v;
  Voice *slot=capped?victim:free?free:victim;
  if(!slot||(slot->clip&&priority<slot->priority)){++stats_.dropped_voices;SDL_UnlockAudioDevice(device_);return;}
  Voice next{};
  if(slot->clip){next.tail=slot->clip;next.tail_cursor=slot->cursor;next.tail_left=slot->left;next.tail_right=slot->right;next.tail_remaining=220;++stats_.stolen_voices;}
  next.clip=&clip;next.gain=std::clamp(gain,0.0f,1.0f);next.positioned=positioned;next.x=x;next.z=z;
  next.priority=priority;next.category=category;next.age=++next_age_; update_pan(next);*slot=next;
  SDL_UnlockAudioDevice(device_);
}
void AudioMixer::set_listener(float x,float z,float yaw){if(!device_)return;SDL_LockAudioDevice(device_);listener_x_=x;listener_z_=z;listener_yaw_=yaw;for(auto &v:voices_)if(v.clip)update_pan(v);SDL_UnlockAudioDevice(device_);}
void AudioMixer::set_background(const AudioClip *clip){if(!device_)return;SDL_LockAudioDevice(device_);background_=clip&&!clip->samples.empty()?clip:nullptr;background_cursor_=0;SDL_UnlockAudioDevice(device_);}
void AudioMixer::set_gains(float effects,float background){if(!device_)return;SDL_LockAudioDevice(device_);effects_=std::clamp(effects,0.0f,1.0f);background_gain_=std::clamp(background,0.0f,1.0f);SDL_UnlockAudioDevice(device_);}
void AudioMixer::set_muted(bool muted){if(!device_)return;SDL_LockAudioDevice(device_);muted_=muted;SDL_UnlockAudioDevice(device_);}
void AudioMixer::reset(){if(!device_)return;SDL_LockAudioDevice(device_);voices_={};background_cursor_=0;next_age_=0;ceiling_gain_=1;master_current_=0;SDL_UnlockAudioDevice(device_);}
AudioStats AudioMixer::stats(){if(!device_)return stats_;SDL_LockAudioDevice(device_);AudioStats result=stats_;SDL_UnlockAudioDevice(device_);return result;}
void AudioMixer::callback(void *ctx,Uint8 *stream,int length){std::memset(stream,0,length);static_cast<AudioMixer*>(ctx)->mix(reinterpret_cast<Sint16*>(stream),length/(2*sizeof(Sint16)));}
void AudioMixer::mix(Sint16 *out,int frames){
  stats_.output_frames+=frames;
  for(int i=0;i<frames;++i){float left=0,right=0;
    for(auto &v:voices_){
      if(v.clip){float sample=v.clip->samples[v.cursor]/32768.0f;
        // A 1 ms de-click ramp protects zero-crossing edges without softening the report.
        v.left+=(v.target_left-v.left)/44;v.right+=(v.target_right-v.right)/44;
        float release=std::min(1.0f,float(v.clip->samples.size()-v.cursor)/132);
        left+=sample*v.left*release*effects_;right+=sample*v.right*release*effects_;
        if(++v.cursor>=v.clip->samples.size())v.clip=nullptr;}
      if(v.tail){float sample=v.tail->samples[v.tail_cursor++]/32768.0f*float(v.tail_remaining)/220;
        left+=sample*v.tail_left*effects_;right+=sample*v.tail_right*effects_;
        if(--v.tail_remaining<=0||v.tail_cursor>=v.tail->samples.size())v.tail=nullptr;}
    }
    if(background_){float sample=background_->samples[background_cursor_++]/32768.0f*background_gain_*.70710678f;
      left+=sample;right+=sample;if(background_cursor_>=background_->samples.size())background_cursor_=0;}
    master_current_+=((muted_?0:master_)-master_current_)/220;left*=master_current_;right*=master_current_;
    float peak=std::max(std::fabs(left),std::fabs(right));stats_.pre_ceiling_peak=std::max(stats_.pre_ceiling_peak,peak);
    float target=peak>.98f?.98f/peak:1;if(target<ceiling_gain_)ceiling_gain_=target;else ceiling_gain_+=(target-ceiling_gain_)/4410;
    if(ceiling_gain_<.999f)++stats_.limited_frames;
    out[i*2]=static_cast<Sint16>(std::lrint(std::clamp(left*ceiling_gain_,-.98f,.98f)*32767));
    out[i*2+1]=static_cast<Sint16>(std::lrint(std::clamp(right*ceiling_gain_,-.98f,.98f)*32767));
  }
}
