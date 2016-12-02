{EventEmitter} = require "./EventEmitter"

###
top, right, bottom, left, centerX, centerY, center
###

calculateFrame = (layer, rules) ->

	val = (rule) ->
		value = rules[rule]
		value = value() if _.isFunction(value)
		return value

	def = (rule) ->
		_.isNumber(val(rule))

	if def("center")
		rules["centerX"] = val("center")
		rules["centerY"] = val("center")

	parentSize = layer.parent
	parentSize ?= Screen

	frame = layer.frame

	if def("left") and def("right")
		frame.x = val("left")
		frame.width = parentSize.width - val("left") - val("right")
	else if def("left")
		frame.x = val("left")
	else if def("right")
		frame.x = parentSize.width - frame.width - val("right")
	else if def("centerX")
		frame.x = (parentSize.width / 2) - (frame.width / 2) + val("centerX")

	if def("top") and def("bottom")
		frame.y = val("top")
		frame.height = parentSize.height - val("top") - val("bottom")
	else if def("top")
		frame.y = val("top")
	else if def("bottom")
		frame.y = parentSize.height - frame.height - val("bottom")
	else if def("centerY")
		frame.y = (parentSize.height / 2) - (frame.height / 2) + val("centerY")

	return frame


class LayerAnchor extends EventEmitter

	constructor: (@layer, rules) ->
		@updateRules(rules)

		# TODO: We need to remove ourselves when something
		# changes the frame from the outside like an animation
		# @layer.on "change:frame", =>
		# 	print "change:frame"

	updateRules: (rules) ->
		@rules = @_parseRules(rules)
		@layer.on("change:parent", @_setupListener)
		@_setNeedsUpdate()
		# @_needsUpdate = false
		@_removeListeners()
		@_setupListener()

	_setupListener: =>

		@_removeListeners()

		if @layer.parent
			@_addListener(@layer.parent, "change:frame", @_setNeedsUpdate)
		else
			@_addListener(Canvas, "resize", @_setNeedsUpdate)

	_addListener: (obj, eventName, listener) =>
		obj.on(eventName, listener)
		@_currentListeners[obj] ?= []
		@_currentListeners[obj].push(eventName)

	_removeListeners: ->
		for obj, eventName of @_currentListeners
			obj.off(eventName, @_setNeedsUpdate)
		@_currentListeners = {}

	_setNeedsUpdate: =>
		@layer.frame = calculateFrame(@layer, @rules)

	_parseRules: ->
		return Utils.parseRect(Utils.arrayFromArguments(arguments))


exports.LayerAnchor = LayerAnchor
