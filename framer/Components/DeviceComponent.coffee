Utils = require "../Utils"
{_}   = require "../Underscore"

{BaseClass} = require "../BaseClass"
{Layer} = require "../Layer"
{Defaults} = require "../Defaults"
{Events} = require "../Events"

###

Device._setup()
Device._update()
Device._setupContext()

Device.fullScreen bool
Device.deviceType str
Device.padding int

Device.orientation(orientation:float)
Device.orientationName landscape|portrait|unknown
Device.rotateLeft()
Device.rotateRight()

Device.setDeviceScale(zoom:float, animate:bool)
Device.setContentScale(zoom:float, animate:bool)

Device.nextHand()

# Events
Events.DeviceTypeDidChange
Events.DeviceFullScreenDidChange


###

# _.extend Events,
# 	DeviceTypeDidChange: "change:deviceType"
# 	DeviceScaleDidChange: "change:deviceScale"
# 	DeviceContentScaleDidChange: "change:contentScale"
# 	DeviceFullScreenDidChange: ""

class exports.DeviceComponent extends BaseClass

	@define "context", get: -> @_context

	constructor: (options={}) ->

		defaults = Defaults.getDefaults("DeviceComponent", options)

		# If we have defaults for DeviceView, we are likely using an older version of
		# Framer Studio. It's best to default to those then for now.
		if Framer.Defaults.hasOwnProperty("DeviceView")
			defaults = _.extend(defaults, Framer.Defaults.DeviceView)

		@_setup()

		@animationOptions = defaults.animationOptions
		@deviceType = defaults.deviceType

		_.extend(@, _.defaults(options, defaults))

		@Type =
			Tablet: "tablet"
			Phone: "phone"
			Computer: "computer"

	_setup: ->

		if @_setupDone
			return

		@_setupDone = true

		@background = new Layer
		@background.clip = true
		@background.backgroundColor = "transparent"
		@background.classList.add("DeviceBackground")

		@hands    = new Layer
		@handsImageLayer = new Layer parent: @hands
		@phone    = new Layer parent: @hands
		@screen   = new Layer parent: @phone
		@viewport = new Layer parent: @screen
		@content  = new Layer parent: @viewport

		@hands.backgroundColor = "transparent"
		@hands._alwaysUseImageCache = true
		@handsImageLayer.backgroundColor = "transparent"

		@phone.backgroundColor = "transparent"
		@phone.classList.add("DevicePhone")

		@screen.classList.add("DeviceScreen")
		@screen.clip = true

		@viewport.backgroundColor = "transparent"
		@viewport.classList.add("DeviceComponentPort")

		@content.backgroundColor = "transparent"
		@content.classList.add("DeviceContent")

		@content.originX = 0
		@content.originY = 0

		Framer.CurrentContext.domEventManager.wrap(window).addEventListener("resize", @_update) unless Utils.isMobile()
		Framer.CurrentContext.domEventManager.wrap(window).addEventListener("resize", @_orientationChange) if Utils.isMobile()

		# This avoids rubber banding on mobile
		for layer in [@background, @phone, @viewport, @content, @screen]
			layer.on "touchmove", (event) -> event.preventDefault()

		@_context = new Framer.Context(parent: @content, name: "DeviceScreen")
		@_context.perspective = 1200
		@_context.device = @

	_update: =>

		# Todo: pixel align at zoom level 1, 0.5

		contentScaleFactor = @contentScale
		contentScaleFactor = 1 if contentScaleFactor > 1

		if @_shouldRenderFullScreen()

			width = window.innerWidth / contentScaleFactor
			height = window.innerHeight / contentScaleFactor

			for layer in [@background, @hands, @phone, @viewport, @content, @screen]
				layer.x = layer.y = 0
				layer.width = width
				layer.height = height
				layer.scale = 1

			@content.scale = contentScaleFactor

		else
			backgroundOverlap = 100

			@background.x = 0 - backgroundOverlap
			@background.y = 0 - backgroundOverlap
			@background.width  = window.innerWidth  + (2 * backgroundOverlap)
			@background.height = window.innerHeight + (2 * backgroundOverlap)

			@_updateDeviceImage()
			@hands.scale = @_calculatePhoneScale()
			@hands.center()
			@phone.center()

			[width, height] = @_getOrientationDimensions(
				@_device.screenWidth / contentScaleFactor,
				@_device.screenHeight / contentScaleFactor)

			@screen.width  = @viewport.width = @_device.screenWidth
			@screen.height = @viewport.height = @_device.screenHeight

			@content.width  = width
			@content.height = height
			@screen.center()

			@setHand(@selectedHand) if @selectedHand and @_orientation is 0

	_shouldRenderFullScreen: ->

		if not @_device
			return true

		if @fullScreen is true
			return true

		if @deviceType is "fullscreen"
			return true

		if Utils.isInsideIframe()
			return false

		if Utils.deviceType() is "phone" and Utils.deviceType() is @_device.deviceType
			return true

		if Utils.deviceType() is "tablet" and Utils.deviceType() is @_device.deviceType
			return true

		if Utils.deviceType() is "phone" and @_device.deviceType is "tablet"
			return true

		if @_device.screenWidth is Canvas.width and @_device.screenHeight is Canvas.height
			return true

		return false

	setupContext: ->
		# Sets this device up as the default context so everything renders
		# into the device screen
		Framer.CurrentContext = @_context

	###########################################################################
	# FULLSCREEN

	@define "fullScreen",
		get: ->
			@_fullScreen
		set: (fullScreen) ->
			@_setFullScreen(fullScreen)

	_setFullScreen: (fullScreen) ->

		if @_deviceType is "fullscreen"
			return

		if not _.isBoolean(fullScreen)
			return

		if fullScreen is @_fullScreen
			return

		@_fullScreen = fullScreen

		if fullScreen is true
			@phone.image = ""
			@hands.image = ""
		else
			@_updateDeviceImage()

		@_update()
		@emit("change:fullScreen")

	@define "screenSize",
		get: ->

			if @_shouldRenderFullScreen()
				return Canvas.size

			if @isLandscape
				return size =
					width: @_device.screenHeight
					height: @_device.screenWidth
			else
				return size =
					width: @_device.screenWidth
					height: @_device.screenHeight

	###########################################################################
	# DEVICE TYPE

	customize: (deviceProps) =>
		Devices.custom = _.defaults deviceProps, Devices.custom
		@deviceType = "custom"

	@define "deviceType",
		get: ->
			@_deviceType
		set: (deviceType) ->

			if deviceType is @_deviceType and deviceType isnt "custom"
				return

			device = null

			if _.isString(deviceType)
				lDevicetype = deviceType.toLowerCase()
				for key in _.keys(Devices)
					lKey = key.toLowerCase()
					device = Devices[key] if lDevicetype is lKey

			if not device
				throw Error "No device named #{deviceType}. Options are: #{_.keys Devices}"

			if @_device is device
				return

			# If we switch from fullscreen to a device, we should zoom to fit
			shouldZoomToFit = @_deviceType is "fullscreen"

			@screen.backgroundColor = "black"
			@screen.backgroundColor = device.backgroundColor if device.backgroundColor?

			if device.deviceType is "computer"
				Utils.domComplete ->
					document.body.style.cursor = "auto"

			@_device = _.clone(device)
			@_deviceType = deviceType
			@fullscreen = false
			@_updateDeviceImage()
			@_update()
			@emit("change:deviceType")

			@viewport.point = @_viewportOrientationOffset()

			if shouldZoomToFit
				@deviceScale = "fit"

	_updateDeviceImage: =>

		if /PhantomJS/.test(navigator.userAgent)
			return

		if @_shouldRenderFullScreen()
			@phone.image  = ""
			@hands.image  = ""
		else if not @_deviceImageUrl(@_deviceImageName())
			@phone.image  = ""
		else
			@phone._alwaysUseImageCache = true
			@phone.image  = @_deviceImageUrl(@_deviceImageName())
			@phone.width  = @_device.deviceImageWidth
			@phone.height = @_device.deviceImageHeight
			@hands.width  = @phone.width
			@hands.height = @phone.height

	_deviceImageName: ->
		if @_device.hasOwnProperty("deviceImage")
			return @_device.deviceImage
		return "#{@_deviceType}.png"

	_deviceImageUrl: (name) ->

		return null unless name

		# If the image is externally hosted, we'd like to use that
		if _.startsWith(name, "http://") or _.startsWith(name, "https://")
			return name

		# If this device is added by the user we use the name as it is
		if @_deviceType not in BuiltInDevices or @_deviceType is "custom"
			return name

		# We want to get these image from our public resources server
		resourceUrl = "//resources.framerjs.com/static/DeviceResources"

		# If we are running a local copy of Framer from the drive, get the resource online
		if Utils.isFileUrl(window.location.href)
			resourceUrl = "http:#{resourceUrl}"

		# If we're running Framer Studio and have local files, we'd like to use those.
		# For now we always use jp2 inside framer stusio
		if Utils.isFramerStudio() and window.FramerStudioInfo
			if @_device.minStudioVersion and Utils.framerStudioVersion() >= @_device.minStudioVersion or not @_device.minStudioVersion
				if @_device.maxStudioVersion and Utils.framerStudioVersion() <= @_device.maxStudioVersion or not @_device.maxStudioVersion
					resourceUrl = window.FramerStudioInfo.deviceImagesUrl
					return "#{resourceUrl}/#{name.replace(".png", ".jp2")}"

		# We'd like to use jp2/webp if possible, or check if we don't for this specific device
		if @_device.deviceImageCompression is true
			if Utils.isWebPSupported()
				return "#{resourceUrl}/#{name.replace(".png", ".webp")}"
			if Utils.isJP2Supported()
				return "#{resourceUrl}/#{name.replace(".png", ".jp2")}"

		return "#{resourceUrl}/#{name}"

	###########################################################################
	# DEVICE ZOOM

	@define "deviceScale",
		get: ->
			if @_shouldRenderFullScreen()
				return 1
			return @_deviceScale or 1
		set: (deviceScale) -> @setDeviceScale(deviceScale, false)

	setDeviceScale: (deviceScale, animate=false) ->

		if deviceScale is "fit" or deviceScale < 0
			deviceScale = "fit"
		else
			deviceScale = parseFloat(deviceScale)

		if deviceScale is @_deviceScale
			return

		@_deviceScale = deviceScale

		if @_shouldRenderFullScreen()
			return

		if deviceScale is "fit"
			phoneScale = @_calculatePhoneScale()
		else
			phoneScale = deviceScale

		@hands.animateStop()

		if animate
			@hands.animate _.extend @animationOptions,
				properties: {scale: phoneScale}
		else
			@hands.scale = phoneScale
			@hands.center()

		@emit("change:deviceScale")


	_calculatePhoneScale: ->

		# Calculates a phone scale that fits the screen unless a fixed value is set

		[width, height] = @_getOrientationDimensions(@phone.width, @phone.height)

		paddingOffset = @_device?.paddingOffset or 0

		phoneScale = _.min([
			(window.innerWidth  - ((@padding + paddingOffset) * 2)) / width,
			(window.innerHeight - ((@padding + paddingOffset) * 2)) / height
		])

		# Never scale the phone beyond 100%
		phoneScale = 1 if phoneScale > 1

		@emit("change:phoneScale", phoneScale)

		if @_deviceScale and @_deviceScale isnt "fit"
			return @_deviceScale

		return phoneScale

	###########################################################################
	# CONTENT SCALE

	@define "contentScale",
		get: -> @_contentScale or 1
		set: (contentScale) -> @setContentScale(contentScale, false)

	setContentScale: (contentScale, animate=false) ->

		contentScale = parseFloat(contentScale)

		if contentScale <= 0
			return

		if contentScale is @_contentScale
			return

		@_contentScale = contentScale

		if animate
			@content.animate _.extend @animationOptions,
				properties: {scale: @_contentScale}
		else
			@content.scale = @_contentScale

		@_update()

		@emit("change:contentScale")


	###########################################################################
	# PHONE ORIENTATION

	@define "orientation",
		get: ->
			return window.orientation if Utils.isMobile()
			return @_orientation or 0

		set: (orientation) -> @setOrientation(orientation, false)

	setOrientation: (orientation, animate=false) ->

		orientation *= -1 if Utils.framerStudioVersion() is oldDeviceMaxVersion

		if orientation is "portrait"
			orientation = 0

		if orientation is "landscape"
			orientation = 90

		if @_shouldRenderFullScreen()
			return

		orientation = parseInt(orientation)

		if orientation not in [0, 90, -90]
			return

		if orientation is @_orientation
			return

		@_orientation = orientation

		# Calculate properties for the phone
		phoneProperties =
			rotationZ: -@_orientation
			scale: @_calculatePhoneScale()

		contentProperties = @_viewportOrientationOffset()

		@hands.animateStop()
		@viewport.animateStop()

		if animate
			animation = @hands.animate _.extend @animationOptions,
				properties: phoneProperties
			@viewport.animate _.extend @animationOptions,
				properties: contentProperties

			animation.on Events.AnimationEnd, =>
				@_update()

		else
			@hands.props = phoneProperties
			@viewport.props = contentProperties
			@_update()

		@handsImageLayer.image = "" if @_orientation isnt 0

		@emit("change:orientation", @_orientation)

	_viewportOrientationOffset: =>

		[width, height] = @_getOrientationDimensions(@_device.screenWidth, @_device.screenHeight)

		@content.width = width
		@content.height = height

		offset = (@screen.width - width) / 2
		offset *= -1 if @_orientation is -90

		[x, y] = [0, 0]

		if @isLandscape
			x = offset
			y = offset

		return contentProperties =
			rotationZ: @_orientation
			x: x
			y: y

	_orientationChange: =>
		@_orientation = window.orientation
		@_update()
		@emit("change:orientation", window.orientation)

	@define "isPortrait", get: -> Math.abs(@orientation) % 180 is 0
	@define "isLandscape", get: -> not @isPortrait

	@define "orientationName",
		get: ->
			return "portrait" if @isPortrait
			return "landscape" if @isLandscape
		set: (orientationName) -> @setOrientation(orientationName, false)

	rotateLeft: (animate=true) ->
		return if @orientation is 90
		@setOrientation(@orientation + 90, animate)

	rotateRight: (animate=true) ->
		return if @orientation is -90
		@setOrientation(@orientation - 90, animate)

	_getOrientationDimensions: (width, height) ->
		if @isLandscape then [height, width] else [width, height]

	###########################################################################
	# HANDS

	handSwitchingSupported: ->
		return @_device.hands isnt undefined

	nextHand: ->
		return if @hands.rotationZ isnt 0
		if @handSwitchingSupported()
			hands = _.keys(@_device.hands)
			if hands.length > 0
				nextHandIndex = hands.indexOf(@selectedHand) + 1
				nextHand = ""
				nextHand = hands[nextHandIndex] if nextHandIndex < hands.length
				hand = @setHand(nextHand)
				@_update()
				return hand
		return false

	setHand: (hand) ->
		@selectedHand = hand
		return @handsImageLayer.image = "" if not hand or not @handSwitchingSupported()

		handData = @_device.hands[hand]
		if handData
			@hands.width = handData.width
			@hands.height = handData.height
			@hands.center()
			@phone.center()
			@handsImageLayer.size = @hands.size
			@handsImageLayer.y = 0
			@handsImageLayer.y = handData.offset if handData.offset
			@handsImageLayer.image = @handImageUrl(hand)
			return hand

	handImageUrl: (hand) ->

		# We want to get these image from our public resources server
		resourceUrl = "//resources.framerjs.com/static/DeviceResources"

		# If we are running a local copy of Framer from the drive, get the resource online
		if Utils.isFileUrl(window.location.href)
			resourceUrl = "http://#{resourceUrl}"

		# If we're running Framer Studio and have local files, we'd like to use those
		if Utils.isFramerStudio() and window.FramerStudioInfo and Utils.framerStudioVersion() >= newDeviceMinVersion
			resourceUrl = window.FramerStudioInfo.deviceImagesUrl
			return "#{resourceUrl}/#{hand}.png"

		if Utils.isWebPSupported()
			return "#{resourceUrl}/#{hand}.webp"
		if Utils.isJP2Supported()
			return "#{resourceUrl}/#{hand}.jp2"

		return "#{resourceUrl}/#{hand}.png"

	toInspect: ->
		return "<Device '#{@deviceType}' #{@screenSize.width}x#{@screenSize.height}>"


