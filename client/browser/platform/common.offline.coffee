window.o.PlatformOffline = class PlatformOffline extends window.o.PlatformCommon
  PopupCode: class PopupCode extends window.o.ViewPopup
    className: window.o.ViewPopupAuthorize::className

  Authorize: window.o.ViewPopupAuthorize
  _authorize:
    draugiem: 'dr_auth_code'
    facebook: 'access_token'
    google: 'code'
    apple: 'apple'

  constructor: ->
    super ...arguments
    @_queue_success_login = []
    @_login_code_params = {}
    fn = (event, data)=>
      if event is 'authenticate:error'
        @_login_code_params.random = null
        @router
        .message
          body: _l('Authorize.standalone login error')
          actions: [
            {'reload': _l('Authorize.button.reload')}
            {'login': _l('Authorize.button.login')}
          ]
        .bind 'login', =>
          @auth_popup()
      if event is 'authenticate:code_error'
        return @_auto_login()
      if event is 'authenticate:success'
        @success_login(data)
        @router.unbind 'request', fn
      if event is 'authenticate:code'
        @_login_code_params.random = data.random
        @auth_popup_device @_login_code_params
      if event is 'authenticate:params'
        @_auth_clear()
        for platform, value of data
          Cookies.set(platform, value)
    @router.bind 'request', fn
    @router.bind 'connect', =>
      if @_login_code_params.random
        return @router.send 'authenticate:code_check', {random: @_login_code_params.random}
      @_auto_login()
    @router.bind 'logout', =>
      @_auth_clear()
      window.location.reload true

  connect: ->
    super({
      mobile: true
      version_callback: ({actual})=>
        to_int = (v)-> v.split('.').map (v)-> parseInt(v)
        version_diff = ((v1, v2)=>
          for i in [0..1]
            if v1[i] isnt v2[i]
              return v1[i] - v2[i]
          return 0
        )(to_int(App.version), to_int(actual))
        is_prev = => window.location.href.indexOf('prev.html') >= 0
        redirect = (url)=>
          window.location = url
        if version_diff > 0 and !is_prev()
          return redirect('prev.html')
        if version_diff < 0 and is_prev()
          return redirect('index.html')
        @router
        .message
          body: _l('Authorize.version error offline')
          actions: [
            {event: 'open', stay: true, body: _l('Authorize.button.open')}
          ]
          close: !!@options.anonymous
        .bind 'open', =>
          window.open App.config[@options.platform].market, '_system'
        .bind 'close', =>
          @router.trigger 'anonymous'
    })

  _queue_success: (fn)->
    if @_success_login_user
      return fn.bind(@)()
    @_queue_success_login.push fn

  success_login: (user)->
    @_success_login_user = user
    while fn = @_queue_success_login.shift()
      fn.bind(@)()

  auth_popup_device: ({random, platform})->
    link = [App.config.server, App.config.login[platform], '/', random].join('')
    link_text = link.replace('https://', '').replace('http://', '')
    popup_code = new @PopupCode({
      head: _l('Authorize.head') + ' ' + platform
      body: _l('Authorize.Authorize link', {link: "<a data-authorize target='_blank' href='#{link}'>#{link_text}</a>"})
    })
    popup_code.parent = @
    @router.subview_append(popup_code)
    .bind 'remove', => @auth_popup()
    .render().$el.appendTo @router.$el
    @router.trigger 'platform:auth_popup_device', {platform}
    return link

  _auto_login: ->
    super ...arguments
    @_login_code_params.random = null
    @

  auth_popup: ->
    authorize = @router.subview_append new @Authorize({close: !!@options.anonymous, platforms: Object.keys(App.config.login), parent: @router.$el})
    authorize.bind 'authorize', (platform)=>
      if platform is 'email'
        return @auth_email()
      @_login_code_params.platform = platform
      if !@_login_code_params.random
        return @router.send 'authenticate:code', {language: App.lang}
      @auth_popup_device @_login_code_params
    .bind 'close', =>
      @router.trigger 'anonymous'
    .render()
    @router.trigger 'platform:auth_popup'

  _auth_clear: -> Object.keys(App.config.login).forEach (c)-> Cookies.set(c, '')

  auth: ->
    params = {}
    for platform in Object.keys(App.config.login)
      if Cookies.get(platform)
        params[platform] = Cookies.get(platform)
        @auth_send params
        return true
    return false
