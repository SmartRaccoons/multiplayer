// Generated by CoffeeScript 2.3.2
(function() {
  var Facebook;

  window.o.PlatformFacebook = Facebook = (function() {
    class Facebook {
      constructor(options) {
        var fn;
        this.buy = this.buy.bind(this);
        this.options = options;
        this.router = new window.o.Router();
        this.router.$el.appendTo('body');
        fn = (event, data) => {
          if (event === 'authenticate:error') {
            this.auth_error();
          }
          if (event === 'authenticate:success') {
            return this.router.unbind('request', fn);
          }
        };
        this.router.bind('request', fn);
        this.router.bind('connect', () => {
          return window.FB.getLoginStatus(((response) => {
            return this._auth_callback(response, this.auth);
          }), {
            scope: this._scope
          });
        });
        this;
      }

      init(callback) {
        $('<script>').attr({
          'src': '//connect.facebook.net/en_US/sdk.js',
          'id': 'facebook-jssdk'
        }).appendTo(document.body);
        return window.fbAsyncInit = function() {
          window.FB.init({
            appId: App.config.facebook_id,
            xfbml: true,
            version: 'v2.5'
          });
          return callback();
        };
      }

      buy({service, id}) {
        return window.FB.ui({
          method: 'pay',
          action: 'purchaseitem',
          product: `https://${App.config.server}/d/og/${service}${App.lang}.html`,
          request_id: id
        }, function() {});
      }

      share(params = {}, callback = function() {}) {
        return window.FB.ui({
          method: 'share',
          href: params.href
        }, (response) => {
          if (response && response.error_code) {
            return callback(response.error_code);
          }
          return callback();
        });
      }

      _auth_callback(response, callback = this.auth_error) {
        if (response.status === 'connected') {
          return this.auth_send(response.authResponse.accessToken);
        }
        return callback();
      }

      auth() {
        return window.FB.login(((response) => {
          return this._auth_callback(response);
        }), {
          scope: this._scope
        });
      }

      auth_error() {
        return this.router.message(_l('standalone login error')).bind('login', () => {
          return this.auth();
        });
      }

      auth_send(access_token) {
        return this.router.send('authenticate:try', {
          facebook: access_token
        });
      }

      connect() {
        return window.o.Connector({
          router: this.router,
          address: '',
          version: document.body.getAttribute('data-version'),
          version_callback: () => {
            return this.router.message(_l('version error'));
          }
        });
      }

    };

    Facebook.prototype._scope = '';

    return Facebook;

  }).call(this);

}).call(this);
