medias =
  icon:
    ios: [
      [50, 1, 2]
      [60, 1, 2, 3]
      [76, 1, 2]
      [40, 1, 2]
      [44, 2]
      [20, 1]
      ['icon', 57, 1, 2]
      [72, 1, 2]
      [167, 1]
      ['icon-small', 29, 1, 2, 3]
      [50, 1, 2]
      [83.5, 2]
      [1024, 1]

    ].concat(
      [24, 27.5, 86, 98, 108].map (v)->
        ["AppIcon#{v}x#{v}", v, 2]
    ).reduce (acc, params)->
      if typeof params[0] isnt 'string'
        params.unshift "icon-#{params[0]}"
      acc.concat [0..params.length - 3].map (i)->
        resize = params[2 + i]
        return {
          src: "#{params[0]}#{if resize > 1 then "@#{resize}x" else ''}.png"
          width: resize * params[1]
          height: resize * params[1]
          tag: 'icon'
        }
    , []

    android: [
      ['ldpi', 36]
      ['mdpi', 48]
      ['hdpi', 72]
      ['xhdpi', 96]
      ['xxhdpi', 144]
      ['xxxhdpi', 192]
    ].map (params)->
      return {
        src: "icon-#{params[1]}-#{params[0]}.png"
        width: params[1]
        height: params[1]
        tag: 'icon'
      }

  screen:
    ios: [
      ['@2x~universal~anyany', 2732, 2732]
      ['@2x~universal~comany', 1278, 2732]
      ['@2x~universal~comcom', 1334, 750]
      ['@3x~universal~anyany', 2208, 2208]
      ['@3x~universal~anycom', 2208, 1242]
      ['@3x~universal~comany', 1242, 2208]
    ].map( (params)->
      return {
        src: "Default#{params[0]}.png"
        width: params[1]
        height: params[2]
        tag: 'splash'
        dimensionhide: true
      }
    ).concat [
        # legacy
        ['~iphone', 320, 480]
        ['@2x~iphone', 640, 960]
        ['-Portrait~ipad', 768, 1024]
        ['-Portrait@2x~ipad', 1536, 2048]
        ['-Landscape~ipad', 1024, 768]
        ['-Landscape@2x~ipad', 2048, 1536]
        ['-568h@2x~iphone', 640, 1136]
        ['-667h', 750, 1334]
        ['-736h', 1242, 2208]
        ['-Landscape-736h', 2208, 1242]
        ['-2436h', 1125, 2436]
        ['-Landscape-2436h', 2436, 1125]
      ].map (params)->
        return {
          src: "Default#{params[0]}.png"
          width: params[1]
          height: params[2]
          tag: 'splash'
        }
    android: [
      ['hdpi', 800, 480]
      ['ldpi', 320, 200]
      ['mdpi', 480, 320]
      ['xhdpi', 1280, 720]
      ['xxhdpi', 1600, 960]
      ['xxxhdpi', 1920, 1280]
    ].reduce (acc, params)->
      acc.concat ['', 'land', 'port'].map (orientation)->
        orientation_dec = orientation or 'land'
        return {
          src: "splash-#{orientation_dec}-#{params[0]}.png"
          density: "#{if orientation then "#{orientation}-" else ''}#{params[0]}"
          width: if orientation_dec is 'land' then params[1] else params[2]
          height: if orientation_dec is 'land' then params[2] else params[1]
          tag: 'splash'
        }
    , []


exports.media = (op)->
  Object.keys(medias).reduce (acc, media)->
    acc[media] = op.platforms.reduce (acc, platform)->
      acc[platform] = medias[media][platform]
      acc
    , {}
    acc
  , {}
