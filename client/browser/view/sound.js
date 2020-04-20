// Generated by CoffeeScript 2.5.1
(function() {
  var Sound, SoundMedia, __enable, __ids, cordova;

  cordova = function() {
    return !!window.cordova;
  };

  __ids = 0;

  SoundMedia = class SoundMedia extends SimpleEvent {
    constructor(options) {
      super();
      this.options = options;
      __ids++;
      this.id = __ids;
      this.cordova = cordova();
      this.media = this.cordova ? new Media(this.options.url) : new Audio(this.options.url);
      this.volume(this.options.volume);
      this.__remove_callback = setTimeout(() => {
        return this.remove();
      }, 1000 * 60);
      this;
    }

    volume(volume) {
      var rounded;
      this.options.volume = volume;
      if (this.options.volume < 0) {
        this.options.volume = 0;
      }
      rounded = Math.round(this.options.volume * 100) / 100;
      if (this.cordova) {
        this.media.setVolume(`${rounded}`);
      } else {
        this.media.volume = rounded;
      }
      return this;
    }

    play() {
      if (this.cordova) {
        this.media.play({
          playAudioWhenScreenIsLocked: false
        });
      } else {
        this.media.play();
      }
      return this;
    }

    stop() {
      this.volume(0);
      if (this.cordova) {
        this.media.stop();
      }
      return this;
    }

    fade_out(mls, mls_left, volume = this.options.volume, start = new Date().getTime()) {
      if (!mls_left) {
        mls_left = mls;
      }
      return window.requestAnimationFrame(() => {
        var diff, end;
        end = new Date().getTime();
        diff = end - start;
        if ((mls_left - diff) <= 0) {
          return this.remove();
        }
        this.volume(volume * mls_left / mls);
        return this.fade_out(mls, mls_left - diff, volume, end);
      });
    }

    remove() {
      clearTimeout(this.__remove_callback);
      this.stop();
      if (this.cordova) {
        this.media.release();
      }
      this.media = null;
      return super.remove();
    }

  };

  __enable = true;

  this.o.Sound = Sound = class Sound {
    constructor(options) {
      var fn;
      this.options = options;
      this.__medias = [];
      this.__muted = typeof Cookies !== "undefined" && Cookies !== null ? !!parseInt(Cookies.get('__sound_muted')) : false;
      fn = () => {
        this.__enable = true;
        document.body.removeEventListener('click', fn);
        return document.body.removeEventListener('touchstart', fn);
      };
      document.body.addEventListener('click', fn);
      document.body.addEventListener('touchstart', fn);
    }

    play(sound) {
      var media;
      if (!__enable) {
        return;
      }
      if (!this.__enable) {
        return;
      }
      if (this.__muted) {
        return;
      }
      try {
        media = new SoundMedia({
          volume: this.options.volume,
          url: `${this.options.path}${sound}.${this.options.extension}`
        }).play();
        this.__medias.push(media);
        media.on('remove', () => {
          return this.__medias.splice(this.get(media.id, true), 1);
        });
        return media;
      } catch (error) {

      }
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
      this.clear();
      return __enable = false;
    }

    fade(media) {
      if (media) {
        return this.get(media.id).fade_out(this.options.fade_out);
      }
    }

    clear() {
      return this.__medias.map(function(m) {
        return m.id;
      }).forEach((id) => {
        return this.get(id).remove();
      });
    }

    is_mute() {
      return this.__muted;
    }

    mute(__muted) {
      this.__muted = __muted;
      this.clear();
      if (typeof Cookies !== "undefined" && Cookies !== null) {
        return Cookies.set('__sound_muted', this.__muted ? 1 : 0);
      }
    }

  };

}).call(this);
