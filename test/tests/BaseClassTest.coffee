{expect} = require "chai"

describe "BaseClass", ->

	testProperty = (name, fallback) ->
		exportable: true
		default: fallback
		get: -> @_getPropertyValue name
		set: (value) -> @_setPropertyValue name, value


	it "should be unique per instance", ->

		class TestClassA extends Framer.BaseClass
			@define "testA", testProperty "testA", 100

		class TestClassB extends Framer.BaseClass
			@define "testB", testProperty "testB", 100

		a = new TestClassA()
		b = new TestClassB()

		a.props.should.eql {testA: 100}
		b.props.should.eql {testB: 100}

	class TestClass extends Framer.BaseClass
		@define "width", testProperty "width", 0
		@define "height", testProperty "height", 0

	it "should set defaults", ->

		testClass = new TestClass()

		testClass.width.should.equal 0
		testClass.height.should.equal 0

	it "should set defaults on construction", ->

		testClass = new TestClass width: 100, height: 100

		testClass.width.should.equal 100
		testClass.height.should.equal 100

	it "should set a property value", ->

		testClass = new TestClass()
		testClass.width = 500

		testClass.width.should.equal 500
		testClass.height.should.equal 0

	it "should set to zero", ->

		class TestClass2 extends Framer.BaseClass
			@define "test", testProperty "test", 100

		testClass = new TestClass2()
		testClass.test.should.equal 100

		testClass.test = 0
		testClass.test.should.equal 0

	it "should override defaults", ->

		testClass = new TestClass
			width: 500

		testClass.width.should.equal 500
		testClass.height.should.equal 0

	it "should get props", ->

		testClass = new TestClass
			width: 500

		testClass.props.should.eql
			width: 500
			height: 0

	it "should set props", ->

		testClass = new TestClass

		testClass.props.should.eql
			width: 0
			height: 0

		testClass.props = {width: 500, height: 500}

		testClass.props.should.eql
			width: 500
			height: 500

	it "should have keys", ->

		class TestClass3 extends Framer.BaseClass
			@define "testA", @simpleProperty "testA", 100
			@define "testB", @simpleProperty "testB", 100

		testClass = new TestClass3()
		testClass.keys().should.eql ["testA", "testB"]

	it "should have keys", ->

		class TestClass3 extends Framer.BaseClass
			@define "testA", @simpleProperty "testA", 100
			@define "testB", @simpleProperty "testB", 100

		testClass = new TestClass3()
		testClass.keys().should.eql ["testA", "testB"]

	it "should work with proxyProperties", ->

		class TestClass7 extends Framer.BaseClass
			@define "testA", @proxyProperty("poop.hello")

			constructor: ->
				super

				@poop = {hello: 100}

		testClass = new TestClass7()
		testClass.poop.hello.should.equal 100
		testClass.testA.should.equal 100
		testClass.testA = 200
		testClass.poop.hello.should.equal 200

	it "should exclude prop from props, when exportable is false", ->

		class TestClass extends Framer.BaseClass
			@define "testProp",
				get: -> "value"
				exportable: false

		instance = new TestClass()
		props = instance.props

		props.hasOwnProperty("testProp").should.be.false

		props = {}
		for field of instance
			props[field] = true

		props.hasOwnProperty("testProp").should.be.true

	it "should exclude prop from enumeration, when enumerable is lowered", ->

		class TestClass extends Framer.BaseClass
			@define "testProp",
				get: -> "value"
				enumerable: false

		instance = new TestClass()
		props = {}
		for field of instance
			props[field] = true

		props.hasOwnProperty("testProp").should.be.false

	it "should throw on assignment of read-only prop", ->
		class TestClass extends Framer.BaseClass
			@define "testProp",
				get: -> "value"

		instance = new TestClass()
		(-> instance.testProp = "foo").should.throw "TestClass.testProp is readonly"

	it "should not set read-only prop via props setter", ->

		class TestClass extends Framer.BaseClass

			@define "testPropA",
				get: -> @_propA
				set: (value) -> @_propA = value

			@define "testPropB",	get: -> "value"

		instance = new TestClass()
		instance.props =
			testPropA: "a"
			testPropB: true

		instance.testPropA.should.equal "a"
		instance.testPropB.should.equal "value"

	it "should have defined properties set in sibling subclasses", ->

		class LalaLayer extends Framer.BaseClass
			@define "blabla",
				get: -> "hoera"
				set: -> "sdfsd"

		class TestClassD extends LalaLayer
			@define "a",
				get: -> "getClassD"
				set: -> "setClassD"


		class TestClassC extends LalaLayer
			@define "a",
				get: -> "getClassC"
				# set: -> "setClassC"

		d = new TestClassD
		c = new TestClassC
		expect(d._propertyList()?.a?.set).to.be.ok
		expect(c._propertyList()?.a?.set).to.not.be.ok


	it "should not export a shared property name in props of in sibling subclasses", ->

		class BaseSubClass extends Framer.BaseClass
			@define "blabla",
				get: -> "hoera"
				set: -> "sdfsd"

		class SiblingA extends BaseSubClass
			@define "sharedProperty",
				get: -> "getSiblingA"
				set: -> "setSiblingA"

		class SiblingB extends BaseSubClass
			@define "sharedProperty",
				get: -> "getSiblingB"

		a = new SiblingA
		b = new SiblingB
		expect(a.sharedProperty).to.be.ok
		expect(b.sharedProperty).to.be.ok
		expect(a.props.sharedProperty).to.be.ok
		expect(b.props.sharedProperty).to.not.be.ok
		expect(a.blabla).to.be.ok
		expect(b.blabla).to.be.ok
		expect(a.props.blabla).to.be.ok
		expect(b.props.blabla).to.be.ok

	it "should allow overrides of properties", ->
		class TestA extends Framer.BaseClass
			@define "test", @simpleProperty("test", "a")
		class TestB extends TestA
			@define "test", @simpleProperty("test", "b")
		a = new TestA
		b = new TestB
		a.test.should.equal "a"
		b.test.should.equal "b"

	it "should allow readonly overrides of readable properties", ->
		class TestA extends Framer.BaseClass
			@define "test",
				get: -> @_bla ? "bla"
				set: (value) -> @_bla = value
		class TestB extends TestA
			@define "test",
				get: -> "hoera"
		a = new TestA
		b = new TestB
		a.test.should.equal "bla"
		a.test = "test"
		a.test.should.equal "test"

		b.test.should.equal "hoera"
		(-> b.test = "test").should.throw "TestB.test is readonly"
		b.test.should.equal "hoera"

	it "should not include a readonly overrides of readable property in props", ->
		class TestA extends Framer.BaseClass
			@define "test",
				get: -> @_bla ? "bla"
				set: (value) -> @_bla = value
		class TestB extends TestA
			@define "test",
				get: -> "hoera"
		b = new TestB
		b.props.should.eql {}

	it "should inherit properties", ->
		class TestInherit extends Framer.BaseClass
			@define "test", @simpleProperty("test", "a")
		class TestInheritB extends TestInherit
		a = new TestInherit
		b = new TestInheritB
			test: null
		a.test.should.equal "a"
		b.test.should.equal "a"
