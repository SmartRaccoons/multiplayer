redis = require('redis')


module.exports.Memory = class Memory
  constructor: (@options)->
    @client = redis.createClient(@options.redis)

  random: (key, value, callback = ->, expire = 1000 * 60 * 5, length = 6, times = 0)->
    if times > 1000
      return console.info 'random error'
    max = Math.pow(10, length) - 1
    min = Math.pow(10, length - 1)
    random = Math.floor(Math.random() * (max - min + 1)) + min
    @client.set "#{key}:#{random}", JSON.stringify(value), 'PX', expire, 'NX', (err, reply)=>
      if err
        return console.info err
      if reply is null
        return @random key, value, callback, expire, length, times + 1
      callback({random})

  random_up: (key, random, value, callback = ->, expire = 1000 * 60 * 2)->
    @client.del  "#{key}:#{random}", =>
      @client.set "#{key}:#{random}", JSON.stringify(value), 'PX', expire, 'NX', (err, reply)=>
        if err
          return console.info err
        if reply is null
          return console.info 'cannot update random value'
        callback()

  random_remove: (key, random)-> @client.del  "#{key}:#{random}"

  random_get: (key, random, callback)->
    @client.get "#{key}:#{random}", (err, reply)->
      if err
        return console.info err
      callback(if reply then JSON.parse(reply) else null)
