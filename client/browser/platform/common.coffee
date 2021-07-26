window.o.PlatformCommon = class Common

  constructor: (@options)->
    @router = new window.o.Router Object.assign( {platform: @options.platform}, @options.router )
    @router.$el.appendTo('body')

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
