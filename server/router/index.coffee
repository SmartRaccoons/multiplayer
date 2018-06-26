# Anonymous = require('../room/anonymous')
# Users = require('../room/users')
# Rooms = require('../room/rooms')
# Authorize = require('../room/authorize')
module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback

Anonymous = null
config_callback( -> Anonymous = module_get('server.room.anonymous').Anonymous )()

module.exports.Router = class Router
  module: 'router'

  constructor: ->
    # do =>
    #   @users = new Users()
    #   # th = _.throttle =>
    #   #   @users.publish_menu.apply(@users, @_rooms_stats_args())
    #   # , 5000
    #   # @users.on 'add', th
    #   # @users.on 'remove', th
    #   setInterval =>
    #     @users._objects
    #     .filter (u)-> !u.alive()
    #     .forEach (u)-> u.get('socket').disconnect('timeout')
    #   ,  60 * 1000

    # @rooms = new Rooms()
    @pubsub().on_all_exec @module, (pr)=> @[pr.method](pr.params)

  # _rooms_stats_args: -> ['rooms:stats', {users: @users._all.length}]

  pubsub: -> config_get('pubsub')

  connection: (socket)->
    if @socket_preprocess
      @socket_preprocess(socket)
    # user = @users.get_session(socket.id)
    # if user
    #   user.get('socket').disconnect(null, false)
    #   user.set({'socket': socket})
    #   return
    anonymous = new Anonymous(socket).on 'login', (attr, api)=>
      anonymous.remove()
    #   user = @users.add_native(Object.assign({socket: socket}, attr))
    #   user.on 'room:set', => user.get('socket')._game = true
    #   user.on 'room:remove', => user.get('socket')._game = false
      # user.publish 'authenticate:success', user.data()
    #   user.publish.apply(user, @_rooms_stats_args())
    #   socket.on 'server:status', =>
    #     user.publish 'server:status',
    #       users: @users._all.length
    #   @_payment_platforms.forEach (platform)=>
    #     socket.on "buy:#{platform}", (service)=>
    #       api.buy {service, user_id: user.id(), language: user.get('language')}, (params)-> user.publish "buy:#{platform}:response", Object.assign({service}, params)
    #   if @tournament
    #     user.publish 'tournament:list', @tournament.get()
    #     socket.on 'tournament:top', (params)=>
    #       if not (params and params.tournament_id)
    #         return
    #       user.publish 'tournament:top', @tournament.top({user_id: user.id(), tournament_id: params.tournament_id})

  admin_restart: ->
    @socket_preprocess = (socket)->
      ['rooms:join'].forEach (ev)=>
        socket.on "before:#{ev}", =>
          socket.send 'user:inform', {body: 'restart in progress'}
          return false
    @users._objects.forEach (u)=> @socket_preprocess(u.get('socket'))
    @rooms._lobby.forEach (u)=> @rooms._lobby_remove(u.id)
    @rooms._objects.forEach (r)=> r._game_last()
    restart_available = =>
      if @rooms._objects.length > 0
        return false
      console.info 'restart available'
      return true
    if !restart_available()
      @rooms.on 'remove', => restart_available()

  admin_status: ->
    console.info "users: #{@users._objects.length} rooms: #{@rooms._objects.length} lobby: #{@rooms._lobby.length}"

  admin: ({command, params})->
    console.info "executing #{command} with #{params}"
    @pubsub().emit_all_exec(@module, "admin_#{command}", params)
