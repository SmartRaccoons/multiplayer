window.o.PlatformCommon = class Common

  constructor: (@options)->
    @router = new window.o.Router Object.assign( {platform: @options.platform}, @options.router )
    @router.$el.appendTo('body')
    @_queue_success_login = []
    fn = (event, data)=>
      if event is 'authenticate:error'
        @_success_login_user = null
      if event is 'authenticate:success'
        @success_login(data)
    @router.bind 'request', fn
    ['connect', 'disconnect'].forEach (ev)=>
      @router.bind ev, =>
        @_success_login_user = null

  _queue_success: (fn)->
    if @_success_login_user
      return fn.bind(@)()
    @_queue_success_login.push fn

  success_login: (user)->
    @_success_login_user = user
    while fn = @_queue_success_login.shift()
      fn.bind(@)()

  language_check: (callback)->
    if !window._locales_default
      return callback()
    @router.subview_append(new window.o.ViewPopupLanguage())
    .bind 'language', (language)=> @_language_update(language)
    .bind 'remove', => callback()
    .render()
    .$el.appendTo(@router.$el)

  _auto_login: ->
    if !@auth()
      if @options.anonymous
        return @router.trigger 'anonymous'
      if !@options.language_check
        return @auth_popup()
      @language_check => @auth_popup()

  connect: (params)->
    window.o.Connector Object.assign({
      router: @router
      address: App.config.server
      version: App.version
      version_callback: =>
        @router.message
          body: _l('Authorize.version error')
          actions: [ {'reload': _l('Authorize.button.reload')} ]
    }, params)

  _language_update: (language)->
    App.lang = language
    @_language_set = true

  buy: (params, name = null)->
    @router.send "buy:#{name or @_name}", Object.assign {language: App.lang}, params

  auth_send: (p)->
    @router.message(_l('Authorize.Authorizing'))
    @router.send 'authenticate:try', Object.assign(
      {platform: @options.platform}
      if @_language_set then {language: App.lang}
      p
    )
