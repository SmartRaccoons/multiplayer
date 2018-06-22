http = require('http')
https = require('https')


module.exports.ApiInbox = class ApiInbox
  url_api:
    port: 80
    hostname: 'api-games.inbox.lv'
    path: '/1.0/json'
  url_payment:
    port: 443
    hostname: 'payment.inbox.lv'
    path: '/api/1/json'

  constructor: (@config)->
    @_payment_callback = "#{@config.server}#{@config.inbox.transaction}"
    @_payment_completed = "#{@config.server}#{@config.inbox.transaction_completed}"

  authorize: (uid, callback, callback_error=->)->
    @_get_data false, {
      action: 'userdata'
      app: @config.inbox.api_key
      apiKey: uid
      data: 'fname,lname'
    }, (data)->
      callback
        name: [data.users[0].fname, data.users[0].lname].join(' ')
        # email: data.users[0].mail
    , callback_error

  transaction_create: (price, lang, callback, callback_error=->)->
    @_get_data true, {
      action: 'transactions/create'
      dev: @config.inbox.dev_id
      apiKey: @config.inbox.application_id
      prices: ['hbl', 'sebl', 'sms', 'paypal', 'ccard'].map((v)-> "#{v}-#{price}").join(', ')
      language: if ['en', 'ru'].indexOf(lang) >= 0 then lang else 'lv'
      skin: 'popup'
      callbackURI: @_payment_callback
      returnURI: "#{@_payment_completed}#{lang}.html"
      cancelURI: "#{@_payment_completed}#{lang}.html"
    }, ( (data)-> callback({id: data.id, link: data.link}) ), callback_error

  transaction_check: (transaction_id, callback, callback_error=->)->
    @_get_data true, {
      action: 'transactions/check'
      dev: @config.inbox.dev_id
      id: transaction_id
    }, (data)->
      if data.status is 'COMPLETED'
        callback()
      else
        callback_error('status is ' + data.status)
    , callback_error

  _get_data: (payment, data, callback, callback_error)->
    req = (if payment then https else http).request Object.assign({
      method: 'POST'
      headers:
        'Content-Type': 'application/json'
    }, if payment then @url_payment else @url_api), (res)->
      res.setEncoding('utf8')
      output = ''
      res.on 'data', (c)-> output+=c
      res.on 'end', ->
        try
          response = JSON.parse(output)
        catch e
        if response and response.code is '200 OK'
          return callback(response)
        callback_error('response error' + JSON.stringify(response))
    req.on 'error', (e)->
      callback_error('request error' + e)
    req.write JSON.stringify(data)
    req.end()
