window.Cookies =
  set: (key, value)->
    try
      return window.localStorage.setItem(key, value)
    catch e
      return null
    return

  get: (key)->
    try
      return window.localStorage.getItem(key)
    catch e
      return null
