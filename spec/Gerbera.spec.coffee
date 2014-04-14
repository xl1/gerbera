Gerbera = require '../src/Gerbera'

describe 'Gerbera', ->
  describe 'compileShader()', ->
    it 'should compile JavaScript to GLSL shaders', ->
      result = Gerbera.compileShader
        attributes:
          position: Gerbera.vec2
        uniforms:
          size: Gerbera.vec2
        vertex: (attrs, unifs, varys) ->
          gl_Position = new vec4(attrs.position, 0, 1)
          return
        fragment: (unifs, varys) ->
          gl_FragColor = new vec4(
            vec2.div(new vec2(gl_FragCoord[0], gl_FragCoord[1]), unifs.size)
            1, 1
          )
          return
      expect(result.vertex).toBe '
        precision mediump float;\
        attribute vec2 position;\
        uniform vec2 size;\
        void main(){gl_Position=vec4(position,0.,1.);}
      '
      expect(result.fragment).toBe '
        precision mediump float;\
        uniform vec2 size;\
        void main(){\
          gl_FragColor=vec4(\
            vec2(gl_FragCoord[0],gl_FragCoord[1])/size,1.,1.\
          );\
        }
      '