###########################################################################
# DEVICE CONFIGURATIONS

googlePixelReleaseVersion = 75
desktopReleaseVersion = 70
newDeviceMinVersion = 53
oldDeviceMaxVersion = 52

iPadAir2BaseDevice =
	deviceImageWidth: 1856
	deviceImageHeight: 2608
	deviceImageCompression: true
	screenWidth: 1536
	screenHeight: 2048
	deviceType: "tablet"
	minStudioVersion: newDeviceMinVersion

iPadMini4BaseDevice =
	deviceImageWidth: 1936
	deviceImageHeight: 2688
	deviceImageCompression: true
	screenWidth: 1536
	screenHeight: 2048
	deviceType: "tablet"
	minStudioVersion: newDeviceMinVersion

iPadProBaseDevice =
	deviceImageWidth: 2448
	deviceImageHeight: 3432
	deviceImageCompression: true
	screenWidth: 2048
	screenHeight: 2732
	deviceType: "tablet"
	minStudioVersion: newDeviceMinVersion

iPhone7BaseDevice =
	deviceImageWidth: 874
	deviceImageHeight: 1792
	deviceImageCompression: true
	screenWidth: 750
	screenHeight: 1334
	deviceType: "phone"
	minStudioVersion: 71
	hands:
		"iphone-hands-2":
			width: 2400
			height: 3740
		"iphone-hands-1":
			width: 2400
			height: 3740

