PopupCode = window.o.PlatformOffline::PopupCode


window.o.PlatformCordova = class Cordova extends window.o.PlatformOffline
  PopupCode: class PopupCodeCordova extends PopupCode
    events: Object.assign {}, PopupCode::events, {
      'click [data-authorize]': (e)->
        if window.SafariViewController
          window.SafariViewController.isAvailable (available)=>
            if !available
              return
            e.preventDefault()
            url = $(e.target).attr('href')
            window.SafariViewController.show({url})
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
      window.open App.config[@options.platform].market, '_system'

  success_login: ->
    super ...arguments
    if window.SafariViewController
      window.SafariViewController.hide()
