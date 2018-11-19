test_server :
	 # --watch --watch-extensions coffee
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./server/pubsub/test/*.coffee"
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./server/room/test/*.coffee"
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./server/api/test/*.coffee"
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./server/pubsub/test/*.coffee"
compile :
	./node_modules/coffeescript/bin/coffee -c client/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/view/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/view/popup/*.coffee
	./node_modules/coffeescript/bin/coffee -c client/browser/platform/*.coffee
