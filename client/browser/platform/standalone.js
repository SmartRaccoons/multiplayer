// Generated by CoffeeScript 2.7.0
(function() {
  var Standalone;

  window.o.PlatformStandalone = Standalone = (function() {
    class Standalone extends window.o.PlatformCommon {
      constructor() {
        var fn;
        super(...arguments);
        fn = (event, data) => {
          var platform, value;
          if (event === 'authenticate:error') {
            this.router.message({
              body: _l('Authorize.standalone login error'),
              actions: [
                {
                  'reload': _l('Authorize.button.reload')
                },
                {
                  'login': _l('Authorize.button.login')
                }
              ],
              close: !!this.options.anonymous
            }).bind('login', () => {
              return this.auth_popup();
            }).bind('close', () => {
              return this.router.trigger('anonymous');
            });
          }
          if (event === 'authenticate:params') {
            this._auth_clear();
            for (platform in data) {
              value = data[platform];
              Cookies.set(platform, value);
            }
          }
          if (event === 'authenticate:success') {
            return this.router.unbind('request', fn);
          }
        };
        this.router.bind('request', fn);
        this.router.bind('connect', () => {
          return this._auto_login();
        });
        this.router.bind('logout', () => {
          this._auth_clear();
          return window.location.reload(true);
        });
      }

      auth_popup() {
        var authorize;
        authorize = this.router.subview_append(new this.Authorize({
          close: !!this.options.anonymous,
          platforms: Object.keys(App.config.login),
          parent: this.router.$el
        }));
        authorize.bind('authorize', (platform) => {
          if (platform === 'email') {
            return this.auth_email();
          }
          window.location.href = App.config.login[platform] + '?language=' + App.lang;
          return this.router.trigger('platform:auth_popup_redirect', {platform});
        }).bind('close', () => {
          return this.router.trigger('anonymous');
        }).render();
        return this.router.trigger('platform:auth_popup');
      }

      _auth_clear() {
        return Object.keys(App.config.login).forEach(function(c) {
          return Cookies.set(c, '');
        });
      }

      auth() {
        var argument, i, j, len, len1, params, platform, ref, ref1;
        params = {};
        ref = Object.keys(App.config.login);
        for (i = 0, len = ref.length; i < len; i++) {
          platform = ref[i];
          argument = this._authorize[platform];
          if (this.router._get(argument)) {
            params[platform] = this.router._get(argument);
            this._auth_clear();
            Cookies.set(platform, params[platform]);
            window.history.replaceState({}, document.title, window.location.pathname);
            this.auth_send(params);
            return true;
          }
        }
        params = {};
        ref1 = Object.keys(App.config.login);
        for (j = 0, len1 = ref1.length; j < len1; j++) {
          platform = ref1[j];
          if (Cookies.get(platform)) {
            params[platform] = Cookies.get(platform);
            this.auth_send(params);
            return true;
          }
        }
        return false;
      }

    };

    Standalone.prototype.Authorize = window.o.ViewPopupAuthorize;

    Standalone.prototype._authorize = {
      draugiem: 'dr_auth_code',
      facebook: 'access_token',
      google: 'code',
      apple: 'apple'
    };

    return Standalone;

  }).call(this);

}).call(this);
