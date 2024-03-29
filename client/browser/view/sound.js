// Generated by CoffeeScript 2.7.0
(function() {
  var Sound, SoundMedia, __enable, __ids, __iteraction, cordova;

  cordova = function() {
    return !!window.cordova;
  };

  __ids = 0;

  SoundMedia = class SoundMedia extends SimpleEvent {
    constructor(options) {
      super();
      this.options = Object.assign({
        volume: 0,
        volume_prev: 0
      }, options);
      __ids++;
      this.id = __ids;
      this.cordova = cordova();
      this.media = (() => {
        if (this.cordova) {
          return new Media(this.options.url);
        }
        return new Howl({
          src: [this.options.url],
          loop: this.options.loop
        });
      })();
      if (!this.cordova) {
        this.media.once('load', () => {
          this._duration_mls = Math.round(this.media.duration() * 1000);
          return this.trigger('loadeddata');
        });
      }
      if (this.options.fade_in) {
        this.fade_in(typeof this.options.fade_in === 'number' ? this.options.fade_in : void 0);
      } else {
        this.volume(this.options.volume);
      }
      if (!this.options.loop) {
        this.__remove_callback = setTimeout(() => {
          return this.remove();
        }, 1000 * 30);
      }
      this;
    }

    duration(callback) {
      if (this._duration_mls) {
        return callback(this._duration_mls);
      }
      return this.bind('loadeddata', () => {
        return this.duration(() => {
          return callback(this._duration_mls || 0);
        });
      });
    }

    volume(volume) {
      var rounded;
      this.options.volume_prev = this.options.volume;
      this.options.volume = volume;
      if (this.options.volume < 0) {
        this.options.volume = 0;
      }
      rounded = Math.round(this.options.volume * 100) / 100;
      if (this.cordova) {
        this.media.setVolume(`${rounded}`);
      } else {
        this.media.volume(rounded);
      }
      return this;
    }

    play() {
      if (this.cordova) {
        this.media.play(Object.assign({
          playAudioWhenScreenIsLocked: false
        }, this.options.loop ? {
          numberOfLoops: 111
        } : void 0));
      } else {
        this.media.play();
      }
      return this;
    }

    stop() {
      this.volume(0);
      if (this.cordova) {
        this.media.stop();
      } else {
        this.media.stop();
      }
      return this;
    }

    fade(volume_end = 0, volume_start = this.options.volume, mls = 1000, remove = true) {
      var fade, start;
      start = new Date().getTime();
      fade = () => {
        return window.requestAnimationFrame(() => {
          var mls_left;
          if (!this.media) {
            return;
          }
          mls_left = mls - (new Date().getTime() - start);
          if (mls_left <= 0) {
            if (remove) {
              this.remove();
            }
            return;
          }
          this.volume(volume_start + (volume_end - volume_start) * (1 - mls_left / mls));
          return fade();
        });
      };
      return fade();
    }

    fade_out(mls) {
      return this.fade(0, this.options.volume, mls);
    }

    fade_in(mls) {
      return this.fade(this.options.volume, 0, mls, false);
    }

    remove() {
      clearTimeout(this.__remove_callback);
      this.stop();
      if (this.cordova) {
        this.media.release();
      } else {
        this.media.unload();
      }
      this.media = null;
      return super.remove();
    }

  };

  __enable = true;

  __iteraction = false;

  this.o.Sound = Sound = class Sound extends SimpleEvent {
    constructor(options1) {
      var enable, fn;
      super(...arguments);
      this.options = options1;
      this.__medias = [];
      this.__muted = typeof Cookies !== "undefined" && Cookies !== null ? !!parseInt(Cookies.get('__sound_muted')) : false;
      enable = () => {
        __iteraction = true;
        return this.trigger('enable');
      };
      if (cordova()) {
        setTimeout(() => {
          enable();
          document.addEventListener("pause", () => {
            return this._mute_medias();
          }, false);
          return document.addEventListener("resume", () => {
            return this._unmute_medias();
          }, false);
        }, 100);
      } else {
        fn = () => {
          __iteraction = true;
          this.trigger('enable');
          document.body.removeEventListener('click', fn);
          return document.body.removeEventListener('touchstart', fn);
        };
        document.body.addEventListener('click', fn);
        document.body.addEventListener('touchstart', fn);
        document.addEventListener('visibilitychange', () => {
          if (document.hidden) {
            return this._mute_medias();
          } else {
            return this._unmute_medias();
          }
        });
      }
      this;
    }

    _media_create(params) {
      var media;
      if (!__enable) {
        return;
      }
      if (!__iteraction) {
        return;
      }
      if (this.__muted) {
        return;
      }
      try {
        params = typeof params === 'object' ? params : {
          sound: params
        };
        this.trigger('play', params.sound);
        media = new SoundMedia(Object.assign({
          volume: this.options.volume,
          url: `${this.options.path}${params.sound}.${this.options.extension}`
        }, params));
        this.__medias.push(media);
        media.on('remove', () => {
          return this.__medias.splice(this.get(media.id, true), 1);
        });
        return media;
      } catch (error) {
        return null;
      }
    }

    play(sound) {
      var media;
      media = this._media_create(sound);
      if (!media) {
        return;
      }
      media.play();
      return media;
    }

    get(id, index = false) {
      return this.__medias[index ? 'findIndex' : 'find'](function(m) {
        return m.id === id;
      });
    }

    is_enable() {
      return __enable;
    }

    disable() {
      this._clear();
      return __enable = false;
    }

    enable() {
      return __enable = true;
    }

    _clear() {
      return this.__medias.map(function(m) {
        return m.id;
      }).forEach((id) => {
        return this.get(id).remove();
      });
    }

    _mute_medias() {
      return this.__medias.map(function(m) {
        return m.id;
      }).forEach((id) => {
        return this.get(id).volume(0);
      });
    }

    _unmute_medias() {
      return this.__medias.map(function(m) {
        return m.id;
      }).forEach((id) => {
        return this.get(id).volume(this.get(id).options.volume_prev);
      });
    }

    is_mute() {
      return this.__muted;
    }

    mute(__muted) {
      this.__muted = __muted;
      this._clear();
      if (typeof Cookies !== "undefined" && Cookies !== null) {
        Cookies.set('__sound_muted', this.__muted ? 1 : 0);
      }
      return this.trigger('mute', this.__muted);
    }

  };

}).call(this);
