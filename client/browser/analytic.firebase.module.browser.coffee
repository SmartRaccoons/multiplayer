import { initializeApp } from 'firebase/app'
import { getAnalytics, setCurrentScreen, setUserProperties, setUserId, logEvent } from "firebase/analytics"


window.o.Analytic = class AnalyticFirebase
  init: ({firebase_config})->
    initializeApp(firebase_config)
    @analytics = getAnalytics()

  config: (params = {})->
    setUserId(@analytics, "#{params.user_id}")
    @user_property {
      'Language': App.lang
    }

  user_property: (params = {})->
    setUserProperties(@analytics, params)

  screen: (view)->
    setCurrentScreen(@analytics, view)

  exception: ({msg, url, line, column, user_agent})->
    @event 'JS Error', {msg, url, line, column, user_agent}
    # firebase.analytics().logEvent('exception', params);

  buy_start: (params)->

  buy_complete: (params)->

  event: (event, params)->
    logEvent(@analytics, event, params)
