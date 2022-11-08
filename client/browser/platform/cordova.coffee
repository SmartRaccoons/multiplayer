PopupCode = window.o.PlatformOffline::PopupCode


window.o.PlatformCordova = class Cordova extends window.o.PlatformOffline
  PopupCode: class PopupCodeCordova extends PopupCode
    events: Object.assign {}, PopupCode::events, {
      'click [data-authorize]': (e)->
        @parent._popup_open @parent.__local_link( $(e.target).attr('href') ), (success)->
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

  _popup_open: (url, callback = ->)->
    open_safari = (url, callback_safari)=>
      if !(window.SafariViewController and @options.platform is 'ios')
        return callback_safari(false)
      window.SafariViewController.isAvailable (available)=>
        if !available
          return callback_safari(false)
        window.SafariViewController.show {url}
        callback_safari(true)
    open_default = (url, callback_default)=>
      if !(window.cordova and window.cordova.InAppBrowser)
        return callback_default(false)
      window.cordova.InAppBrowser.open url, '_system'
      callback_default(true)
    open_safari url, (success)=>
      if !success
        return open_default url, callback
      return callback(success)

  _popup_close: ->
    if window.SafariViewController
      window.SafariViewController.hide()

  __local_link: (link)->
    link + (if @options.app_protocol then "?re=#{@options.app_protocol}" else '' )

  auth_popup_device: ->
    link = super ...arguments
    @_popup_open @__local_link(link)
    link

  success_login: ->
    super ...arguments
    @_popup_close()
