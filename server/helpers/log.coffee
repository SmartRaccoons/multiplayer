chalk = require('chalk')


_messages = []
_messages_limit = 10
_colorize = ['magenta', 'red', 'green', 'blue']
module.exports.Log =
  config: ({limit})-> _messages_limit = limit
  fn: (msg)->
    _messages.push "#{new Date().getTime()}: #{msg}"
    if _messages.length > _messages_limit
      _messages.shift()
  get: ->
    _messages

  colorize: (msgs)->
    msgs.map (msg, i)->
      chalk[_colorize[i]](msg)
