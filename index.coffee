module.exports =
  locale: require('./locale')
  config: require('./config')
  server:
    authorize: require('./server/authorize')
    user: require('./server/user')
    room: require('./server/room')
    db:
      mysql: require('./server/db/mysql').Mysql
      memory: require('./server/db/memory').Memory
    pubsub: require('./server/pubsub')
    helpers:
      log: require('./server/helpers/log')
      template: require('./server/helpers/template')
      email: require('./server/helpers/email')
    router:
      urls: require('./server/router/urls')
