$ = (id) -> document.getElementById id

class Editor
	constructor: (editorId, outId, errorId, canvasAreaId) ->
		@isRunning = false
		@editor = ace.edit editorId
		@out = $ outId
		@error = $ errorId
		@gl = new MicroGL(antialias: false).init $(canvasAreaId), 512, 512
		@t = Date.now()

		@editor.getSession().setMode 'ace/mode/javascript'
		@editor.commands.addCommands [{
			name: 'execute'
			bindKey: 'Ctrl-Enter'
			exec: =>
				@convert() and @execute()
		}]

	convert: ->
		try
			@program = Gerbera.compileShader
				minify: false
				attributes:
					position: Gerbera.vec4
				uniforms:
					time: Gerbera.float
					#mouse: Gerbera.vec2
				vertex: (attr, unif) ->
					gl_Position = attr.position;
					return
				fragment: "function(uniforms, varyings){#{@editor.getValue()}}"
		catch e
			@error.textContent = e.message
			return false
		@error.textContent = ''
		@out.textContent = @program.fragment
		true

	execute: ->
		@t = Date.now()
		@gl.program @program.vertex, @program.fragment
			.bindVars
				position: [-1,-1,0,1, -1,1,0,1, 1,-1,0,1, 1,1,0,1]
		if not @isRunning
			@isRunning = true
			@update()

	update: ->
		return unless @isRunning
		@gl
			.bindVars
				time: Date.now() - @t
				#mouse: [0, 0]
			.clear()
			.draw()
		requestAnimationFrame => @update()


document.addEventListener 'DOMContentLoaded', ->
	editor = new Editor 'editor', 'converted', 'error', 'canvas'
	editor.editor.setValue '''
// JavaScript code here
function mult(a, b){
	return new vec2(
		a[0] * b[0] - a[1] * b[1],
		a[0] * b[1] + a[1] * b[0]
	);
}

var t = uniforms.time / 4e3 + 2,
	c = new vec2(
		(gl_FragCoord[0] - 250) * Math.exp(-t) + 0.375,
		(gl_FragCoord[1] - 150) * Math.exp(-t) + 0.225
	),
	z = c,
	d = 0;

for(var i = 0; i < 999; i++){
	if(float.length(z) > 2) break;
	z = vec2.add(mult(z, z), c);
	d += 0.2;
}
gl_FragColor = new vec4(
	(Math.cos(d) + 1) / 2,
	(Math.sin(d) + 1) / 2,
	log(d),
	1
);
	'''
	editor.convert() and editor.execute()
, false
