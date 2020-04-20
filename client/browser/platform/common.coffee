window.o.PlatformCommon = class Common

  constructor: (@options)->
    @router = new window.o.Router(@options.router)
    @router.$el.appendTo('body')

  language_check: (callback)->
    if !window._locales_default
      return callback()
    @router.subview_append(new window.o.ViewPopupLanguage())
    .bind 'language', (language)=>
      App.lang = language
    .bind 'remove', => callback()
    .render()
    .$el.appendTo(@router.$el)

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

  buy: (params)-> @router.send "buy:#{@_name}", Object.assign {language: App.lang}, params

  auth_send: (p)->
    @router.message(_l('Authorize.Authorizing'))
    @router.send 'authenticate:try', p
