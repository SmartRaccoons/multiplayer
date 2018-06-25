uuid = require('node-uuid')
SimpleEvent = require('simple.event').SimpleEvent


buffer_init = (log, user_timeout)->
  buffer = {}
  buffer_id = 1
  buffer_remover = {}
  buffer_send = (user_id, socket)->
    if not buffer[user_id] or buffer[user_id].length is 0 or buffer[user_id][0].sending
      return
    buffer[user_id][0].sending = true
    log('write: ' + buffer[user_id][0].id + ' : ' + user_id)
    socket._send buffer[user_id][0].data

  buffer_receive = (user_id, socket)->
    if not buffer[user_id]
      return
    b = buffer[user_id].shift()
    log('delivered: ' + (if b then b.id) + ' : ' + user_id)
    buffer_send(user_id, socket)

  buffer_queue = (user_id, socket, args)->
    id = buffer_id++
    if not buffer[user_id]
      buffer[user_id] = []
    buffer[user_id].push
      id: id
      data: args
    log('buffer: ' + id + ': ' + JSON.stringify(args) + ' : ' + user_id)
    buffer_send(user_id, socket)
    clearTimeout(buffer_remover[user_id])
    buffer_remover[user_id] = setTimeout =>
      buffer_remove(user_id)
    , user_timeout + 1000 * 30

  buffer_remove = (user_id)->
    log('buffer remove: ' + user_id)
    clearTimeout(buffer_remover[user_id])
    delete buffer_remover[user_id]
    delete buffer[user_id]

  buffer_check = (user_id, socket)->
    if buffer[user_id]
      buffer_clone = buffer[user_id].splice(0)
      while b = buffer_clone.shift()
        buffer_queue(user_id, socket, b.data)

  {
    check: buffer_check
    remove: buffer_remove
    queue: buffer_queue
    receive: buffer_receive
    exists: (user_id)-> !!buffer[user_id]
  }


buffer = null
_id = 0
_version_server = [0, 0, 0]

class Socket extends SimpleEvent
  on: -> @bind.apply(@, arguments)
  emit: -> @trigger.apply(@, arguments)
  removeListener: -> @unbind.apply(@, arguments)

  constructor: (query, id)->
    _id++
    @_query = query
    if query._session and (40 <= query._session.length < 55) and buffer.exists(query._session)
      @id = query._session
    else
      @id = id.substr(0, 4) + uuid.v1() + '' + _id

  trigger: (event)->
    if @_events and @_events["before:#{event}"]
      if !@_events["before:#{event}"][0]()
        return
    super

  version_check: ->
    mobile = @_query._mobile is '1'
    version_client = (@_query._version || '0.0.0').split('.')
    for i in [0..2]
      if parseInt(version_client[i]) < _version_server[i]
        if i is 2 and mobile
          return true
        return false
    return true

  check: -> buffer.check(@id, @)

  received: -> buffer.receive(@id, @)

  remove: ->
    super
    if @remove_callback
      @remove_callback(@immediate())
    if @immediate()
      @_removed = true
      buffer.remove(@id)

  send: ->
    if @_removed
      return
    buffer.queue(@id, @, Array.prototype.slice.call(arguments))

  _send: -> throw ''

  immediate: -> if @_immediate? then @_immediate else !@_game

  disconnect: -> throw ''


module.exports = (log, user_timeout, version)->
  buffer = buffer_init(log, user_timeout)
  _version_server = version.split('.').map (v)-> parseInt(v)
  return Socket
