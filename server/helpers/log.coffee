
module.exports.Log = ->
  ->
    _messages = []
    (msg)->
      _messages = [msg]
