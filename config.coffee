get_depth_object = (object, path)->
  ob = null
  for part in path.split('.')
    if !(object and object[part])
      return null
    ob = object[part]
  return ob

config =
  config: {}
callbacks = []
module.exports.config = (c)->
  Object.assign config, c
  callbacks.forEach (callback)-> callback()
module.exports.config_get = config_get = (param)->
  if Array.isArray(param)
    return param.reduce (result, item)->
      Object.assign result, {[item]: config_get(item)}
    , {}
  config.config[param]
module.exports.config_callback = (callback)->
  callbacks.push(callback)
  callback
module.exports.module_get = (path)-> get_depth_object(config, path) or require("./#{path.replace(/\./g, '/')}")
