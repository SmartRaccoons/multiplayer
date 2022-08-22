// Generated by CoffeeScript 2.7.0
(function() {
  var AnalyticCordova, wrap;

  wrap = function(f) {
    return (() => {
      var error;
      try {
        return f.apply(this, arguments);
      } catch (error1) {
        error = error1;
      }
    })();
  };

  window.o.Analytic = AnalyticCordova = class AnalyticCordova {
    init() {
      return window.ga.startTrackerWithId(App.config.google_analytics);
    }

    config(params = {}) {
      window.ga.setUserId(params.user_id);
      return window.ga.setAppVersion(App.version);
    }

    screen(screen_name) {
      return window.ga.trackView(`${screen_name} ${App.lang}`);
    }

    exception(description) {
      return window.ga.trackException(description, false);
    }

    buy_start(params) {}

    buy_complete(params) {}

  };

}).call(this);
