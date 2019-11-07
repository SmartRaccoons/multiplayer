fs = require('fs')
exec = require('child_process').exec
glob = require('glob')
util = require('util')
exec_promise = util.promisify(exec)


module.exports = (grunt, helpers, commands)->
  grunt.loadNpmTasks('grunt-contrib-watch')
  exec_callback = (callback)->
    (error, stdout, stderr)->
      if error
        console.log('exec error: ' + error)
      callback()

  platform_compile_js = ({platform, babel})=>
    fs.writeFileSync "public/d/j-#{platform}.js", helpers.template.js_get(platform).map( (f)->
      if f.substr(-3) is '.js'
        return fs.readFileSync(f, 'utf8')
      return f
    ).join("\n")
    Promise.all(
      [
        if babel and commands.babel then commands.babel else null,
        if commands.uglifyjs then commands.uglifyjs else null
      ].filter (ex)-> !!ex
      .map (ex)-> exec_promise "#{ex} public/d/j-#{platform}.js -o public/d/j-#{platform}.js"
    )

  platform_compile_css = =>
    exec_promise "#{commands.uglifycss} client/browser/css/screen.css > public/d/c.css"

  platform_compile_html = (params)=>
    fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", helpers.template.generate(Object.assign({development: false}, params))
    helpers.template.generate(Object.assign({development: false}, params))


  grunt.registerTask 'production', ->
    done = this.async()
    template_config = Object.keys(helpers.template.config_get().javascripts)
    Promise.all( [
        platform_compile_css()
      ].concat(
        ['standalone', 'draugiem', 'facebook', 'inbox']
        .filter (platform)-> template_config.indexOf(platform) >= 0
        .map (platform)->
          platform_compile_html {platform, template: 'game'}
          platform_compile_js {platform, babel: true}
      )
    ).then => done()

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

  grunt.registerTask 'compile_facebook_payment', ->
    tml = helpers.template.facebook_payment()
    Object.keys(helpers.config.facebook.buy_price).forEach (id)->
      helpers.config.locales.forEach (lang)->
        file = "service-#{id}-#{lang}"
        fs.writeFileSync "public/d/og/#{file}.html", tml({
          id, lang, file,
          server: helpers.config.server
          locale: helpers.locale
          price: helpers.config.facebook.buy_price[id]
          coins: helpers.config.buy_coins[id]
        })


  grunt.initConfig
    watch:
      coffee:
        files: [
          'client/*.coffee'
          'client/**/*.coffee'
        ]
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