iPhone7PlusBaseDevice =
	deviceImageWidth: 1452
	deviceImageHeight: 2968
	deviceImageCompression: true
	screenWidth: 1242
	screenHeight: 2208
	deviceType: "phone"
	minStudioVersion: 71
	hands:
		"iphone-hands-2":
			width: 3987
			height: 6212
		"iphone-hands-1":
			width: 3987
			height: 6212

iPhone6BaseDevice =
	deviceImageWidth: 874
	deviceImageHeight: 1792
	deviceImageCompression: true
	screenWidth: 750
	screenHeight: 1334
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 2400
			height: 3740
		"iphone-hands-1":
			width: 2400
			height: 3740

iPhone6PlusBaseDevice =
	deviceImageWidth: 1452
	deviceImageHeight: 2968
	deviceImageCompression: true
	screenWidth: 1242
	screenHeight: 2208
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 3987
			height: 6212
		"iphone-hands-1":
			width: 3987
			height: 6212

iPhone5BaseDevice =
	deviceImageWidth: 768
	deviceImageHeight: 1612
	deviceImageCompression: true
	screenWidth: 640
	screenHeight: 1136
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 2098
			height: 3269
			offset: 19
		"iphone-hands-1":
			width: 2098
			height: 3269
			offset: 19

iPhone5CBaseDevice =
	deviceImageWidth: 776
	deviceImageHeight: 1620
	deviceImageCompression: true
	screenWidth: 640
	screenHeight: 1136
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 2098
			height: 3269
			offset: 28
		"iphone-hands-1":
			width: 2098
			height: 3269
			offset: 28

