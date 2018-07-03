events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class Model extends SimpleEvent
  constructor: (@attributes)->
  id: -> @attributes.id
  data_public: -> {id: @id()}


PubsubServer_methods =
  constructor: ->

PubsubServer = proxyquire('../default', {
  '../pubsub/multiserver':
    PubsubServer: class PubsubServer extends SimpleEvent
      constructor: -> PubsubServer_methods.constructor.apply(@, arguments)
}).PubsubServer

class PubsubServer extends PubsubServer
  model: -> Model


describe 'models', ->
  spy = null
  clock = null
  models = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    models = new PubsubServer()
    models.emit_immediate_exec = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'default', ->
    it 'constructor', ->
      PubsubServer_methods.constructor = sinon.spy()
      models = new PubsubServer()
      assert.equal(1, PubsubServer_methods.constructor.callCount)
      assert.deepEqual([], models._objects)
      assert.deepEqual([], models._all)

    it 'get', ->
      models._objects = [{id: -> 2}, {id: -> 4}, {id: -> 1}]
      assert.equal(4, models.get(4).id())
      assert.equal(1, models.get(4, true))

    it '_add', ->
      models.bind 'add', spy
      models._add({id: 2})
      assert.deepEqual([{id: 2}], models._all)
      assert.equal(1, spy.callCount)

    it '_remove', ->
      models.bind 'remove', spy
      models._add({id: 1})
      models._add({id: 2})
      models._add({id: 3})
      models._remove(2)
      assert.deepEqual([{id: 1}, {id: 3}], models._all)
      assert.equal(1, spy.callCount)

    it '_create', ->
      model = models._create({type: 'sng', id: 1})
      assert.deepEqual({type: 'sng', id: 1}, model.attributes)
      assert.equal(1, models._objects.length)
      assert.equal(1, models._objects[0].id())

    it '_create (remove)', ->
      models._create({id: 1})
      models._create({id: 2}).trigger 'remove'
      assert.equal(1, models._objects.length)
      assert.equal(1, models._objects[0].id())

    it '_create (remove emit servers)', ->
      model = models._create({id: 2})
      models.emit_immediate_exec = spy = sinon.spy()
      model.trigger 'remove'
      assert.equal(1, spy.callCount)
      assert.equal('_remove', spy.getCall(0).args[0])
      assert.equal(2, spy.getCall(0).args[1])

    it '_create (emit servers)', ->
      models.emit_immediate_exec = spy = sinon.spy()
      models._create({type: 'sng', id: 1})
      assert.equal(1, spy.callCount)
      assert.equal('_add', spy.getCall(0).args[0])
      assert.deepEqual({id: 1}, spy.getCall(0).args[1])
