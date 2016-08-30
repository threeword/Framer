
###
# Article prototype
Screen.backgroundColor = "#fff"

article = new ScrollComponent
	size: Screen.size
	scrollHorizontal: false
	contentInset: bottom: 50

banner = new Layer
	width: Screen.width
	height: 500
	image: "images/banner.png"
	parent: article.content

title = new TextLayer
	x: 50 
	y: banner.maxY + 50
	width: Screen.width - 100
	color: "#000"
	fontSize: 80
	fontWeight: 600
	lineHeight: 1.3
	autoHeight: true
	text: "In a world with no boundaries, what will you design?"
	parent: article.content
	
body = new TextLayer
	x: 50 
	y: title.maxY + 50
	width: Screen.width - 100
	color: "#333"
	fontSize: 40
	fontWeight: 300
	lineHeight: 1.5
	autoHeight: true
	text: "Start with simple code to bring your design to life. Test it on any device, iterate as you go and share easily for feedback. Pioneer new interaction patterns or create groundbreaking animation. No limits, no constraints. Framer is the design tool of choice for today’s top designers at tech startups, Fortune 500s and design schools worldwide."
	parent: article.content
	
article.updateContent()


# Input prototype
# Import file "label"
sketch = Framer.Importer.load("imported/label@1x")


# Create the underline layer
line = new Layer 
	width: 0
	height: 6 
	backgroundColor: "#64FCDA"
	x: 216 + 410
	y: 466

# Add states
line.states.add 
	show: 
		width: 820
		x: 216
	hide: 
		width: 0
		x: 216 + 410
		
line.states.animationOptions = 
	curve: "spring(300,30,0)"

# Create title field	
title = new InputLayer 	
	x: 216
	y: 324
	width: 820
	height: 140
	backgroundColor: null
	color: "rgba(255,255,255,0.5)"
	focusColor: "#FFF"
	fontSize: 96
	
title.input.x = 0
	
# Store position
curY = title.y	

# Switch to floating label
switchLabels = ->
	title.input.value = title.input.placeholder = "Title"
	title.input.blur()
	
	titleAnim = title.animate 
		properties: 
			y: curY - 100
			color: "#64FCDA"
		curve: "spring(200,22,16)"
		
	line.states.switch("show")
	
	# Create new, actual input field
	field = new InputLayer 		
		focusColor: "#FFF"
		fontSize: 96
		width: title.width 
		height: title.height
		
	
	field.props = title.props
	field.style = title.style
	field.input.placeholder = ""	
	field.input.focus()
	
	field.input.onkeyup = ->	
		if @value is ""
			title.animate 
				properties: 
					y: curY
					color: "rgba(255,255,255,0.3)"
					
				curve: "spring(200,22,16)"
			line.states.switch("hide")
			
		else 
			titleAnim.start()
	
			line.states.animationOptions = 
				curve: "ease"
				time: 0.15
				
			line.states.switch("show")
	
# On Mobile	
if Utils.isMobile()
	title.input.onkeyup = ->
		switchLabels()
		
# On Desktop
else
	title.input.onkeydown = ->
		switchLabels()
		
# Modulate the y changes to fontSize changes
title.on "change:y", ->
	size = Utils.modulate(@y, [curY, curY - 100], [100, 40], true)
	title.input.style.fontSize = "#{size}px"
	
	
	
###




t = new TextLayer
	text: "Test"
	fontFamily: Utils.webFont("Montserrat")
	
