window.o.PlatformOdnoklassniki = class Odnoklassniki extends window.o.PlatformCommon
  _name: 'odnoklassniki'

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
        odnoklassniki: window.location.href.split('?')[1]
        language: 'ru'
    @
