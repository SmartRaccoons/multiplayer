PopupCode = window.o.PlatformOffline::PopupCode


window.o.PlatformCordova = class Cordova extends window.o.PlatformOffline
  PopupCode: class PopupCodeCordova extends PopupCode
    events: Object.assign {}, PopupCode::events, {
      'click [data-authorize]': (e)->
        url = $(e.target).attr('href')
        if window.SafariViewController
          window.SafariViewController.isAvailable (available)=>
            if !available
              return
            e.preventDefault()
            window.SafariViewController.show({url})
          return false
        else if window.cordova and window.cordova.InAppBrowser
          e.preventDefault()
          window.cordova.InAppBrowser.open url, '_system'
          return false
    }

  _name: 'cordova'

  _version_error: ->
    @router
    .message
      body: _l('Authorize.version error cordova')
      actions: [
        {event: 'open', stay: true, body: _l('Authorize.button.open')}
      ]
    .bind 'open', =>
      if window.cordova and window.cordova.InAppBrowser
        window.cordova.InAppBrowser.open App.config[@options.platform].market, '_system'
        return
      window.open App.config[@options.platform].market, '_system'

  success_login: ->
    super ...arguments
    if window.SafariViewController
      window.SafariViewController.hide()
