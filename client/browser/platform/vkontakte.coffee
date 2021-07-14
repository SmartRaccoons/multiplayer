window.o.PlatformVkontakte = class Vkontakte extends window.o.PlatformCommon
  _name: 'vkontakte'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router.message(_l('Authorize.integrated login error'))
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      @auth_send
        vkontakte: window.location.href.split('?')[1]
        language: if @router._get('language') is '3' then 'en' else 'ru'
    @
