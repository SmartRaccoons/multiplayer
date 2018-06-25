module.exports.server =
  room:
    authorize: require('./server/room/authorize')
  #   anonymous: require('./server/room/anonymous')
  db:
    Mysql: require('./server/db/mysql').Mysql
  pubsub: require('./server/pubsub')
  helpers:
    log: require('./server/helpers/log')
    template: require('./server/helpers/template')
  router:
    index: require('./server/router/index')
    urls: require('./server/router/urls')

