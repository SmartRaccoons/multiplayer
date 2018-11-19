module.exports =
  locale: require('./locale')
  config: require('./config')
  server:
    room:
      authorize: require('./server/room/authorize')
      anonymous: require('./server/room/anonymous')
      user: require('./server/room/user')
      room: require('./server/room/room')
      rooms: require('./server/room/rooms')
    db:
      mysql: require('./server/db/mysql').Mysql
    pubsub: require('./server/pubsub')
    helpers:
      log: require('./server/helpers/log')
      template: require('./server/helpers/template')
      email: require('./server/helpers/email')
    router:
      urls: require('./server/router/urls')
