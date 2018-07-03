events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class Room extends SimpleEvent
  constructor: (@attributes)->
  id: -> @attributes.id
  data_public: -> {id: @id()}


PubsubServer_methods =
  # constructor: ->

Rooms = proxyquire('../rooms', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> {Room}
  './default':
    PubsubServer: class PubsubServer extends SimpleEvent
      # constructor: -> PubsubServer_methods.constructor.apply(@, arguments)
}).Rooms


describe 'Rooms', ->
  spy = null
  clock = null
  rooms = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    rooms = new Rooms()

  afterEach ->
    clock.restore()

  describe 'default', ->
    it 'constructor', ->
      rooms = new Rooms()
      assert.equal('rooms', rooms._module)
      assert.deepEqual(Room, rooms.model())
