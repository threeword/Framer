assert = require "assert"
{expect} = require "chai"

initialStateName = "default"

describe "LayerStates Backwards compatibility", ->

	it "should still support layer.states.add", ->
		layer = new Layer
		layer.states.add
			stateA: x: 200
			stateB: scale: 0.5
		assert.deepEqual layer.stateNames, [initialStateName, "stateA", "stateB"]
		assert.deepEqual layer.states.stateA, x: 200
		assert.deepEqual layer.states.stateB, scale: 0.5

	it "should still support layer.states.add single", ->
		layer = new Layer
		layer.states.add("stateA", x: 200)
		assert.deepEqual layer.stateNames, [initialStateName, "stateA"]
		assert.deepEqual layer.states.stateA, x: 200

	it "should still support layer.states.remove", ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		assert.deepEqual layer.stateNames, [initialStateName, "stateA", "stateB"]
		layer.states.remove "stateA"
		assert.deepEqual layer.stateNames, [initialStateName, "stateB"]

	it "should still support layer.states.switch", (done) ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.onStateDidSwitch ->
			assert.equal layer.states.current.name, "stateA"
			done()
		layer.states.switch "stateA"

	it "should still support layer.states.switchInstant", ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.states.switchInstant "stateB"
		assert.equal layer.states.current.name, "stateB"

	it "should still support layer.states.next", (done) ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.onStateDidSwitch ->
			assert.equal layer.states.current.name, "stateA"
			done()
		layer.states.next()

	it "should still support layer.states.next with string arguments", (done) ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.once Events.StateSwitchEnd, ->
			layer.states.current.name.should.equal "stateB"
			layer.once Events.StateSwitchEnd, ->
				layer.states.current.name.should.equal "stateA"
				done()
			layer.states.next("stateB", "stateA")
		layer.states.next("stateB", "stateA")

	it "should still support layer.states.next with list arguments", (done) ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.once Events.StateSwitchEnd, ->
			layer.states.current.name.should.equal "stateB"
			layer.once Events.StateSwitchEnd, ->
				layer.states.current.name.should.equal "stateA"
				done()
			layer.states.next ["stateB", "stateA"]
		layer.states.next ["stateB", "stateA"]

	it "should still support layer.states.animationOptions", ->
		layer = new Layer
		layer.states =
			stateA: x: 200
		layer.states.animationOptions =
			time: 4
		animation = layer.animate "stateA"
		animation.options.time.should.equal 4

	it "should still support layer.states.animationOptions and fall back", ->
		# This used to crash: https://www.facebook.com/groups/framerjs/permalink/987570871369984/
		shoes = new Layer
		shoes.states.stateA = scale: 1
		shoes.states.stateB = scale: 0.8
		shoes.states.animationOptions =
			curve: "spring (300,20,0)"
		shoes.states.next()


	# it "should work when using one of the deprecated methods as statename", ->
	# 	layer = new Layer
	# 	layer.states =
	# 		add: x: 200
	# 	layer.animate "add", instant: true
	# 	assert.equal layer.states.add.x, 200
	# 	assert.equal layer.x, 200

	# it "should work when mixing old and new API's", ->
	# 	layerA = new Layer
	# 	layerA.states =
	# 		add: y: 100
	# 		next: x: 200
	# 	layerB = new Layer
	# 	layerB.states.add
	# 		a: y: 300
	# 		b: x: 400
	# 	layerA.animate "next", instant: true
	# 	layerA.animate "add", instant: true
	# 	assert.equal layerA.states.next.x, 200
	# 	assert.equal layerA.x, 200
	# 	assert.equal layerA.states.add.y, 100
	# 	assert.equal layerA.y, 100
	# 	layerB.states.next(instant: true)
	# 	layerB.states.next(instant: true)
	# 	assert.equal layerB.y, 300
	# 	assert.equal layerB.x, 400

	describe "Events", ->

		beforeEach ->
			@layer = new Layer()
			@layer.states.add("a", {x: 100, y: 100})
			@layer.states.add("b", {x: 200, y: 200})

		it "should emit StateWillSwitch when switching", (done) ->

			test = (previous, current, states) =>
				previous.should.equal "default"
				current.should.equal "a"
				@layer.states.current.name.should.equal "default"
				done()

			@layer.on Events.StateWillSwitch, test
			@layer.states.switchInstant "a"

		it "should emit didSwitch when switching", (done) ->

			test = (previous, current, states) =>
				previous.should.equal "default"
				current.should.equal "a"
				@layer.states.current.name.should.equal "a"
				done()

			@layer.on Events.StateDidSwitch, test
			@layer.states.switchInstant "a"


	describe "Defaults", ->

		it "should set defaults", ->

			layer = new Layer
			layer.states.add "test", {x: 123}
			animation = layer.states.switch "test"

			animation.options.curve.should.equal Framer.Defaults.Animation.curve

			Framer.Defaults.Animation =
				curve: "spring(1, 2, 3)"

			layer = new Layer
			layer.states.add "test", {x: 456}
			animation = layer.states.switch "test"

			animation.options.curve.should.equal "spring(1, 2, 3)"

			Framer.resetDefaults()
