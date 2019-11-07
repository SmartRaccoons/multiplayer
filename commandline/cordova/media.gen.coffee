sharp = require('sharp')
fs = require('fs')
cordova_media = require('./media').media
directory_clear = require('../helpers').directory_clear


exports.mediagen = (op, done)->
  op = Object.assign {}, {
    path: 'cordova'
    platforms: ['ios', 'android']
    icon: 'design/icon.png'
    screen: 'design/screen.png'
    screen_background: 'design/screen_background.png'
  }, op
  path_res = "#{op.path}/res"
  directory_clear(path_res)
  medias = cordova_media({platforms: op.platforms})
  fnc =
    icon: (img)->
      sh = sharp(op.icon)
      if img.width
        sh = sh.resize(img.width)
      sh.toFile(img.dest)
    screen: (img)->
      sh = sharp(op.screen)
      if img.width
        sh = sh.resize(img.width - img.padding, img.height - img.padding, {fit: 'inside'})
      sh.toBuffer()
      .then (screen)->
        sh2 = sharp(op.screen_background)
        if img.width
          sh2 = sh2.resize(img.width, img.height, {fit: 'fill'})
        sh2
        .composite([{ input: screen }])
        .toFile(img.dest)
  Object.keys(medias).forEach (media)->
    fs.mkdirSync "#{path_res}/#{media}"
    Object.keys(medias[media]).forEach (platform)->
      fs.mkdirSync "#{path_res}/#{media}/#{platform}"
  Promise.all Object.keys(medias).map (media)->
    Promise.all Object.keys(medias[media]).map (platform)->
      Promise.all(
        medias[media][platform].map (img)->
          fnc[media](Object.assign(img, {
            dest: "#{path_res}/#{media}/#{platform}/#{img.src}"
          }))
        .concat fnc[media]({dest: "#{path_res}/#{media}.png"})
      )
  .then => done()
