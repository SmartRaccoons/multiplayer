firebase = require('firebase/app')
require('firebase/analytics')

# wrap = (f)->
#   (=>
#     try
#       f.apply(@, arguments)
#     catch error
#   )()


window.o.Analytic = class AnalyticFirebase
  init: ({firebase_config})->
    firebase.initializeApp(firebase_config)
    firebase.analytics()

  config: (params = {})->
    firebase.analytics().setUserId("#{params.user_id}")
    firebase.analytics().setUserProperties({
      'Language': App.lang
    })

  screen: (view)->
    firebase.analytics().setCurrentScreen(view)

  exception: (description)->
    # firebase.analytics().logEvent('exception', params);

  buy_start: (params)->

  buy_complete: (params)->
