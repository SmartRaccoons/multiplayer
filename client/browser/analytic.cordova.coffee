window.o.AnalyticCordova = class AnalyticCordova
  init: ->
    window.ga.startTrackerWithId(App.config.google_analytics)

  config: (params = {})->
    window.ga.setUserId(params.user_id)
    window.ga.setAppVersion(App.version)

  screen: (screen_name)->
    window.ga.trackView("#{screen_name} #{App.lang}")

  exception: (description)->
    window.ga.trackException(description, false)

  buy_start: (params)->

  buy_complete: (params)->
