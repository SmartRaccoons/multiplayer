window.o.PlatformDraugiem = class Draugiem extends window.o.PlatformCommon
  _name: 'draugiem'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router.message(_l('Authorize.integrated login error'))
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', => @auth_send({ draugiem: @router._get('dr_auth_code') })
    @router.bind "request:buy:#{@_name}", ({link})=>
      window.draugiemWindowOpen(link, 350, 400)
    @__init()
    @

  __init: ->
    window.draugiem_callback_url = location.protocol + '//'+document.domain+'/draugiem-callback.html'
    window.draugiem_domain = @router._get('domain')
    $('<script>').attr
      'src': '//ifrype.com/applications/external/draugiem.js'
    .appendTo document.body
