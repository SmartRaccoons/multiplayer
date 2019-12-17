translate_fn_generate = (locales)->
  (key, active = 'en', subparams)->
    locale = locales[active]
    get = (key)->
      for subkey in key.split('.')
        res = (res or locale)[subkey]
        if !res
          return subkey
      return res
    res = get(key)
    if not subparams
      return res
    [
      (match, name)->
        array_param = name.match /\[([^\[\]]+)\]/
        if array_param and subparams[array_param[1]]?
          array_name = name.substr(0, name.length - array_param[0].length)
          array = get(array_name)
          if array
            if typeof subparams[array_param[1]] is 'boolean' and !array[ subparams[array_param[1]] ]
              return if subparams[array_param[1]] then array else ''
            if array[ subparams[array_param[1]] ]
              return array[ subparams[array_param[1]] ]
        res_replace = get(name)
        if !subparams[name] and res_replace
          return res_replace
        return match.slice(0)
      (match, name)->
        if subparams[name]?
          return subparams[name]
        return ''
    ].reduce ((acc, fn)->
      acc.replace /\\?\{([^{}]+)\}/g, (match, name)->
        if match.charAt(0) == '\\'
          return match.slice(1)
        return fn(match, name)
    ), res

if exports?
  exports.translate_fn_generate = translate_fn_generate
