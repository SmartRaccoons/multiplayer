http = require('https')


module.exports.ApiDraugiem = class ApiDraugiem
  app_id: null
  url: 'https://api.draugiem.lv/json/'

  authorize: (code, callback, callbackError=->)->
    @apiGet('authorize', {'code': code}, (res)=>
      @app_key = res['apikey']
      user = res['users'][res['uid']]
      user['inviter'] = if res['inviter'] then parseInt(res['inviter']) else null
      user['language'] = res['language']
      callback(user)
    , callbackError)

  transactionCreate: (service, price, callback, callbackError)->
    if not @app_key
      return callbackError()
    @apiGet 'transactions/create', {'service': service, 'price': price}, (res)=>
      callback(res['transaction'])
    , callbackError

  friends: (callback, callbackError=(->), page=1, friends=[])->
    @apiGet 'app_friends', {'show': 'ids', 'page': page, 'limit': 200}, (r)=>
      for k, v of r.userids
        friends.push(v)
      if r['total'] > page*200
        return @friends(callback, callbackError, page+1, friends)
      callback(friends)
    , callbackError

  apiGet: (action, args={}, callback, callbackError=->)->
    url = @url+'?'
    args['app'] = @app_id
    args['action'] = action
    if @app_key
      args['apikey'] = @app_key
    for pr, value of args
      url += '&'+pr+'='+value
    @_getUrl url, (data)=>
      try
        response = JSON.parse(data)
      catch e
      if response and not response['error']
        callback(response)
      else
        callbackError(response)

  _getUrl: (url, callback)->
    try
      http.get url, (res)->
        output = ''
        res.on 'data', (c)-> output+=c
        res.on 'end', -> callback(output)
      .on 'error', (e)->
          #TODO: test this case
          console.info "_getUrl: "+e.message
          callback()
    catch e
