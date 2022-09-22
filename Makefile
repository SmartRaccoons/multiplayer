test_server :
	 # --watch --watch-extensions coffee
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/pubsub/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/authorize/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/user/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/room/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/api/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/pubsub/test/*.coffee"
	./node_modules/mocha/bin/_mocha --reporter dot --require coffeescript/register "./server/router/test/*.coffee"
compile :
	./node_modules/coffeescript/bin/coffee -c client/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/view/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/view/popup/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/platform/*.coffee
	# ./node_modules/browserify/bin/cmd.js client/browser/analytic.firebase.browser.js -o client/browser/analytic.cordova.o.js
