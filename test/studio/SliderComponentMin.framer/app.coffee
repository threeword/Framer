# SliderComponent
sliderA = new SliderComponent
sliderA.center()

# Values
sliderA.min = 50
sliderA.max = 150
sliderA.value = 50

# knobSize vs. size
sliderA.knobSize = 60
sliderA.knob.width = sliderA.knob.height = 40

# Visualize value
sliderA.knob.clip = false
valueLayer = new Layer
	width:60, height:72, image:"images/value.png"
	superLayer: sliderA.knob
	y: sliderA.knob.y - 70, scale: 0

valueLayer.x -= 10

# Style
valueLayer.html = sliderA.value
valueLayer.style = {
	"color" : "#fff"
	"font-size" : "28px"
	"font-family" : "Helvetica Neue"
	"font-weight" : "300"
	"line-height" : "#{valueLayer.height - 12}px"
	"text-align" : "center"
}

# Set origin to animate from bottom
valueLayer.originY = 1

# States
valueLayer.states =
	fade25:    {opacity: 0.25}
	fade50:    {opacity: 0.50}
	fade75:    {opacity: 0.75}
	nofade:    {opacity: 1}
	scaleDown: {scale: 0}
	scaleUp:   {scale: 0.8}

valueLayer.options = curve: "spring(300, 30, 0)"

# Visualize output
sliderA.knob.on Events.DragStart, ->
	valueLayer.animate "scaleUp"

# Test proper output
sliderA.on "change:value", ->
	valueLayer.html = Math.round(this.value)
	valueLayer.animate "fade25" if this.value is 0
	valueLayer.animate "fade50" if this.value >= 25
	valueLayer.animate "fade75" if this.value >= 50
	valueLayer.animate "nofade" if this.value >= 75

# Return after DragEnd
sliderA.knob.on Events.DragAnimationEnd, ->
	valueLayer.animate "scaleDown"