Nexus4BaseDevice =
	deviceImageWidth: 860
	deviceImageHeight: 1668
	deviceImageCompression: true
	screenWidth: 768
	screenHeight: 1280
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 2362
			height: 3681
			offset: -52
		"iphone-hands-1":
			width: 2362
			height: 3681
			offset: -52

Nexus5BaseDevice =
	deviceImageWidth: 1204
	deviceImageHeight: 2432
	deviceImageCompression: true
	screenWidth: 1080
	screenHeight: 1920
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 3292
			height: 5130
			offset: 8
		"iphone-hands-1":
			width: 3292
			height: 5130
			offset: 8

Nexus6BaseDevice =
	deviceImageWidth: 1576
	deviceImageHeight: 3220
	deviceImageCompression: true
	screenWidth: 1440
	screenHeight: 2560
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 4304
			height: 6707
			offset: 8
		"iphone-hands-1":
			width: 4304
			height: 6707
			offset: 8

PixelBaseDevice =
	deviceImageWidth: 1224
	deviceImageHeight: 2492
	deviceImageCompression: true
	screenWidth: 1080
	screenHeight: 1920
	deviceType: "phone"
	minStudioVersion: googlePixelReleaseVersion
	hands:
		"iphone-hands-2":
			width: 3344
			height: 5211
			offset: 23
		"iphone-hands-1":
			width: 3344
			height: 5211
			offset: 23

Nexus9BaseDevice =
	deviceImageWidth: 1896
	deviceImageHeight: 2648
	deviceImageCompression: true
	screenWidth: 1536
	screenHeight: 2048
	deviceType: "tablet"
	minStudioVersion: newDeviceMinVersion

HTCa9BaseDevice =
	deviceImageWidth: 1252
	deviceImageHeight: 2592
	deviceImageCompression: true
	screenWidth: 1080
	screenHeight: 1920
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 3436
			height: 5354
			offset: 36
		"iphone-hands-1":
			width: 3436
			height: 5354
			offset: 36

HTCm8BaseDevice =
	deviceImageWidth: 1232
	deviceImageHeight: 2572
	deviceImageCompression: true
	screenWidth: 1080
	screenHeight: 1920
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 3436
			height: 5354
			offset: 12
		"iphone-hands-1":
			width: 3436
			height: 5354
			offset: 12

MSFTLumia950BaseDevice =
	deviceImageWidth: 1660
	deviceImageHeight: 3292
	deviceImageCompression: true
	screenWidth: 1440
	screenHeight: 2560
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 4494
			height: 7003
			offset: -84
		"iphone-hands-1":
			width: 4494
			height: 7003
			offset: -84

SamsungGalaxyNote5BaseDevice =
	deviceImageWidth: 1572
	deviceImageHeight: 3140
	deviceImageCompression: true
	screenWidth: 1440
	screenHeight: 2560
	deviceType: "phone"
	minStudioVersion: newDeviceMinVersion
	hands:
		"iphone-hands-2":
			width: 4279
			height: 6668
			offset: -24
		"iphone-hands-1":
			width: 4279
			height: 6668
			offset: -84

AppleWatchSeries242Device =
	deviceImageWidth: 512
	deviceImageHeight: 990
	deviceImageCompression: true
	screenWidth: 312
	screenHeight: 390
	minStudioVersion: 71

