// Generated by CoffeeScript 2.4.1
(function() {
  var Router;

  window.o.Router = Router = (function() {
    class Router extends window.o.View {
      _get(param) {
        var i, len, ref, result, v;
        ref = ['search', 'hash'];
        for (i = 0, len = ref.length; i < len; i++) {
          v = ref[i];
          result = window.location[v].match(new RegExp("(\\?|&|#)" + param + "(\\[\\])?=([^&]*)"));
          if (result) {
            return decodeURIComponent(result[3]);
          }
        }
        return false;
      }

      constructor() {
        super(...arguments);
        App.events.trigger('router:init', this);
        this._active = null;
      }

      connect() {
        this._unload();
        this.render();
        return this.trigger('connect');
      }

      connecting() {
        return this.message(_l('Authorize.Connecting'));
      }

      disconnect() {
        return this.message(_l('Authorize.Disconnect'));
      }

      login_duplicate() {
        return this.message(_l('Authorize.Login duplicate'));
      }

      connect_failed() {
        return this.message(_l('Authorize.connect failed'));
      }

      request(event, data) {
        this.trigger('request', event, data);
        return this.trigger(`request:${event}`, data);
      }

      // send: ->
      message_remove() {
        if (this._message) {
          this._message.remove();
          return this._message = null;
        }
      }

      message(params) {
        this.message_remove();
        if (typeof params === 'string') {
          params = {
            body: params
          };
        }
        this._message = new window.o.ViewPopup(_.extend({
          parent: this.$el,
          close: false
        }, params)).render();
        this._message.bind('reload', function() {
          return window.location.reload(true);
        });
        return this._message;
      }

      _active_check(name) {
        return this._active && this._active._name === name;
      }

      _unload() {
        if (this._active) {
          this._active.remove();
          return this._active = null;
        }
      }

      _load(view, options) {
        this._unload();
        this._active = new window.o['View' + view.charAt(0).toUpperCase() + view.slice(1)](options);
        this.$el.prepend(this._active.$el);
        this._active.render();
        this._active._name = view;
        return this._active;
      }

    };

    Router.prototype.className = 'container';

    Router.prototype.template = "  ";

    return Router;

  }).call(this);

}).call(this);
