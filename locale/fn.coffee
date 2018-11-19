translate_fn_generate = (locales)->
  (key, active = 'en', subparams)->
    res = locales[active][key]
    if not subparams
      return res
    res.replace /\\?\{([^{}]+)\}/g, (match, name) ->
      if match.charAt(0) == '\\'
        return match.slice(1)
      if subparams[name]
        return subparams[name]
      return ''

if exports?
  exports.translate_fn_generate = translate_fn_generate
