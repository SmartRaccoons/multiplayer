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


# emailjs builds Message-Id from os.hostname(), which on servers is not a real domain - spam filters punish it
message_counter = 0
message_id = -> "<#{Date.now()}.#{message_counter++}.#{process.pid}@#{config.email.split('@').pop()}>"


module.exports.send = email_send = (params, callback=->)->
  name = (config.name or '').replace(/[\[\]]/g, '').trim()
  message = Object.assign {}, params, {
    subject: "#{config.name} #{params.subject}".trim()
    from: "#{name} <#{config.email}>".trim()
    'message-id': message_id()
  }
  if params.html
    message.attachment = [{
      alternative: true
      data: params.html
    }]
  # any leftover key is sent as a mail header, so `html` must not stay in the message
  delete message.html
  email.send message, (err)->
    if err
      console.log 'EMAIL ERROR', new Date(), err
    callback(err)


module.exports.send_admin = (params)-> email_send Object.assign({to: config.report}, params)


errors_log = []
module.exports.log = (err, _messages = [], callback=->)->
  errors_log.push(new Date().getTime())
  email_send {
    subject: (if err then 'server error: ' + err.message else '')
    text: [ (if err then err.stack else ''), _messages.join("\n") ].join("\n\n").trim()
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