AppleWatchSeries238Device =
	deviceImageWidth: 472
	deviceImageHeight: 772
	deviceImageCompression: true
	screenWidth: 272
	screenHeight: 340
	minStudioVersion: 71

AppleWatch42Device =
	deviceImageWidth: 512
	deviceImageHeight: 990
	deviceImageCompression: true
	screenWidth: 312
	screenHeight: 390
	minStudioVersion: newDeviceMinVersion

AppleWatch38Device =
	deviceImageWidth: 472
	deviceImageHeight: 772
	deviceImageCompression: true
	screenWidth: 272
	screenHeight: 340
	minStudioVersion: newDeviceMinVersion

AppleWatch38BlackLeatherDevice =
	deviceImageWidth: 472
	deviceImageHeight: 796
	deviceImageCompression: true
	screenWidth: 272
	screenHeight: 340
	minStudioVersion: newDeviceMinVersion

AppleMacBook =
	deviceImageWidth: 3084
	deviceImageHeight: 1860
	deviceImageCompression: true
	screenWidth: 2304
	screenHeight: 1440
	deviceType: "computer"
	minStudioVersion: desktopReleaseVersion

AppleMacBookAir =
	deviceImageWidth: 2000
	deviceImageHeight: 1220
	deviceImageCompression: true
	screenWidth: 1440
	screenHeight: 900
	deviceType: "computer"
	minStudioVersion: desktopReleaseVersion

AppleMacBookPro =
	deviceImageWidth: 3820
	deviceImageHeight: 2320
	deviceImageCompression: true
	screenWidth: 2880
	screenHeight: 1800
	deviceType: "computer"
	minStudioVersion: desktopReleaseVersion

AppleIMac =
	deviceImageWidth: 2800
	deviceImageHeight: 2940
	deviceImageCompression: true
	screenWidth: 2560
	screenHeight: 1440
	deviceType: "computer"
	minStudioVersion: desktopReleaseVersion

DellXPS =
	deviceImageWidth: 5200
	deviceImageHeight: 3040
	deviceImageCompression: true
	screenWidth: 3840
	screenHeight: 2160
	deviceType: "computer"
	minStudioVersion: desktopReleaseVersion

SonyW85OC =
	deviceImageWidth: 1320
	deviceImageHeight: 860
	deviceImageCompression: true
	screenWidth: 1280
	screenHeight: 720
	minStudioVersion: desktopReleaseVersion

###########################################################################
# OLD DEVICE CONFIGURATIONS

old_iPhone6BaseDevice =
	deviceImageWidth: 870
	deviceImageHeight: 1738
	deviceImageCompression: true
	screenWidth: 750
	screenHeight: 1334
	deviceType: "phone"
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone6BaseDeviceHand = _.extend {}, old_iPhone6BaseDevice,
	deviceImageWidth: 1988
	deviceImageHeight: 2368
	deviceImageCompression: true
	paddingOffset: -150
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone6PlusBaseDevice =
	deviceImageWidth: 1460
	deviceImageHeight: 2900
	deviceImageCompression: true
	screenWidth: 1242
	screenHeight: 2208
	deviceType: "phone"
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone6PlusBaseDeviceHand = _.extend {}, old_iPhone6PlusBaseDevice,
	deviceImageWidth: 3128
	deviceImageHeight: 3487
	deviceImageCompression: true
	paddingOffset: -150
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone5BaseDevice =
	deviceImageWidth: 780
	deviceImageHeight: 1608
	deviceImageCompression: true
	screenWidth: 640
	screenHeight: 1136
	deviceType: "phone"
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone5BaseDeviceHand = _.extend {}, old_iPhone5BaseDevice,
	deviceImageWidth: 1884
	deviceImageHeight: 2234
	deviceImageCompression: true
	paddingOffset: -200
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone5CBaseDevice =
	deviceImageWidth: 776
	deviceImageHeight: 1612
	deviceImageCompression: true
	screenWidth: 640
	screenHeight: 1136
	deviceType: "phone"
	maxStudioVersion: oldDeviceMaxVersion

old_iPhone5CBaseDeviceHand = _.extend {}, old_iPhone5CBaseDevice,
	deviceImageWidth: 1894
	deviceImageHeight: 2244
	deviceImageCompression: true
	paddingOffset: -200
	maxStudioVersion: oldDeviceMaxVersion

old_iPadMiniBaseDevice =
	deviceImageWidth: 872
	deviceImageHeight: 1292
	deviceImageCompression: true
	screenWidth: 768
	screenHeight: 1024
	deviceType: "tablet"
	maxStudioVersion: oldDeviceMaxVersion

old_iPadMiniBaseDeviceHand = _.extend {}, old_iPadMiniBaseDevice,
	deviceImageWidth: 1380
	deviceImageHeight: 2072
	deviceImageCompression: true
	paddingOffset: -120
	maxStudioVersion: oldDeviceMaxVersion

old_iPadAirBaseDevice =
	deviceImageWidth: 1769
	deviceImageHeight: 2509
	deviceImageCompression: true
	screenWidth: 1536
	screenHeight: 2048
	deviceType: "tablet"
	maxStudioVersion: oldDeviceMaxVersion

old_iPadAirBaseDeviceHand = _.extend {}, old_iPadAirBaseDevice,
	deviceImageWidth: 4744
	deviceImageHeight: 4101
	deviceImageCompression: true
	paddingOffset: -120
	maxStudioVersion: oldDeviceMaxVersion

old_Nexus5BaseDevice =
	deviceImageWidth: 1208
	deviceImageHeight: 2440
	deviceImageCompression: true
	screenWidth: 1080
	screenHeight: 1920
	deviceType: "phone"
	maxStudioVersion: oldDeviceMaxVersion

old_Nexus5BaseDeviceHand = _.extend {}, old_Nexus5BaseDevice, # 2692 × 2996
	deviceImageWidth: 2692
	deviceImageHeight: 2996
	deviceImageCompression: true
	paddingOffset: -120
	maxStudioVersion: oldDeviceMaxVersion

