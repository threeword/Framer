assert = require "assert"
{expect} = require "chai"

initialStateName = "default"

stateWithoutName = (state) ->
	return _.pickBy(state, (value, key) -> key isnt "name")

describe "LayerStates", ->

	describe "Events", ->

		beforeEach ->
			@layer = new Layer()
			@layer.states.a = {x: 100, y: 100}
			@layer.states.b = {x: 200, y: 200}

		it "should emit StateSwitchStart when switching", (done) ->

			test = (previous, current, states) =>
				previous.should.equal initialStateName
				current.should.equal "a"
				@layer.states.current.name.should.equal initialStateName
				@layer.states.machine._previousNames.should.eql []
				stateWithoutName(@layer.states.current).should.eql @layer.states[initialStateName]
				done()

			@layer.on Events.StateSwitchStart, test
			@layer.animate "a", instant: true

		it "should emit StateSwitchStop when switching", (done) ->

			test = (previous, current, states) =>
				previous.should.equal initialStateName
				current.should.equal "a"
				@layer.states.current.name.should.equal "a"
				@layer.states.machine._previousNames.should.eql ["default"]
				stateWithoutName(@layer.states.current).should.eql @layer.states.a
				done()

			@layer.on Events.StateSwitchStop, test
			@layer.animate "a", time: 0.01

		it "should emit StateSwitchStop when switching instant", (done) ->

			test = (previous, current, states) =>
				previous.should.equal initialStateName
				current.should.equal "a"
				@layer.states.current.name.should.equal "a"
				@layer.states.machine._previousNames.should.eql ["default"]
				stateWithoutName(@layer.states.current).should.eql @layer.states.a
				done()

			@layer.on Events.StateSwitchStop, test
			@layer.animate "a", instant: true

	describe "Special states", ->

		it "should work for current", ->
			layer = new Layer
			layer.states.current.name.should.equal "default"

		it "should work for previous", ->
			layer = new Layer

			layer.states.testA = {x: 100}
			layer.stateSwitch("testA")

			layer.x.should.equal 100
			layer.states.current.name.should.equal "testA"
			layer.states.current.x.should.equal 100

			layer.states.previous.name.should.equal "default"
			layer.states.previous.x.should.equal 0

		it "should always have previous", ->
			layer = new Layer

			layer.states.previous.name.should.equal "default"
			layer.states.previous.x.should.equal 0

	describe "Defaults", ->

		it "should set defaults", ->

			layer = new Layer
			layer.states.test = {x: 123}
			animation = layer.animate "test"

			animation.options.curve.should.equal Framer.Curves.fromString(Framer.Defaults.Animation.curve)

			Framer.Defaults.Animation =
				curve: "spring(1, 2, 3)"

			layer = new Layer
			layer.states.test = {x: 456}
			animation = layer.animate "test"

			animator = animation.options.curve()
			animator.options.tension.should.equal 1
			animator.options.friction.should.equal 2
			animator.options.velocity.should.equal 3

			Framer.resetDefaults()

	describe "Adding", ->

		describe "when setting multiple states", ->

			it "should override existing states", ->
				layer = new Layer
				layer.states.test = x: 100
				layer.stateNames.sort().should.eql [initialStateName, "test"].sort()
				layer.states =
					stateA: x: 200
					stateB: scale: 0.5
				layer.stateNames.sort().should.eql [initialStateName, "stateA", "stateB"].sort()

			it "should reset the previous and current states", ->
				layer = new Layer
				layer.states.test = x: 100
				layer.stateSwitch "test"
				layer.states =
					stateA: x: 200
					stateB: scale: 0.5
				layer.states.previous.name.should.equal initialStateName
				layer.states.current.name.should.equal initialStateName

	describe "Initial", ->

		testStates = (layer, states) ->
			layer.stateNames.sort().should.eql(states)
			Object.keys(layer.states).sort().should.eql(states)
			(k for k, v of layer.states).sort().should.eql(states)

		it "should have an initial state", ->
			layer = new Layer
			testStates(layer, [initialStateName])

		it "should have an extra state", ->
			layer = new Layer
			layer.states.test = {x: 100}
			testStates(layer, [initialStateName, "test"])

	describe "Switch", ->

		it "should switch instant", ->

			layer = new Layer
			layer.states =
				stateA:
					x: 123
				stateB:
					y: 123
					options:
						instant: true

			layer.stateSwitch "stateA"
			layer.states.current.name.should.equal "stateA"
			layer.x.should.equal 123

			layer.stateSwitch "stateB"
			layer.states.current.name.should.equal "stateB"
			layer.y.should.equal 123

		it "should not change html when using switch instant", ->
			layer = new Layer
				html: "fff"
			layer.states.stateA = {x: 100}
			layer.animate "stateA", instant: true
			layer.html.should.equal "fff"

		it "should switch non animatable properties", ->
			layer = new Layer
			layer.states.stateA = {x: 100, image: "static/test2.png"}
			layer.animate "stateA", instant: true
			layer.x.should.equal 100
			layer.image.should.equal "static/test2.png"

		it "should not convert html to a color value if used in a state", ->
			layer = new Layer
			layer.states.stateA = {x: 100, html: "aaa"}
			layer.animate "stateA", instant: true
			layer.html.should.equal "aaa"

		it "should not change style when going back to initial", ->
			layer = new Layer
			layer.style.fontFamily = "Arial"
			layer.style.fontFamily.should.equal "Arial"

			layer.states =
				test: {x: 500}

			layer.animate "test", instant: true
			layer.x.should.equal 500
			layer.style.fontFamily = "Helvetica"
			layer.style.fontFamily.should.equal "Helvetica"

			layer.animate initialStateName, instant: true
			layer.x.should.equal 0
			layer.style.fontFamily.should.equal "Helvetica"

		# it "should be a no-op to change to the current state", ->
		# 	layer = new Layer
		# 	layer.states.stateA = {x: 100}
		# 	layer.stateSwitch "stateA"
		# 	animation = layer.animate "stateA", time: 0.05
		# 	assert.equal(animation, null)

		it "should change to a state when the properties defined are not the current", (done) ->
			layer = new Layer
			layer.states.stateA = {x: 100}
			layer.stateSwitch "stateA"
			layer.x = 150
			layer.onStateDidSwitch ->
				layer.states.current.name.should.equal "stateA"
				layer.x.should.equal 100
				done()
			animation = layer.animate "stateA", time: 0.05

	it "should change the state name when using 'previous' as stateName", (done) ->
		layer = new Layer
		layer.states =
			stateA: x: 200
			stateB: scale: 0.5
		layer.stateSwitch "stateB"
		layer.stateSwitch "stateA"
		layer.stateSwitch "stateB"
		layer.onStateDidSwitch ->
			assert.equal layer.states.current.name, "stateA"
			done()
		layer.animate "previous"

	describe "Properties", ->

		it "should bring back the 'initial' state values when using 'stateCycle'", (done) ->

			layer = new Layer
			layer.states =
				stateA: {x: 100, rotation: 90, options: time: 0.05}
				stateB: {x: 200, rotation: 180, options: time: 0.05}

			layer.x.should.equal 0

			ready = (animation, layer) ->
				switch layer.states.current.name
					when "stateA"
						layer.x.should.equal 100
						layer.rotation.should.equal 90
						layer.stateCycle()
					when "stateB"
						layer.x.should.equal 200
						layer.rotation.should.equal 180
						layer.stateCycle(time: 0.05)
					when initialStateName
						layer.x.should.equal 0
						layer.rotation.should.equal 0
						done()

			layer.on Events.AnimationEnd, ready
			layer.stateCycle()

		it "should bring cycle when using 'stateCycle'", (done) ->

			layer = new Layer

			layer.states.stateA =
				x: 302
				y: 445

			layer.x.should.equal 0

			count = 0
			ready = (animation, layer) ->
				if count is 4
					done()
					return
				count++
				switch layer.states.current.name
					when "stateA"
						layer.x.should.equal 302
						layer.y.should.equal 445
						layer.stateCycle(time: 0.05)
					when initialStateName
						layer.x.should.equal 0
						layer.rotation.should.equal 0
						layer.stateCycle(time: 0.05)

			layer.on Events.AnimationEnd, ready
			layer.stateCycle(time: 0.05)

		it "ignoreEvents should not be part of the initial state", ->

			layer = new Layer

			layer.states.stateA =
				backgroundColor: "rgba(255, 0, 255, 1)"

			layer.onClick ->
				layer.stateCycle()

			layer.x.should.equal 0

			layer.stateCycle(instant: true)
			layer.stateCycle(instant: true)
			layer.stateCycle(instant: true)
			layer.ignoreEvents.should.equal false


		it "should set scroll property", ->

			layer = new Layer
			layer.states =
				stateA: {scroll: true}
				stateB: {scroll: false}

			layer.animate "stateA", instant: true
			layer.scroll.should.equal true

			layer.animate "stateB", instant: true
			layer.scroll.should.equal false

			layer.animate "stateA", instant: true
			layer.scroll.should.equal true

		it "should set non numeric properties with animation", (done) ->

			layer = new Layer
			layer.states =
				stateA: {scroll: true, backgroundColor: "red"}

			layer.scroll.should.equal false

			layer.on Events.StateDidSwitch, ->
				layer.scroll.should.equal true
				layer.style.backgroundColor.should.equal new Color("red").toString()
				done()

			layer.animate "stateA"

		it "should set non and numeric properties with animation", (done) ->

			layer = new Layer
			layer.states =
				stateA: {x: 200, backgroundColor: "red"}

			# layer.scroll.should.equal false
			layer.x.should.equal 0

			layer.on Events.StateDidSwitch, ->
				# layer.scroll.should.equal true
				layer.x.should.equal 200
				layer.style.backgroundColor.should.equal new Color("red").toString()
				done()

			layer.animate "stateA", {curve: "linear", time: 0.1}

		it "should restore the initial state when using non exportable properties", ->

			layer = new Layer
			layer.states =
				stateA: {midX: 200}

			layer.x.should.equal 0

			layer.animate "stateA", instant: true
			layer.x.should.equal 200 - (layer.width // 2)

			layer.animate initialStateName, instant: true
			layer.x.should.equal 0

		it "should set the parent", ->

			layerA = new Layer
			layerB = new Layer
				parent: layerA
			layerC = new Layer

			layerB.states =
				noParent:
					parent: null
				parentC:
					parent: layerC

			assert.equal(layerB.parent, layerA)
			layerB.animate "parentC", instant: true
			assert.equal(layerB.parent, layerC)
			layerB.animate "noParent", instant: true
			assert.equal(layerB.parent, null)

			layerB.animate initialStateName, instant: true
			# assert.equal(layerB.parent, layerA)

		it "should set the current and previous states when switching", ->

			layer = new Layer

			layer.states =
				stateA: {x: 100, options: instant: true}
				stateB: {y: 200, options: instant: true}

			layer.states.default.hasOwnProperty("name").should.equal false

			layer.states.previous.name.should.equal "default"
			layer.states.previous.x.should.equal 0
			layer.states.previous.y.should.equal 0
			stateWithoutName(layer.states.previous).should.eql layer.states.default

			layer.states.default.hasOwnProperty("name").should.equal false

			layer.stateSwitch("stateA")

			layer.states.current.name.should.equal "stateA"
			layer.states.current.x.should.equal 100

			layer.states.previous.name.should.equal "default"
			layer.states.previous.x.should.equal 0
			layer.states.previous.y.should.equal 0

			stateWithoutName(layer.states.current).should.eql layer.states.stateA
			stateWithoutName(layer.states.previous).should.eql layer.states.default


		it "should set the default state when creating a", ->
			layer = new Layer
			layer.states.current.name.should.equal initialStateName
			layer.states.default.x.should.equal 0

		it "should set the default state when creating b", ->
			layer = new Layer
				x: 100
			layer.states.current.name.should.equal initialStateName
			layer.states.default.x.should.equal 100

		it "should set the default state when creating c", ->
			layer = new Layer
			layer.states.default.x = 100
			layer.states.current.name.should.equal initialStateName
			layer.states.default.x.should.equal 100

		it "should listen to options provided to stateCycle", ->
			layer = new Layer
			layer.states =
				stateA: x: 300
				stateB: y: 300
			animation = layer.stateCycle ["stateA", "stateB"],
				curve: Bezier.linear
			animation.options.curve.should.equal Bezier.linear

		it "should correctly switch to next state without using an array stateCycle", ->
			layer = new Layer
			layer.states =
				stateA: x: 300
				stateB: y: 300
			layer.stateCycle "stateA", "stateB", {instant: true}
			layer.states.current.name.should.equal "stateA"
			layer.stateCycle "stateA", "stateB", {instant: true}
			layer.states.current.name.should.equal "stateB"
			layer.stateCycle "stateA", "stateB", {instant: true}
			layer.states.current.name.should.equal "stateA"

		it "should listen to options provided to stateCycle when no states are provided", ->
			layer = new Layer
			layer.states.test = x: 300
			animation = layer.stateCycle
				curve: "ease-in-out"
			animation.options.curve.should.equal Bezier.easeInOut

		# it "should throw an error when you try to override a special state", ->
		# 	layer = new Layer
		# 	throwing = ->
		# 		layer.states.initial = x: 300
		# 	expect(throwing).to.throw('The state \'initial\' is a reserved name.')

		it "should throw an error when one fo the states is a special state", ->
			layer = new Layer
			throwing = ->
				layer.states =
					something: y: 10
					previous: x: 300
			expect(throwing).to.throw('The state \'previous\' is a reserved name.')

	describe "Cycling", ->

		it "should do nothing without states", ->
			layer = new Layer
			layer.stateCycle()
			layer.states.current.name.should.equal "default"

		it "should cycle two", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.test = {x: 200}

			layer.on Events.StateSwitchEnd, ->
				layer.states.current.name.should.equal "test"
				done()

			layer.stateCycle()

		it "should cycle two with options", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.test = {x: 200}
			layer.stateCycle onEnd: ->
				layer.x.should.equal 200
				layer.states.current.name.should.equal "test"
				layer.stateCycle onEnd: ->
					layer.x.should.equal 0
					layer.states.current.name.should.equal "default"
					layer.stateCycle onEnd: ->
						layer.x.should.equal 200
						layer.states.current.name.should.equal "test"
						done()

		it "should not touch the options object", (done) ->
			layer = new Layer
			layer.states.test = {x: 200}
			options = {time: 0.1}
			layer.stateCycle(options)
			layer.once Events.StateDidSwitch, ->
				layer.x.should.equal 200
				layer.states.current.name.should.equal "test"
				layer.stateCycle(options)
				layer.once Events.StateDidSwitch, ->
					layer.x.should.equal 0
					layer.states.current.name.should.equal "default"
					done()

		it "should cycle three with options", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.stateCycle onEnd: ->
				layer.x.should.equal 200
				layer.states.current.name.should.equal "testA"
				layer.stateCycle onEnd: ->
					layer.x.should.equal 400
					layer.states.current.name.should.equal "testB"
					layer.stateCycle onEnd: ->
						layer.x.should.equal 0
						layer.states.current.name.should.equal "default"
						done()

		it "should cycle two out of three in a list", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.stateCycle ["testA", "testB"], onEnd: ->
				layer.x.should.equal 200
				layer.states.current.name.should.equal "testA"
				layer.stateCycle ["testA", "testB"], onEnd: ->
					layer.x.should.equal 400
					layer.states.current.name.should.equal "testB"
					layer.stateCycle ["testA", "testB"], onEnd: ->
						layer.x.should.equal 200
						layer.states.current.name.should.equal "testA"
						done()

		it "should cycle list without options", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.once Events.StateSwitchEnd, ->
				layer.states.current.name.should.equal "testB"
				layer.once Events.StateSwitchEnd, ->
					layer.states.current.name.should.equal "testA"
					done()
				layer.stateCycle ["testB", "testA"]
			layer.stateCycle ["testB", "testA"]

		it "should cycle multiple arguments without options", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.once Events.StateSwitchEnd, ->
				layer.states.current.name.should.equal "testB"
				layer.once Events.StateSwitchEnd, ->
					layer.states.current.name.should.equal "testA"
					done()
				layer.stateCycle "testB", "testA"
			layer.stateCycle "testB", "testA"


		it "should cycle two out of three in arguments", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.stateCycle "testA", "testB", onEnd: ->
				layer.x.should.equal 200
				layer.states.current.name.should.equal "testA"
				layer.stateCycle "testA", "testB", onEnd: ->
					layer.x.should.equal 400
					layer.states.current.name.should.equal "testB"
					layer.stateCycle "testA", "testB", onEnd: ->
						layer.x.should.equal 200
						layer.states.current.name.should.equal "testA"
						done()

		it "should cycle all without state list", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.stateCycle onEnd: ->
				layer.states.current.name.should.equal "testA"
				layer.stateCycle onEnd: ->
					layer.states.current.name.should.equal "testB"
					layer.stateCycle onEnd: ->
						layer.states.current.name.should.equal "default"
						done()

		it "should listen to animationOptions defined in a state", (done) ->
			layer = new Layer
			layer.animationOptions.time = 0.1
			layer.states.testA = {x: 200, animationOptions: curve: Bezier.easeOut}
			cycle = layer.stateCycle onEnd: ->
				layer.states.current.name.should.equal "testA"
				cycle2 = layer.stateCycle onEnd: ->
					layer.states.current.name.should.equal "default"
					cycle3 = layer.stateCycle onEnd: ->
						layer.states.current.name.should.equal "testA"
						done()
					cycle3.options.curve.should.equal Bezier.easeOut
					layer.animationOptions.should.eql {time: 0.1}
				cycle2.options.curve.should.equal Bezier.ease
				layer.animationOptions.should.eql {time: 0.1}
			cycle.options.curve.should.equal Bezier.easeOut
			layer.animationOptions.should.eql {time: 0.1}

	describe "Switch", ->

		it "should switch", ->
			layer = new Layer
			layer.states.testA = {x: 200}
			layer.states.testB = {x: 400}
			layer.states.current.name.should.equal "default"
			layer.stateSwitch("testA")
			layer.states.current.name.should.equal "testA"
			layer.x.should.equal 200
			layer.stateSwitch("testB")
			layer.x.should.equal 400
			layer.states.current.name.should.equal "testB"

		it "should throw an error when called without a stateName", ->
			layer = new Layer
			layer.states.testA = {x: 200}
			expect(-> layer.stateSwitch()).to.throw("Missing required argument 'stateName' in stateSwitch()")

	describe "Options", ->

		it "should listen to layer.options", ->
			layer = new Layer
			layer.animationOptions =
				time: 4
			animation = layer.animate
				x: 100
			animation.options.time.should.equal 4

		it "should listen to layer.animate options", ->
			layer = new Layer
			layer.states.test = {x: 100}
			animation = layer.animate "test", time: 4
			animation.options.time.should.equal 4

		it "should listen to layer.animate options.start", ->
			layer = new Layer
			layer.states.test = {x: 100}
			animation = layer.animate "test", start: false
			animation.isAnimating.should.equal false
			animation.start()
			animation.isAnimating.should.equal true

	describe "Callbacks", ->

		it "should call start", (done) ->

			layer = new Layer
			layer.states.test = x: 300

			onStart = ->
				layer.x.should.eql 0
				done()

			animation = layer.animate "test",
				onStart: onStart

			animation.options.onStart.should.equal onStart

		it "should call stop", (done) ->

			layer = new Layer
			layer.states.test = x: 300

			onStop = ->
				layer.x.should.eql 300
				done()

			animation = layer.animate "test",
				onStop: onStop
				time: 0.1

			animation.options.onStop.should.equal onStop

		it "should call end", (done) ->

			layer = new Layer
			layer.states.test = x: 300

			onEnd = ->
				layer.x.should.eql 300
				done()

			animation = layer.animate "test",
				onEnd: onEnd
				time: 0.1

			animation.options.onEnd.should.equal onEnd
