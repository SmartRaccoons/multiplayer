events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class Model extends SimpleEvent
  constructor: (attributes)->
    super()
    @attributes = attributes
    @id = @attributes.id
  data_public: -> {id: @id}


PubsubServer_methods =
  constructor: ->

PubsubServerObjects = proxyquire('../default', {
  '../pubsub/multiserver':
    PubsubServer: class PubsubServer extends SimpleEvent
      constructor: ->
        super()
        PubsubServer_methods.constructor.apply(@, arguments)
}).PubsubServerObjects

class PubsubServerObjects extends PubsubServerObjects
  model: -> Model


describe 'models', ->
  spy = null
  spy2 = null
  clock = null
  models = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    spy2 = sinon.spy()
    models = new PubsubServerObjects()
    models.emit_immediate_exec = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'default', ->
    it 'constructor', ->
      PubsubServer_methods.constructor = sinon.spy()
      models = new PubsubServerObjects()
      assert.equal(1, PubsubServer_methods.constructor.callCount)
      assert.deepEqual([], models._objects)
      assert.deepEqual([], models._all)

    it 'get', ->
      models._objects = [{id: 2}, {id: 4}, {id: 1}]
      assert.equal(4, models.get(4).id)
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
      assert.equal(1, models._objects[0].id)

    it '_create (remove)', ->
      models._create({id: 1})
      models._create({id: 2}).trigger 'remove'
      assert.equal(1, models._objects.length)
      assert.equal(1, models._objects[0].id)

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

    it '_objects_exec', ->
      models._objects = [{exec: spy}, {exec: spy2}]
      models._objects_exec({exec: {p: 'a'}})
      assert.equal(1, spy.callCount)
      assert.deepEqual({p: 'a'}, spy.getCall(0).args[0])
      assert.equal(1, spy2.callCount)
      assert.deepEqual({p: 'a'}, spy2.getCall(0).args[0])

    it '_objects_exec (filter)', ->
      spy3 = sinon.spy()
      models._objects = [
        {exec: spy, data_public: -> {tour: 5, id: 2}}
        {exec: spy2, data_public: -> {tour: 5, id: 3}}
        {exec: spy3, data_public: -> {tour: 6, id: 4}}
      ]
      models._objects_exec({exec: {p: 'a'}, filter: {id: 2}})
      assert.equal(1, spy.callCount)
      assert.equal(0, spy2.callCount)
      models._objects_exec({exec: {p: 'a'}, filter: {tour: 5}})
      assert.equal(2, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.equal(0, spy3.callCount)
