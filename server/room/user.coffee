events = require('events')
_ = require('lodash')
pubsub = require('../pubsub/connector').connection()
Login = require('./authorize').Login


_attr = require('./authorize')._attr


class User extends events.EventEmitter
  _attr: Object.keys(_attr)
  _attr_public: Object.keys(_attr).filter (k)-> !_attr[k].private
  _game_bet: [null, 0, 5, 20, 100, 1000]
  _game_bet_played: [0, 0, 5, 100, 150, 300]

  constructor: (attr, @options)->
    @attributes = _.extend({alive: new Date()}, attr)
    pubsub.on_user @id(), (pr)=> @publish(pr.event, pr.params)
    pubsub.on_user_exec @id(), (pr)=> @[pr.method](pr.params)
    @_bind_socket()
    @_update_bonus_day()
    @

  _bind_socket: ->
    @attributes.socket.on 'alive', => @set({alive: new Date()})
    ['give', 'wait', 'last'].forEach (ev)=>
      @attributes.socket.on "game:#{ev}", =>
        @room_exec '_game_exec', {user: @id(), method: ev}
    do =>
      ev = 'move'
      @attributes.socket.on "game:#{ev}", (params)=>
        if not (params and parseInt(params.pit) is params.pit)
          return
        @room_exec '_game_exec', {params: {pit: params.pit}, user: @id(), method: ev}
    @attributes.socket.on 'rooms:join', (params)=>
      if @room or !(params and @_game_bet.indexOf(params.bet) > -1)
        return
      bet = @bet_calculate(params.bet)
      if bet is false
        return
      @room = 'rooms'
      pubsub.emit_server_master_exec @room, '_lobby_add', Object.assign(bet, @data_room())
    @attributes.socket.on 'tournament:join', =>
      if @room
        return
      @room = 'tournament'
      pubsub.emit_server_master_exec @room, '_lobby_add', @data_room()
    @attributes.socket.on 'user:update', (params)=>
      if !params
        return
      if params.language
        @set({language: _attr['language'].validate(params.language)})
    do =>
      params = {type: 5, date: 30, coins: 20}
      @attributes.socket.on 'user:share:check', =>
        @_check_coins_bonus _.pick(params, ['type', 'date']), (updated)=>
          if updated
            return
          @publish 'user:share', _.pick params, ['coins']
      @attributes.socket.on 'user:share:bonus', => @set_coins_bonus(params)
    @attributes.socket.on 'rooms:left', => @_rooms_left()
    @attributes.socket.remove_callback = (immediate)=>
      if immediate
        @remove()

  alive: -> @get('alive').getTime() > new Date().getTime() - (if @room then 30 else 10) * 60 * 1000

  bet_calculate: (bet)->
    if bet is null
      for bet_max, j in @_game_bet.slice(2).reverse()
        if bet_max * 6 <= @get('coins') and @_game_bet_played[@_game_bet_played.length - 1 - j] <= @get('played')
          return {bet_max}
      return {bet_max: 0}
    if bet is 0 or bet * 2 <= @get('coins')
      return {bet}
    return false

  id: -> @attributes.id

  _room_is_lobby: -> ['rooms', 'tournament'].indexOf(@room) >= 0

  room_set: (room_id)->
    @room = room_id
    @emit 'room:set'

  room_remove: ->
    @room = null
    @publish 'rooms:remove'

  room_exec: (method, params)->
    if !@room or @_room_is_lobby()
      return
    pubsub.emit_room_exec.apply(pubsub, [@room, method, params])

  _rooms_left: ->
    if not @_room_is_lobby()
      return
    pubsub.emit_server_master_exec @room, '_lobby_remove', @id()

  publish: -> @attributes.socket.send.apply(@attributes.socket, arguments)

  data: -> _.pick @attributes, @_attr

  data_room: -> _.pick @attributes, ['coins'].concat(@_attr_public)

  data_users: -> _.pick @attributes, ['id', 'rating', 'coins']

  set: (params, silent=false)->
    Object.assign @attributes, params
    if 'socket' of params
      @_bind_socket()
    data = _.pick params, @_attr
    if Object.keys(data).length is 0
      return
    @publish 'user:set', data
    if !silent
      Login::_user_update(Object.assign({id: @id()}, data))

  get: (param)-> @attributes[param]

  set_coins: ({coins, type, params={}})->
    # 1 = game
    # 2 = buy
    # 3 = day bonus
    # 4 = room create fee
    # 5 - share bonus
    # 6 - tournament bonus
    @set({coins: @get('coins') + coins}, true)
    if type isnt 1
      @room_exec 'user_update', {id: @id(), coins: @get('coins')}
    @publish 'user:set_coins', {coins, type, params}
    Login::_user_update_coins({user_id: @id(), coins, type})

  set_coins_bonus: ({coins, type, date})->
    @_check_coins_bonus ({type, date}), (updated)=>
      if updated
        return
      @set_coins({type, coins})

  _check_coins_bonus: ({type, date}, callback)->
    Login::_user_get_coins {type, date, user_id: @id()}, (rows)=> callback rows and rows.length > 0

  _update_bonus_day: ->
    if @get('new') or @get('coins') >= 150 or @get('played') < 5
      return
    @set_coins_bonus({coins: 5, type: 3, date: 0})

  set_played: ->
    @set({played: @get('played') + 1}, true)
    Login::_user_update_played({id: @id()})

  remove: ->
    @_rooms_left()
    @room_exec('remove_user', @id())
    @emit 'remove'
    pubsub.remove_user @id()
