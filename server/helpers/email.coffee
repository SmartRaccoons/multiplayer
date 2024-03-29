SMTPClient = require('emailjs').SMTPClient

email = null

config = {}
module.exports.config = (c)->
  config = c
  email = new SMTPClient if config.server_config then config.server_config else {
    user: config.email
    password: config.pass
    host: 'smtp.gmail.com'
    ssl: true
  }


module.exports.send = email_send = (params, callback=->)->
  email.send Object.assign({}, params, {
    subject: "#{config.name} #{params.subject}"
    from: "<#{config.email}>"
  }, if params.html then {
    attachment: [{
      alternative: true
      data: params.html
    }]
    html: null
  } ), (err)->
    if err
      console.log 'EMAIL ERROR', new Date(), err
    callback(err)


module.exports.send_admin = (params)-> email_send Object.assign({to: config.report}, params)


errors_log = []
module.exports.log = (err, _messages = [], callback=->)->
  errors_log.push(new Date().getTime())
  email_send {
    subject: (if err then ' server error: ' + err.message else '')
    text: ''
    to: config.report
    attachment: [{
      alternative:true
      data: """
        #{(if err then err.stack + ''+ '<br /><br />' else '')}
        <br />
        #{_messages.join("\n<br />")}
      """
    }]
  }, (err_email)->
    fatal = (type, err)=>
      console.info type, err
      process.exit(1)
    if err_email
      return fatal('mail error', err_email)
    if err.code in ['ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT']
      return fatal('predefiend fatal', err)
    if errors_log.length > 2
      if errors_log[2] - errors_log[0] < 3 * 1000
        process.exit(1)
      errors_log.shift()
    callback(err)
