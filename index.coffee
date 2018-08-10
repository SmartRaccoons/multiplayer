module.exports.server =
  config: require('./config').config
  room:
    authorize: require('./server/room/authorize')
    anonymous: require('./server/room/anonymous')
    user: require('./server/room/user')
    room: require('./server/room/room')
    rooms: require('./server/room/rooms')
  db:
    Mysql: require('./server/db/mysql').Mysql
  pubsub: require('./server/pubsub')
  locale: require('./locale')
  helpers:
    log: require('./server/helpers/log')
    template: require('./server/helpers/template')
  router:
    index: require('./server/router/index')
    urls: require('./server/router/urls')
