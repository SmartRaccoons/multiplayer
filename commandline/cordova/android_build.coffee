fs = require('fs')
exec = require('child_process').exec
util = require('util')
exec_promise = util.promisify(exec)


exports.android_build = (op, done)->
  op = Object.assign {}, {
    path: 'cordova'
    bin: 'cordova'
    android:
      keystore: ''
      storePassword: ''
      alias: ''
      password: ''
      minApi: ''
  }, op
  exec_promise "cd cordova && #{op.bin} build android --release -- --keystore=#{op.android.keystore} --storePassword=#{op.android.storePassword} --alias=#{op.android.alias} --password=#{op.android.password} --gradleArg=-PcdvMinSdkVersion=#{op.android.minApi}"
  .then (res)=>
    console.info 'out: ', res.stdout
    console.info 'error: ', res.stderr
    fs.copyFileSync "#{op.path}/platforms/android/app/build/outputs/apk/release/app-release.apk", "#{op.path}/android.apk"
    done()
