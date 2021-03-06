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
    directory_clear: true
  }, op
  path_res = "#{op.path}/res"
  if op.directory_clear
    directory_clear(path_res)
  medias = cordova_media({platforms: op.platforms})
  fnc =
    icon: (img)->
      sh = sharp(op.icon)
      if img.width
        sh = sh.resize(img.width, img.height, {fit: 'inside'})
      if !op.icon_background
        return sh.toFile(img.dest)
      sh.toBuffer()
      .then (screen)->
        sh.metadata()
        .then (metadata)->
          width = if !img.width then metadata.width else img.width
          height = if !img.height then metadata.height else img.height
          sharp(op.icon_background)
          .resize(width, height, {fit: 'fill'})
          .composite([{ input: screen }])
          .toFile(img.dest)

    screen: (img)->
      sh = sharp(op.screen)
      if img.width
        padding = do =>
          if typeof img.padding is 'function'
            return img.padding(img)
          if img.padding
            return img.padding
          return Math.round(img.width * 0.1)
        sh = sh.resize(img.width - padding, img.height - padding, {fit: 'inside'})
      sh.toBuffer()
      .then (screen)->
        sh2 = sharp(op.screen_background)
        if img.width
          sh2 = sh2.resize(img.width, img.height, {fit: 'fill'})
        sh2
        .composite([{ input: screen }])
        .toFile(img.dest)

  Object.keys(medias).forEach (media)->
    if !fs.existsSync "#{path_res}/#{media}"
      fs.mkdirSync "#{path_res}/#{media}"
    Object.keys(medias[media]).forEach (platform)->
      if !fs.existsSync "#{path_res}/#{media}/#{platform}"
        fs.mkdirSync "#{path_res}/#{media}/#{platform}"
  Promise.all Object.keys(medias).map (media)->
    Promise.all Object.keys(medias[media]).map (platform)->
      Promise.all(
        medias[media][platform].map (img)->
          fnc[media](Object.assign({
            dest: "#{path_res}/#{media}/#{platform}/#{img.src}"
            padding: op.screen_padding
          }, img))
        .concat fnc[media]({dest: "#{path_res}/#{media}.png"})
      )
  .then => done()
