PopupCode = window.o.PlatformOffline::PopupCode


window.o.PlatformCordova = class Cordova extends window.o.PlatformOffline
  PopupCode: class PopupCodeCordova extends PopupCode
    events: Object.assign {}, PopupCode::events, {
      'click [data-authorize]': (e)->
        @_popup_open $(e.target).attr('href'), (success)->
          if success
            e.preventDefault()
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

  _popup_open: (url, callback)->
    open_safari = (url, callback)=>
      if !window.SafariViewController
        return callback(false)
      window.SafariViewController.isAvailable (available)=>
        if !available
          return callback(false)
        window.SafariViewController.show {url}
        callback(true)
    open_default = (url, callback)=>
      if !(window.cordova and window.cordova.InAppBrowser)
        return callback(false)
      @_popup_instance = window.cordova.InAppBrowser.open url, '_system'
      # @_popup_instance.addEventListener 'loadstart', (event)=>
      #   if event.url.substr(-5) is 'close'
      #     @_popup_close()
      callback(true)
    open_safari url, (success)=>
      if !success
        return open_default url, callback
      return callback(success)

  _popup_close: ->
    if window.SafariViewController
      window.SafariViewController.hide()
    if @_popup_instance
      @_popup_instance.close()
      @_popup_instance = null

  auth_popup_device: ->
    link = super ...arguments
    @_popup_open(link)
    link

  success_login: ->
    super ...arguments
    @_popup_close()
