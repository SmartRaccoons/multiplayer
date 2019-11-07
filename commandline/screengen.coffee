sharp = require('sharp')


gen = (img)->
  sharp(img.screen)
  .resize(img.width - img.padding, img.height - img.padding, {fit: 'inside'})
  .toBuffer()
  .then (screen)->
    sharp(img.screen_background)
    .resize(img.width, img.height, {fit: 'fill'})
    .composite([{ input: screen }])
    .jpeg({quality: 100, progressive: true})
    .toFile(img.dest)


exports.generate = (op, done)->
  Promise.all op.sizes.map (size)->
    gen({
      width: size[0]
      height: size[1]
      padding: if size[2] then size[2] else 0
      dest: "#{op.dest}/#{size[0]}x#{size[1]}.#{op.ext}"
      screen: op.screen
      screen_background: op.screen_background
    })
  .then => done()
