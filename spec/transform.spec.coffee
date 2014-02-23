Stream = require 'stream'
esprima = require 'esprima'
deparser = require 'glsl-deparser'
transform = require '../src/transform'

describe 'transform', ->
  it 'test for assignment', ->
    result = ''
    runs ->
      stream = new Stream
      stream
        .pipe transform()
        .pipe deparser false
        .on 'data', (r) -> result = r
      stream.emit 'data', esprima.parse 'a = 1;'
    waitsFor 1000, -> result
    runs ->
      expect(result).toBe 'a=1;'