old_Nexus9BaseDevice =
	deviceImageWidth: 1733
	deviceImageHeight: 2575
	deviceImageCompression: true
	screenWidth: 1536
	screenHeight: 2048
	deviceType: "tablet"
	maxStudioVersion: oldDeviceMaxVersion

old_AppleWatch42Device =
	deviceImageWidth: 552
	deviceImageHeight: 938
	deviceImageCompression: true
	screenWidth: 312
	screenHeight: 390
	maxStudioVersion: oldDeviceMaxVersion

old_AppleWatch38Device =
	deviceImageWidth: 508
	deviceImageHeight: 900
	deviceImageCompression: true
	screenWidth: 272
	screenHeight: 340
	maxStudioVersion: oldDeviceMaxVersion

Devices =

	"fullscreen":
		name: "Fullscreen"
		deviceType: "desktop"
		backgroundColor: "transparent"

	"custom":
		name: "Custom"
		deviceImageWidth: 874
		deviceImageHeight: 1792
		screenWidth: 750
		screenHeight: 1334
		deviceType: "phone"

	# iPad Air
	"apple-ipad-air-2-silver": _.clone(iPadAir2BaseDevice)
	"apple-ipad-air-2-gold": _.clone(iPadAir2BaseDevice)
	"apple-ipad-air-2-space-gray": _.clone(iPadAir2BaseDevice)

	# iPad Mini
	"apple-ipad-mini-4-silver": _.clone(iPadMini4BaseDevice)
	"apple-ipad-mini-4-gold": _.clone(iPadMini4BaseDevice)
	"apple-ipad-mini-4-space-gray": _.clone(iPadMini4BaseDevice)

	# iPad Pro
	"apple-ipad-pro-silver": _.clone(iPadProBaseDevice)
	"apple-ipad-pro-gold": _.clone(iPadProBaseDevice)
	"apple-ipad-pro-space-gray": _.clone(iPadProBaseDevice)

	# iPhone 7
	"apple-iphone-7-gold": _.clone(iPhone7BaseDevice)
	"apple-iphone-7-rose-gold": _.clone(iPhone7BaseDevice)
	"apple-iphone-7-silver": _.clone(iPhone7BaseDevice)
	"apple-iphone-7-black": _.clone(iPhone7BaseDevice)
	"apple-iphone-7-jet-black": _.clone(iPhone7BaseDevice)

	# iPhone 7 Plus
	"apple-iphone-7-plus-gold": _.clone(iPhone7PlusBaseDevice)
	"apple-iphone-7-plus-rose-gold": _.clone(iPhone7PlusBaseDevice)
	"apple-iphone-7-plus-silver": _.clone(iPhone7PlusBaseDevice)
	"apple-iphone-7-plus-black": _.clone(iPhone7PlusBaseDevice)
	"apple-iphone-7-plus-jet-black": _.clone(iPhone7PlusBaseDevice)

	# iPhone 6s
	"apple-iphone-6s-gold": _.clone(iPhone6BaseDevice)
	"apple-iphone-6s-rose-gold": _.clone(iPhone6BaseDevice)
	"apple-iphone-6s-silver": _.clone(iPhone6BaseDevice)
	"apple-iphone-6s-space-gray": _.clone(iPhone6BaseDevice)

	# iPhone 6s Plus
	"apple-iphone-6s-plus-gold": _.clone(iPhone6PlusBaseDevice)
	"apple-iphone-6s-plus-rose-gold": _.clone(iPhone6PlusBaseDevice)
	"apple-iphone-6s-plus-silver": _.clone(iPhone6PlusBaseDevice)
	"apple-iphone-6s-plus-space-gray": _.clone(iPhone6PlusBaseDevice)

	# iPhone 5S
	"apple-iphone-5s-gold": _.clone(iPhone5BaseDevice)
	"apple-iphone-5s-silver": _.clone(iPhone5BaseDevice)
	"apple-iphone-5s-space-gray": _.clone(iPhone5BaseDevice)

	# iPhone 5C
	"apple-iphone-5c-blue": _.clone(iPhone5CBaseDevice)
	"apple-iphone-5c-green": _.clone(iPhone5CBaseDevice)
	"apple-iphone-5c-red": _.clone(iPhone5CBaseDevice)
	"apple-iphone-5c-white": _.clone(iPhone5CBaseDevice)
	"apple-iphone-5c-yellow": _.clone(iPhone5CBaseDevice)

	# Apple Watch Series 2 38mm
	"apple-watch-series-2-38mm-black-steel-black": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-edition": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-rose-gold-aluminum-midnight-blue": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-cocoa": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-concrete": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-ocean-blue": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-red": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-turquoise": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-white": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-silver-aluminum-yellow": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-space-gray-aluminum-black": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-sport-aluminum-walnut": _.clone(AppleWatchSeries238Device)
	"apple-watch-series-2-38mm-steel-white": _.clone(AppleWatchSeries238Device)

	# Apple Watch Series 2 42mm
	"apple-watch-series-2-42mm-edition": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-gold-aluminum-cocoa": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-rose-gold-aluminum-midnight-blue": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-concrete": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-green": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-light-pink": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-ocean-blue": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-pink-sand": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-red": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-turquoise": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-white": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-silver-aluminum-yellow": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-space-black-steel-black": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-space-gray-aluminum-black": _.clone(AppleWatchSeries242Device)
	"apple-watch-series-2-42mm-steel-white": _.clone(AppleWatchSeries242Device)

	# Apple Watch Nike+ 38mm
	"apple-watch-nike-plus-38mm-silver-aluminum-flat-silver-volt": _.clone(AppleWatchSeries238Device)
	"apple-watch-nike-plus-38mm-silver-aluminum-flat-silver-white": _.clone(AppleWatchSeries238Device)
	"apple-watch-nike-plus-38mm-space-gray-aluminum-black-cool-gray": _.clone(AppleWatchSeries238Device)
	"apple-watch-nike-plus-38mm-space-gray-aluminum-black-volt": _.clone(AppleWatchSeries238Device)

	# Apple Watch Nike+ 42mm
	"apple-watch-nike-plus-42mm-silver-aluminum-flat-silver-volt": _.clone(AppleWatchSeries242Device)
	"apple-watch-nike-plus-42mm-silver-aluminum-flat-silver-white": _.clone(AppleWatchSeries242Device)
	"apple-watch-nike-plus-42mm-space-gray-aluminum-black-cool-gray": _.clone(AppleWatchSeries242Device)
	"apple-watch-nike-plus-42mm-space-gray-aluminum-black-volt": _.clone(AppleWatchSeries242Device)

	# Apple Watch 38mm

	"apple-watch-38mm-gold-black-leather-closed": _.clone(AppleWatch38BlackLeatherDevice)
	"apple-watch-38mm-rose-gold-black-leather-closed": _.clone(AppleWatch38BlackLeatherDevice)
	"apple-watch-38mm-stainless-steel-black-leather-closed": _.clone(AppleWatch38BlackLeatherDevice)

	"apple-watch-38mm-black-steel-black-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-gold-midnight-blue-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-rose-gold-lavender-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-blue-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-fog-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-green-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-red-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-walnut-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-white-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-gold-antique-white-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-aluminum-rose-gold-stone-closed": _.clone(AppleWatch38Device)
	"apple-watch-38mm-sport-space-gray-black-closed": _.clone(AppleWatch38Device)

	# Apple Watch 42mm
	"apple-watch-42mm-black-steel-black-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-gold-black-leather-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-gold-midnight-blue-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-rose-gold-black-leather-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-rose-gold-lavender-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-blue-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-fog-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-green-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-red-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-walnut-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-white-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-gold-antique-white-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-aluminum-rose-gold-stone-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-sport-space-gray-black-closed": _.clone(AppleWatch42Device)
	"apple-watch-42mm-stainless-steel-black-leather-closed": _.clone(AppleWatch42Device)

	# NEXUS
	"google-nexus-4": _.clone(Nexus4BaseDevice)
	"google-nexus-5x": _.clone(Nexus5BaseDevice)
	"google-nexus-6p": _.clone(Nexus6BaseDevice)
	"google-nexus-9": _.clone(Nexus9BaseDevice)

	# Pixel
	"google-pixel-quite-black": _.clone(PixelBaseDevice)
	"google-pixel-really-blue": _.clone(PixelBaseDevice)
	"google-pixel-very-silver": _.clone(PixelBaseDevice)

	# HTC ONE A9
	"htc-one-a9-black": _.clone(HTCa9BaseDevice)
	"htc-one-a9-white": _.clone(HTCa9BaseDevice)

	# HTC ONE M8
	"htc-one-m8-black": _.clone(HTCm8BaseDevice)
	"htc-one-m8-gold": _.clone(HTCm8BaseDevice)
	"htc-one-m8-silver": _.clone(HTCm8BaseDevice)

	# MICROSOFT LUMIA 950
	"microsoft-lumia-950-black": _.clone(MSFTLumia950BaseDevice)
	"microsoft-lumia-950-white": _.clone(MSFTLumia950BaseDevice)

	# SAMSUNG NOTE 5
	"samsung-galaxy-note-5-black": _.clone(SamsungGalaxyNote5BaseDevice)
	"samsung-galaxy-note-5-gold": _.clone(SamsungGalaxyNote5BaseDevice)
	"samsung-galaxy-note-5-pink": _.clone(SamsungGalaxyNote5BaseDevice)
	"samsung-galaxy-note-5-silver-titanium": _.clone(SamsungGalaxyNote5BaseDevice)
	"samsung-galaxy-note-5-white": _.clone(SamsungGalaxyNote5BaseDevice)

	# Notebooks
	"apple-macbook": _.clone(AppleMacBook)
	"apple-macbook-air": _.clone(AppleMacBookAir)
	"apple-macbook-pro": _.clone(AppleMacBookPro)
	"dell-xps": _.clone(DellXPS)

	# Desktops
	"apple-imac": _.clone(AppleIMac)

	# TV
	"sony-w85Oc": _.clone(SonyW85OC)

	# OLD DEVICES
	"desktop-safari-1024-600":
		deviceType: "browser"
		name: "Desktop Safari 1024 x 600"
		screenWidth: 1024
		screenHeight: 600
		deviceImageWidth: 1136
		deviceImageHeight: 760
		deviceImageCompression: true
		backgroundColor: "white"
	"desktop-safari-1280-800":
		deviceType: "browser"
		name: "Desktop Safari 1280 x 800"
		screenWidth: 1280
		screenHeight: 800
		deviceImageWidth: 1392
		deviceImageHeight: 960
		deviceImageCompression: true
		backgroundColor: "white"
	"desktop-safari-1440-900":
		deviceType: "browser"
		name: "Desktop Safari 1440 x 900"
		screenWidth: 1440
		screenHeight: 900
		deviceImageWidth: 1552
		deviceImageHeight: 1060
		deviceImageCompression: true
		backgroundColor: "white"

	# iPhone 6
	"iphone-6-spacegray": _.clone(old_iPhone6BaseDevice)
	"iphone-6-spacegray-hand": _.clone(old_iPhone6BaseDeviceHand)
	"iphone-6-silver": _.clone(old_iPhone6BaseDevice)
	"iphone-6-silver-hand": _.clone(old_iPhone6BaseDeviceHand)
	"iphone-6-gold": _.clone(old_iPhone6BaseDevice)
	"iphone-6-gold-hand": _.clone(old_iPhone6BaseDeviceHand)

	# iPhone 6+
	"iphone-6plus-spacegray": _.clone(old_iPhone6PlusBaseDevice)
	"iphone-6plus-spacegray-hand": _.clone(old_iPhone6PlusBaseDeviceHand)
	"iphone-6plus-silver": _.clone(old_iPhone6PlusBaseDevice)
	"iphone-6plus-silver-hand": _.clone(old_iPhone6PlusBaseDeviceHand)
	"iphone-6plus-gold": _.clone(old_iPhone6PlusBaseDevice)
	"iphone-6plus-gold-hand": _.clone(old_iPhone6PlusBaseDeviceHand)

	# iPhone 5S
	"iphone-5s-spacegray": _.clone(old_iPhone5BaseDevice)
	"iphone-5s-spacegray-hand": _.clone(old_iPhone5BaseDeviceHand)
	"iphone-5s-silver": _.clone(old_iPhone5BaseDevice)
	"iphone-5s-silver-hand": _.clone(old_iPhone5BaseDeviceHand)
	"iphone-5s-gold": _.clone(old_iPhone5BaseDevice)
	"iphone-5s-gold-hand": _.clone(old_iPhone5BaseDeviceHand)

	# iPhone 5C
	"iphone-5c-green": _.clone(old_iPhone5CBaseDevice)
	"iphone-5c-green-hand": _.clone(old_iPhone5CBaseDeviceHand)
	"iphone-5c-blue": _.clone(old_iPhone5CBaseDevice)
	"iphone-5c-blue-hand": _.clone(old_iPhone5CBaseDeviceHand)
	"iphone-5c-pink": _.clone(old_iPhone5CBaseDevice)
	"iphone-5c-pink-hand": _.clone(old_iPhone5CBaseDeviceHand)
	"iphone-5c-white": _.clone(old_iPhone5CBaseDevice)
	"iphone-5c-white-hand": _.clone(old_iPhone5CBaseDeviceHand)
	"iphone-5c-yellow": _.clone(old_iPhone5CBaseDevice)
	"iphone-5c-yellow-hand": _.clone(old_iPhone5CBaseDeviceHand)

	# iPad Mini
	"ipad-mini-spacegray": _.clone(old_iPadMiniBaseDevice)
	"ipad-mini-spacegray-hand": _.clone(old_iPadMiniBaseDeviceHand)
	"ipad-mini-silver": _.clone(old_iPadMiniBaseDevice)
	"ipad-mini-silver-hand": _.clone(old_iPadMiniBaseDeviceHand)

	# iPad Air
	"ipad-air-spacegray": _.clone(old_iPadAirBaseDevice)
	"ipad-air-spacegray-hand": _.clone(old_iPadAirBaseDeviceHand)
	"ipad-air-silver": _.clone(old_iPadAirBaseDevice)
	"ipad-air-silver-hand": _.clone(old_iPadAirBaseDeviceHand)

	# Nexus 5
	"nexus-5-black": _.clone(old_Nexus5BaseDevice)
	"nexus-5-black-hand": _.clone(old_Nexus5BaseDeviceHand)

	# Nexus 9
	"nexus-9": _.clone(old_Nexus9BaseDevice)

	# Apple Watch 38mm
	"applewatchsport-38-aluminum-sportband-black": _.clone(old_AppleWatch38Device)
	"applewatchsport-38-aluminum-sportband-blue": _.clone(old_AppleWatch38Device)
	"applewatchsport-38-aluminum-sportband-green": _.clone(old_AppleWatch38Device)
	"applewatchsport-38-aluminum-sportband-pink": _.clone(old_AppleWatch38Device)
	"applewatchsport-38-aluminum-sportband-white": _.clone(old_AppleWatch38Device)
	"applewatch-38-black-bracelet": _.clone(old_AppleWatch38Device)
	"applewatch-38-steel-bracelet": _.clone(old_AppleWatch38Device)
	"applewatchedition-38-gold-buckle-blue": _.clone(old_AppleWatch38Device)
	"applewatchedition-38-gold-buckle-gray": _.clone(old_AppleWatch38Device)
	"applewatchedition-38-gold-buckle-red": _.clone(old_AppleWatch38Device)
	"applewatchedition-38-gold-sportband-black": _.clone(old_AppleWatch38Device)
	"applewatchedition-38-gold-sportband-white": _.clone(old_AppleWatch38Device)

	# Apple Watch 42mm
	"applewatchsport-42-aluminum-sportband-black": _.clone(old_AppleWatch42Device)
	"applewatchsport-42-aluminum-sportband-blue": _.clone(old_AppleWatch42Device)
	"applewatchsport-42-aluminum-sportband-green": _.clone(old_AppleWatch42Device)
	"applewatchsport-42-aluminum-sportband-pink": _.clone(old_AppleWatch42Device)
	"applewatchsport-42-aluminum-sportband-white": _.clone(old_AppleWatch42Device)
	"applewatch-42-black-bracelet": _.clone(old_AppleWatch42Device)
	"applewatch-42-steel-bracelet": _.clone(old_AppleWatch42Device)
	"applewatchedition-42-gold-buckle-blue": _.clone(old_AppleWatch42Device)
	"applewatchedition-42-gold-buckle-gray": _.clone(old_AppleWatch42Device)
	"applewatchedition-42-gold-buckle-red": _.clone(old_AppleWatch42Device)
	"applewatchedition-42-gold-sportband-black": _.clone(old_AppleWatch42Device)
	"applewatchedition-42-gold-sportband-white": _.clone(old_AppleWatch42Device)


exports.DeviceComponent.Devices = Devices

BuiltInDevices = _.keys(Devices)
