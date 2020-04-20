window.o.Analytic = class AnalyticFirebase
  init: ({firebase_config})->

  config: (params = {})->
    window.FirebasePlugin.setUserId "#{params.user_id}"
    @user_property {'Language': App.lang}

  user_property: (params = {})->
    for key, value of params
      window.FirebasePlugin.setUserProperty key, value

  screen: (view)->
    window.FirebasePlugin.setScreenName view

  exception: (message)->
    window.FirebasePlugin.logError message

  buy_start: (params)->
    # window.FirebasePlugin.logEvent(event, params)

  buy_complete: (params)->

  event: (event, params)->
    window.FirebasePlugin.logEvent(event, params)
