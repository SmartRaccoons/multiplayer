io = @io ? require 'socket.io-client'

(exports ? this.o).Connector = (params)->
  router = params.router
  connector = io(params.address, {
    transports: params.transports
    query: {_version: params.version, _mobile: if params.mobile then '1' else '0'}
  })
  router.send = -> connector.emit 'request', Array.prototype.slice.call(arguments)
  ['connect', 'request'].forEach (ev)->
    connector.on ev, (data)->
      router[ev].apply router, data
  connector.on 'version', -> params.version_callback()
  delay = 0
  connector.on 'error:duplicate', ->
    delay = 15
    router.login_duplicate()

  wrap = (fn) -> if delay is 0 then fn() else setTimeout(fn, delay * 1000)
  dis = -> wrap -> router.disconnect()
  failed = -> wrap -> router.connect_failed()
  connector.on 'connect_error', failed
  connector.on 'connect_timeout', failed
  connector.on 'error', failed
  connector.on 'disconnect', dis
  ['reconnect_attempt', 'reconnecting'].forEach (ev)->
    connector.on ev, -> console.info ev
  router.connecting()
  connector
