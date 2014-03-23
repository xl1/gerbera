Stream = require 'stream'
esprima = require 'esprima'
deparser = require 'glsl-deparser'
inferrer = require '../src/typeinfer'
transform = require '../src/transform'

test = (source, expected) ->
  buffer = ''
  result = ''
  runs ->
    s = new Stream
    s.pipe transform()
      .pipe deparser false
      .on 'data', (r) -> buffer += r
      .on 'close', -> result = buffer
    s.emit 'data', inferrer.infer esprima.parse source
    s.emit 'close'
  waitsFor 1000, -> result
  runs ->
    expect(result).toBe expected

describe 'transform', ->
  it 'test for assignment', ->
    test 'var a = 1;', 'float a=1;'

  it 'should convert function statement', ->
    test '
      function func(i){}
      func(1);
    ', '
      void func(float i){}func(1)
    '

  it 'should convert function expression', ->
    test '
      var func = function(x, y){};
      func(0, 1);
    ', '
      void func(float x,float y){}func(0,1)
    '

  it 'should convert const declaration', ->
    test '
      const a = 1;
    ', '
      const float a=1;
    '

  it 'should convert NewExpression to constructor call', ->
    test 'var a = new vec3(0);', 'vec3 a=vec3(0);'
