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
  waitsFor 10, -> result
  runs ->
    expect(result).toBe expected

describe 'transform', ->
  it 'should convert variable declaration', ->
    test 'var a = 1;', 'float a=1;'

  it 'should convert function statement', ->
    test '
      function func(i){}
      func(1);
    ', '
      void func(float i){}func(1)
    '

  it 'should infer return value type of function', ->
    test '
      function func2(i){ return i; }
      func2(2);
    ', '
      float func2(float i){return i;}func2(2)
    '

  it 'should convert function expression', ->
    test '
      var func = function(x, y){};
      func(0, 1);
    ', '
      void func(float x,float y){}func(0,1)
    '

  it 'should convert function expression assignment', ->
    test '
      var func;
      func = function(x){};
      func(0);
      func(1);
    ', '
      void func(float x){}func(0)func(1)
    '

  it 'should convert const declaration', ->
    test '
      const a = 1;
    ', '
      const float a=1;
    '

  it 'should convert NewExpression to constructor call', ->
    test 'var a = new vec3(0);', 'vec3 a=vec3(0);'

  it 'should convert multiple declarations', ->
    test 'var x = 0, y = new vec3(1);', 'float x=0;vec3 y=vec3(1);'

  it 'should convert builtin methods', ->
    test '
      var x = vec3.pow(new vec3(1, 2, 3), 4);
    ', '
      vec3 x=pow(vec3(1,2,3),4);
    '

  it 'should convert methods to binary operators', ->
    test '
      var a = new vec3(1), b = new vec3(1, 2, 3);
      var x = vec3.mult(3, vec3.add(vec3.div(b, 2), vec3.sub(a, b)))
    ', '
      vec3 a=vec3(1);vec3 b=vec3(1,2,3);\
      vec3 x=3*((b/2)+(a-b));
    '

  it 'should add parentheses to make priority clear', ->
    test '
      var a, b;
      var x = vec3.mult(a = 0, b = new vec3(1));
    ', '
      float a;vec3 b;\
      vec3 x=(a=0)*(b=vec3(1));
    '

  it 'should ignore declarations of builtins (CoffeeScript support)', ->
    test '
      var a, gl_Position, b, gl_PointSize;
      b = 1;
      gl_PointSize = b;
    ', '
      float b;b=1;gl_PointSize=b;
    '

  it 'should convert array', ->
    test '
      var ary = [1, 2, 3];
      var x = ary[0] + ary[1 + 3 - 2];
    ', '
      float ary[3];ary[0]=1;ary[1]=2;ary[2]=3;\
      float x=(ary[0])+(ary[(1+3)-2]);
    '
