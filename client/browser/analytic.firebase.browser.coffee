window.o.Analytic = class AnalyticFirebase
  init: ({firebase_config})->
    firebase.initializeApp(firebase_config)
    firebase.analytics()

  config: (params = {})->
    firebase.analytics().setUserId("#{params.user_id}")
    @user_property {
      'Language': App.lang
    }

  user_property: (params = {})->
    firebase.analytics().setUserProperties(params)

  screen: (view)->
    firebase.analytics().setCurrentScreen(view)

  exception: ({msg, url, line, column, user_agent})->
    @event 'JS Error', {msg, url, line, column, user_agent}
    # firebase.analytics().logEvent('exception', params);

  buy_start: (params)->

  buy_complete: (params)->

  event: (event, params)->
    firebase.analytics().logEvent(event, params)
