// Generated by CoffeeScript 2.7.0
var AnalyticFirebase;

import {
  initializeApp
} from 'firebase/app';

import {
  getAnalytics,
  setCurrentScreen,
  setUserProperties,
  setUserId,
  logEvent
} from "firebase/analytics";

window.o.Analytic = AnalyticFirebase = class AnalyticFirebase {
  init({firebase_config}) {
    initializeApp(firebase_config);
    return this.analytics = getAnalytics();
  }

  config(params = {}) {
    setUserId(this.analytics, `${params.user_id}`);
    return this.user_property({
      'Language': App.lang
    });
  }

  user_property(params = {}) {
    return setUserProperties(this.analytics, params);
  }

  screen(view) {
    return setCurrentScreen(this.analytics, view);
  }

  exception({msg, url, line, column, user_agent}) {
    return this.event('JS Error', {msg, url, line, column, user_agent});
  }

  // firebase.analytics().logEvent('exception', params);
  buy_start(params) {}

  buy_complete(params) {}

  event(event, params) {
    return logEvent(this.analytics, event, params);
  }

};
