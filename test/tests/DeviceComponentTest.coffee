assert = require "assert"

describe "DeviceComponent", ->

	it "should default to iphone 7 silver", ->

		comp = new DeviceComponent()
		comp.deviceType.should.equal "apple-iphone-7-silver"

	it "should use images on server for built in devices when not in Studio", ->

		comp = new DeviceComponent()
		localUrl = "resources.framerjs.com/static/DeviceResources/"
		imageUrl = comp._deviceImageUrl(comp._deviceImageName())

		result = imageUrl.indexOf(localUrl)

		result.should.not.equal -1

	it "should use the deviceImage string as is for custom devices when not in Studio", ->

		comp = new DeviceComponent()

		DeviceComponent.Devices["test"] =
			"deviceType": "phone"
			"screenWidth": 720
			"screenHeight": 1000
			"deviceImage": "images/framer-icon.png"
			"deviceImageWidth": 800
			"deviceImageHeight": 1203

		# Set custom device
		comp.deviceType = "test"

		comp.deviceType.should.equal "test"
		comp._deviceImageUrl(comp._deviceImageName()).should.eql "images/framer-icon.png"

	it "should use the local file url when run in Studio with built in device", ->

		# stub isFramerStudio helper
		_originalIsFramerStudio = Utils.isFramerStudio
		Utils.isFramerStudio = ->
			return true
		Utils.isFramerStudio().should.be.true

		# stub framerStudioVersion

		_originalIsFramerStudioVersion = Utils.framerStudioVersion
		Utils.framerStudioVersion = ->
			return Number.MAX_VALUE

		# example url
		localFileUrl = "file:///Users/name/Library/Developer/Xcode/DerivedData/Framer_Studio/Build/Products/Debug/Framer%20Studio.app/Contents/Resources/DeviceImages/"

		window.FramerStudioInfo = new Object()
		window.FramerStudioInfo.deviceImagesUrl = localFileUrl

		window.FramerStudioInfo.deviceImagesUrl.should.equal(localFileUrl)

		comp = new DeviceComponent()
		imageUrl = comp._deviceImageUrl(comp._deviceImageName())

		result = imageUrl.indexOf(localFileUrl)
		result.should.not.equal -1

		# reset stubs
		Utils.isFramerStudio = _originalIsFramerStudio
		Utils.framerStudioVersion = _originalIsFramerStudioVersion

	it "should use deviceImageName when a custom device is used in Studio", ->

		# stub isFramerStudio helper
		_originalIsFramerStudio = Utils.isFramerStudio
		Utils.isFramerStudio = ->
			return true
		Utils.isFramerStudio().should.be.true

		comp = new DeviceComponent()

		DeviceComponent.Devices["test"] =
			"deviceType": "phone"
			"screenWidth": 720
			"screenHeight": 1000
			"deviceImage": "images/framer-icon.png"
			"deviceImageWidth": 800
			"deviceImageHeight": 1203

		# Set custom device
		comp.deviceType = "test"

		comp.deviceType.should.equal "test"

		imageUrl = comp._deviceImageUrl(comp._deviceImageName())

		imageUrl.should.equal "images/framer-icon.png"

		# reset stubs
		Utils.isFramerStudio = _originalIsFramerStudio

	it "should influence screen", ->

		device = new DeviceComponent()

		device.deviceType = "fullscreen"
		device.context.devicePixelRatio = 2
		device.context.run ->
			Screen.size.width.should.eql Canvas.size.width / 2
			Screen.size.height.should.eql Canvas.size.height / 2

		device.deviceType = "nexus-5-black"
		device.context.run ->
			Screen.size.should.eql {width: 360, height: 640}
			Utils.inspect(Screen).should.equal "<Screen 360x640>"

	it "should calculate canvas frames", ->

		Screen.size.should.eql Canvas.size

		device = new DeviceComponent()

		device.deviceType = "nexus-5-black"
		device.context.run ->
			Screen.size.should.eql {width: 360, height: 640}
			Screen.canvasFrame.should.eql device.screen.canvasFrame

		device.deviceType = "fullscreen"
		device.context.run ->
			Screen.size.width.should.eql Canvas.size.width / device.context.devicePixelRatio
			Screen.size.height.should.eql Canvas.size.height / device.context.devicePixelRatio

	it "should return landscape and portrait screen sizes", ->

		Screen.size.should.eql Canvas.size

		device = new DeviceComponent()

		device.deviceType = "nexus-5-black"

		device.orientation.should.equal 0
		device.isPortrait.should.equal true
		device.screenSize.should.eql {width: 360, height: 640}

		device.rotateLeft(false)
		device.orientation.should.equal 90
		device.isPortrait.should.equal false
		device.screenSize.should.eql {width: 640, height: 360}

		device.rotateRight(false)
		device.orientation.should.equal 0
		device.isPortrait.should.equal true
		device.screenSize.should.eql {width: 360, height: 640}

		device.rotateRight(false)
		device.orientation.should.equal -90
		device.isPortrait.should.equal false
		device.screenSize.should.eql {width: 640, height: 360}

	it "should return the correct platform per device", ->
		device = new Framer.DeviceComponent()
		for key, value of Framer.DeviceComponent.Devices
			device.deviceType = key
			switch device.platform()
				when "iOS"
					assert(_.startsWith(key, "iphone") or _.startsWith(key, "ipad") or _.startsWith(key, "apple-iphone") or _.startsWith(key, "apple-ipad"), "#{key} should not have platform iOS")
				when "watchOS"
					assert(_.startsWith(key, "apple-watch") or _.startsWith(key, "applewatch"), "#{key} should not have platform watchOS")
				when "Windows"
					assert(_.startsWith(key, "dell") or _.startsWith(key, "microsoft"), "#{key} should not have platform Windows")
				when "Android"
					assert(_.startsWith(key, "google") or _.startsWith(key, "nexus") or _.startsWith(key, "htc") or _.startsWith(key, "samsung"), "#{key} should not have platform Android")
				when "macOS"
					assert(_.startsWith(key, "apple-macbook") or _.startsWith(key, "apple-imac") or _.startsWith(key, "desktop-safari"), "#{key} should not have platform macOS")
				else
					# Exceptions
					assert(key in ["fullscreen", "custom", "sony-w85Oc", "test"], "#{key} should have a platform specified")

	describe "when not showing bezel", ->
		before ->
			Utils.isFramerStudio = ->
				return true

		it "the background color should follow the screen color", ->
			Canvas.backgroundColor = "red"
			Framer.Device.screen.backgroundColor = "green"
			Framer.Device.hideBezel = true
			Canvas.backgroundColor.toName().should.eql "green"
			Framer.Device.screen.backgroundColor = "blue"
			Canvas.backgroundColor.toName().should.equal "blue"

		it "should keep track of background changes", ->
			Canvas.backgroundColor = "red"
			Framer.Device.screen.backgroundColor = "green"
			Framer.Device.hideBezel = true
			Canvas.backgroundColor = "blue"
			Canvas.backgroundColor.toName().should.equal "green"
			Framer.Device.hideBezel = false
			Canvas.backgroundColor.toName().should.equal "blue"

	describe "when showing bezel", ->
		it "should revert to the background color before disabling the bezel", ->
			Canvas.backgroundColor = "red"
			Framer.Device.screen.backgroundColor = "green"
			Framer.Device.hideBezel = true
			Canvas.backgroundColor.toName().should.eql "green"
			Framer.Device.hideBezel = false
			Canvas.backgroundColor.toName().should.equal "red"
