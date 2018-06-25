test_server :
	 # --watch --watch-extensions coffee
	mocha --reporter dot --require coffee-script/register "./server/pubsub/test/*.coffee"
	mocha --reporter dot --require coffee-script/register "./server/room/test/*.coffee"
	mocha --reporter dot --require coffee-script/register "./server/api/test/*.coffee"
	mocha --reporter dot --require coffee-script/register "./server/pubsub/test/*.coffee"
compile :
	coffee -c client/*.coffee
	coffee -c client/browser/*.coffee
	coffee -c client/browser/view/*.coffee
	coffee -c locale/*.coffee
