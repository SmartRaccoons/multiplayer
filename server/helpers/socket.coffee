SimpleEvent = require('simple.event').SimpleEvent


_version_server = [0, 0, 0]

class Socket extends SimpleEvent
  removeListener: -> @unbind.apply(@, arguments)

  constructor: (query)->
    super()
    @_query = query

  trigger: (event)->
    if @_events and @_events["before:#{event}"]
      if !@_events["before:#{event}"][0]()
        return
    super ...arguments

  version_check: ->
    mobile = @_query._mobile is '1'
    version_client = (@_query._version || '0.0.0').split('.')
    for i in [0..1]
      if parseInt(version_client[i]) isnt _version_server[i]
        if i is 1 and mobile
          return true
        return false
    return true

  send: -> throw ''

  disconnect: -> throw ''


module.exports = ({ version })->
  _version_server = version.split('.').map (v)-> parseInt(v)
  return Socket
