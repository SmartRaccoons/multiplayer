fs = require('fs')
exec = require('child_process').exec
glob = require('glob')
sharp = require('sharp')


directory_delete = (path)->
  if !fs.existsSync(path)
    return
  fs.readdirSync(path).forEach (file)->
    curPath = path + '/' + file
    if fs.lstatSync(curPath).isDirectory()
      return directory_delete curPath
    fs.unlinkSync curPath
  fs.rmdirSync path

directory_clear = (path)->
  directory_delete(path)
  fs.mkdirSync path


module.exports = (grunt, helpers, commands)->
  grunt.loadNpmTasks('grunt-contrib-watch')
  coffee = [
    'client/*.coffee'
    'client/**/*.coffee'
  ]
  exec_callback = (callback)->
    (error, stdout, stderr)->
      if error
        console.log('exec error: ' + error)
      callback()

  platform_compile_js = (platform, done)=>
    fs.writeFileSync 'all-temp.js', helpers.template.js_get(platform).map( (f)->
      if f.substr(-3) is '.js'
        return fs.readFileSync(f, 'utf8')
      return f
    ).join("\n")
    exec "#{commands.uglifyjs} all-temp.js -o public/d/j-#{platform}.js", (err)=>
      if err
        console.info err
        return done()
      exec "rm all-temp.js", => done()

  platform_compile_css = =>
    exec "#{commands.uglifycss} client/browser/css/screen.css > public/d/c.css"

  platform_compile_html = (params)=>
    fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", helpers.template.generate(Object.assign({development: false}, params))
    helpers.template.generate(Object.assign({development: false}, params))


  grunt.registerTask 'production', ->
    done = this.async()
    platform_compile_css()
    template_config = Object.keys(helpers.template.config_get().javascripts)
    platforms = ['standalone', 'draugiem', 'facebook', 'inbox'].filter (platform)-> template_config.indexOf(platform) >= 0
    platform_exec = (i)=>
      platform_compile_html {platform: platforms[i], template: 'game'}
      platform_compile_js platforms[i], =>
        if i >= platforms.length - 1
          return done()
        platform_exec(i + 1)
    platform_exec(0)

  grunt.registerTask 'compile', ->
    done = @async()
    files = []
    for extension in ['coffee', 'sass']
      files = files.concat(grunt.config(['watch'])[extension].files)
    compile = ->
      check = ->
        if files_all.length is 0
          return done()
        compile_file files_all.shift(), check
      compile_file files_all.shift(), check
    i = 0
    files_all = []
    files.forEach (f)->
      glob f, {}, (err, files_one)=>
        i++
        files_all = files_all.concat(files_one)
        if i is files.length
          compile()

  grunt.initConfig
    watch:
      coffee:
        files: coffee
      sass:
        files: ['client/browser/sass/*.sass']
      static:
        files: [
          'client/**/*.css'
          'client/**/*.js'
        ]
        options:
          livereload: true

  compile_file = (file, callback=->)->
    console.info "compile: #{file}"
    ext = file.split('.').pop()
    if ext is 'coffee'
      exec("#{commands.coffee} #{file}", exec_callback(callback))
    if ext is 'sass'
      exec("cd client/browser && compass compile --sourcemap sass/screen.sass -c ../../node_modules/multiplayer/client/browser/config.rb", exec_callback(callback))


  grunt.event.on 'watch', (event, file, ext)-> compile_file(file)
  grunt.registerTask('default', ['watch'])

  if helpers.screen
    ((scr)->
      grunt.registerTask 'production_screen', ->
        done = this.async()
        gen = (img)->
          sharp(scr.screen)
          .resize(img.width - img.padding, img.height - img.padding, {fit: 'inside'})
          .toBuffer()
          .then (screen)->
            sharp(scr.screen_background)
            .resize(img.width, img.height, {fit: 'fill'})
            .overlayWith(screen)
            .jpeg({quality: 100, progressive: true})
            .toFile(img.dest)
        Promise.all scr.sizes.map (size)->
          gen({
            width: size[0]
            height: size[1]
            padding: if size[2] then size[2] else 0
            dest: "#{scr.dest}/#{size[0]}x#{size[1]}.#{scr.ext}"
          })
        .then => done()

    )(helpers.screen)

  if helpers.cordova
    (({files, path, icon})->
      grunt.registerTask 'production_cordova', ->
        done = this.async()
        platform_compile_css()
        medias = helpers.cordova.medias()
        platform_compile_html
          platform: 'cordova'
          template: 'cordova-config'
          extension: 'xml'
          medias: Object.keys(medias).reduce (acc, media)->
            Object.keys(medias[media]).forEach (platform)->
              if !acc[platform]
                acc[platform] = []
              acc[platform] = acc[platform].concat medias[media][platform].map (img)->
                img.src = "res/#{media}/#{platform}/#{img.src}"
                img
            acc
          , {}
        fs.copyFileSync 'public/cordova.xml', "#{path}/config.xml"
        fs.unlinkSync 'public/cordova.xml'
        platform_compile_html {platform: 'cordova', template: 'cordova'}
        platform_compile_js 'cordova', =>
          path_www = "#{path}/www"
          directory_clear(path_www)
          fs.mkdirSync "#{path_www}/d"
          fs.mkdirSync "#{path_www}/d/images"
          fs.mkdirSync "#{path_www}/d/sounds"
          fs.copyFileSync 'public/cordova.html', "#{path_www}/index.html"
          fs.unlinkSync 'public/cordova.html'
          ['c.css', 'j-cordova.js'].concat(files).forEach (f)->
            fs.copyFileSync "public/d/#{f}", "#{path_www}/d/#{f}"
          fs.unlinkSync 'public/d/j-cordova.js'
          done()
      grunt.registerTask 'production_cordova_media', ->
        done = this.async()
        path_res = "#{path}/res"
        directory_clear(path_res)
        medias = helpers.cordova.medias()
        cordova_config = helpers.cordova.config_get()
        fnc =
          icon: (img)->
            sh = sharp(cordova_config.icon)
            if img.width
              sh = sh.resize(img.width)
            sh.jpeg({quality: cordova_config.img_params.quality or 100, progressive: true})
            sh.toFile(img.dest)
          screen: (img)->
            sh = sharp(cordova_config.screen)
            if img.width
              sh = sh.resize(img.width - img.padding, img.height - img.padding, {fit: 'inside'})
            sh.toBuffer()
            .then (screen)->
              sh2 = sharp(cordova_config.screen_background)
              if img.width
                sh2 = sh2.resize(img.width, img.height, {fit: 'fill'})
              sh2
              .overlayWith(screen)
              .jpeg({quality: cordova_config.img_params.quality or 100, progressive: true})
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
              .concat fnc[media]({dest: "#{path_res}/#{media}.jpg"})
            )
        .then => done()

    )(helpers.cordova.config_get())
