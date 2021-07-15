module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
PubsubModule = require('../pubsub/multiserver').PubsubModule


platforms = []
dbmemory = null
locale = null
email = null
_authorize = null
config_callback ->
  platforms = ['draugiem', 'facebook', 'google', 'apple', 'inbox', 'vkontakte', 'odnoklassniki', 'email'].filter (platform)-> !!config_get(platform)
  dbmemory = config_get('dbmemory')
  locale = module_get('locale')
  email = module_get('server.helpers.email')
  _authorize = module_get('server.authorize')


_ids = 0
module.exports.Anonymous = class Anonymous extends PubsubModule
  _socket_bind: [
    ['remove', 'remove']
    ['authenticate:try', 'authenticate']
    ['authenticate:code', 'authenticate_code']
    ['authenticate:code_check', 'authenticate_code_check']
    ['authenticate:email_forget', 'authenticate_email_forget']
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
    dbmemory.random @_module(), {id: @id}, ({random})=>
      @_codes.push random
      @_socket.send 'authenticate:code', {random: [language, random].join('') }

  authenticate_code_check: (params)->
    error = => @_socket.send 'authenticate:code_error'
    if !(params and params.random)
      return error()
    dbmemory.random_get @_module(), params.random.substr(1), (v)=>
      if !(v and v.authenticate)
        return error()
      @authenticate(v.authenticate)

  authenticate_email_forget: (params)->
    response = (params = {})=>
      @_socket.send 'authenticate:email_forget', params
    config_email = config_get('email')
    if !(config_email and params and params.email)
      return
    language = locale.validate(params.language)
    _l = (str, params = {})=> locale._ str, language, params
    _authorize.email::_check_email params, (user)=>
      if !user
        return response
          body: locale._ 'UserNotify.Forget email error', language, { email: params.email }
      dbmemory.random @_module(), {user_id: user.id}, ({random})=>
        link_full = "#{ config_get('server') }#{ config_email.forget }/#{ [locale.lang_short(language), random].join('') }/#{ user.id }"
        email.send
          to: params.email
          subject: _l('UserNotify.Forget email subject')
          text: _l('UserNotify.Forget email text', {link_full})
          html: _l('UserNotify.Forget email html', {link_full})
        response
          body: locale._ 'UserNotify.Forget email response', language, { email: params.email }
      , 1000 * 60 * 30, 10

  authenticate: (params)->
    error = => @_socket.send 'authenticate:error'
    if !params
      return error()
    for platform in platforms
      if params[platform]
        api = new _authorize[platform]()
        return api.authorize {code: params[platform], language: params.language, params: params.params}, (user, user_params)=>
          if !user
            return error()
          @_socket.send 'authenticate:params', { [platform]: user_params or params[platform]  }
          @trigger 'login', user, api, params
    return error()

  remove: ->
    @_socket_bind.forEach (p)=> @_socket.removeListener p[0], @[p[1]]
    super()
