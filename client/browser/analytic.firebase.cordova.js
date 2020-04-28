// Generated by CoffeeScript 2.5.1
(function() {
  var AnalyticFirebase;

  window.o.Analytic = AnalyticFirebase = class AnalyticFirebase {
    init({firebase_config}) {}

    config(params = {}) {
      window.FirebasePlugin.setUserId(`${params.user_id}`);
      return this.user_property({
        'Language': App.lang
      });
    }

    user_property(params = {}) {
      var key, results, value;
      results = [];
      for (key in params) {
        value = params[key];
        results.push(window.FirebasePlugin.setUserProperty(key, value));
      }
      return results;
    }

    screen(view) {
      return window.FirebasePlugin.setScreenName(view);
    }

    exception(message) {
      return window.FirebasePlugin.logError(message);
    }

    buy_start(params) {}

    // window.FirebasePlugin.logEvent(event, params)
    buy_complete(params) {}

    event(event, params) {
      return window.FirebasePlugin.logEvent(event, params);
    }

  };

}).call(this);