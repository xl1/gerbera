Stream = require 'stream'
esprima = require 'esprima'
deparser = require 'glsl-deparser'
inferrer = require '../src/typeinfer'
transform = require '../src/transform'

test = (source, expected) ->
  result = ''
  runs ->
    s = new Stream
    s.pipe transform()
      .pipe deparser false
      .on 'data', (r) -> result = r
    s.emit 'data', inferrer.infer esprima.parse source
  waitsFor 1000, -> result
  runs ->
    expect(result).toBe expected

describe 'transform', ->
  it 'test for assignment', ->
    test 'var a = 1;', 'float a=1;'
