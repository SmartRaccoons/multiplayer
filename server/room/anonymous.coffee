events = require('events')
_authorize = require('./authorize')


platforms = platforms_default = ['draugiem', 'facebook', 'google', 'inbox']
module.exports.config = (c)->
  _authorize.config(c)
  platforms = platforms_default.filter (platform)-> !!c[platform]


module.exports.Anonymous = class Anonymous extends events.EventEmitter
  constructor: (@_socket)->
    @authenticate = @authenticate.bind(@)
    @_socket.on 'authenticate:try', @authenticate

  authenticate: (params)->
    error = => @_socket.send 'authenticate:error'
    if !params
      return error()
    for platform in platforms
      if params[platform]
        api = new _authorize[platform]()
        return api.authorize {code: params[platform], language: params.language}, (user)=>
          if !user
            return error()
          @emit 'login', user, api
    return error()

  remove: ->
    @_socket.removeListener 'authenticate:try', @authenticate
