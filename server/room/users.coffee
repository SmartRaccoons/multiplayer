
module.exports = class Users extends events.EventEmitter
  model: User
  constructor: ->
    @_objects = []
    @_all = []
    @on_users_exec (pr, server)=> @[pr.method](pr.params, server)

  _check_duplicate: (id)->
    model = @get(id)
    if model
      model.attributes.socket.disconnect('duplicate')

  _add: (ob, server)->
    if config.server_id isnt server
      @_check_duplicate(ob.id)
    @_all.push ob
    @emit 'add'

  _remove: (id)->
    index = @_all.findIndex (ob)-> ob.id is id
    if index < 0
      return
    @_all.splice(index, 1)
    @emit 'remove'

  get_session: (id)-> @_objects.find (ob)-> ob.attributes.socket.id is id

  get: (id, index=false)-> @_objects[if index then 'findIndex' else 'find'] (ob)-> ob.id() is id

  add_native: (attributes)->
    @_check_duplicate(attributes.id)
    model = new User(attributes)
    model.on 'remove', =>
      @_objects.splice @get(attributes.id, true), 1
      @emit_users_exec '_remove', model.id()
    @_objects.push model
    @emit_users_exec '_add', model.data_users()
    model

  publish_menu: (event, params)->
    @_objects.forEach (ob)=>
      if !ob.room
        ob.publish(event, params)

  set_coins: ({user_id, coins, type, params={}, complete})->
    pubsub.emit_user_exec user_id, 'set_coins', {coins, type, params}, complete

  buy: ({user_id, service, transaction_id, platform, complete})->
    @set_coins({user_id, type: 2, coins: config.buy[service], params: {service, platform, transaction_id}, complete})


['on_users_exec', 'emit_users_exec'].forEach (fn)-> Users::[fn] = -> pubsub[fn].apply(pubsub, arguments)
