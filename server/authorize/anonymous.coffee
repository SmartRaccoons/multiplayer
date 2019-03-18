_authorize = require('./authorize')
module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
PubsubModule = require('../pubsub/multiserver').PubsubModule


platforms = []
dbmemory = null
locale = null
config_callback ->
  platforms = ['draugiem', 'facebook', 'google', 'inbox'].filter (platform)-> !!config_get(platform)
  dbmemory = config_get('dbmemory')
  locale = module_get('locale')


_ids = 0
module.exports.Anonymous = class Anonymous extends PubsubModule
  _module: 'anonymous'
  _socket_bind: [
    ['remove', 'remove']
    ['authenticate:try', 'authenticate']
    ['authenticate:code', 'authenticate_code']
    ['authenticate:code_check', 'authenticate_code_check']
  ]
  constructor: (@_socket)->
    _ids++
    super({id: "#{config_get('server_id')}:#{_ids}"})
    @_codes = []
    @_socket_bind.forEach (p)=>
      @[p[1]] = @[p[1]].bind(@)
      @_socket.on p[0], @[p[1]]

  authenticate_code: (params)->
    language = locale.lang_short(locale.validate(if params then params.language else ''))
    dbmemory.random @_module, {id: @id}, ({random})=>
      @_codes.push random
      @_socket.send 'authenticate:code', {random: [language, random].join('') }

  authenticate_code_check: (params)->
    error = => @_socket.send 'authenticate:code_error'
    if !(params and params.random)
      return error()
    dbmemory.random_get @_module, params.random.substr(1), (v)=>
      if !(v and v.authenticate)
        return error()
      @authenticate(v.authenticate)

  authenticate: (params)->
    error = => @_socket.send 'authenticate:error'
    if !params
      return error()
    for platform in platforms
      if params[platform]
        api = new _authorize[platform]()
        return api.authorize {code: params[platform], language: params.language, params: params.params}, (user)=>
          if !user
            return error()
          @_socket.send 'authenticate:params', { [platform]: params[platform] }
          @trigger 'login', user, api
    return error()

  remove: ->
    @_socket_bind.forEach (p)=> @_socket.removeListener p[0], @[p[1]]
    super()
