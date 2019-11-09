fs = require('fs')
cordova_media = require('./media').media
platform_compile_html = require('../helpers').platform_compile_html


exports.config_xml = (op, done)->
  op = Object.assign {}, {
    path: 'cordova'
    platforms: ['ios', 'android']
    template: {}
    config_local: {}
  }, op
  medias = cordova_media({platforms: op.platforms})
  platform_compile_html
    template: op.template
    params:
      platform: 'cordova'
      template: 'cordova-config'
      extension: 'xml'
      config_local: op.config_local
      medias: Object.keys(medias).reduce (acc, media)->
        Object.keys(medias[media]).forEach (platform)->
          if !acc[platform]
            acc[platform] = []
          acc[platform] = acc[platform].concat medias[media][platform].map (img)->
            img.src = "res/#{media}/#{platform}/#{img.src}"
            img
        acc
      , {}
  fs.copyFileSync 'public/cordova.xml', "#{op.path}/config.xml"
  fs.unlinkSync 'public/cordova.xml'
  done()
