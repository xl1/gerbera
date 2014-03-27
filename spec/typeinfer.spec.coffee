esprima = require 'esprima'
typeop = require '../src/typeoperation'
inferrer = require '../src/typeinfer'

describe 'typeinfer', ->
  describe 'infer()', ->
    it 'should return annotated JavaScript AST', ->
      ast = esprima.parse 'var a; a = 1;'
      annotated = inferrer.infer ast
      atype = annotated.scope?.get? 'a'
      expect(atype).toBeDefined()
      expect(atype.name).toBe 'float'

    it 'should throw if an undeclared symbol is found', ->
      ast = esprima.parse 'a = 1;'
      expect ->
        inferrer.infer ast
      .toThrow()

    it 'should throw if a type contradiction is found', ->
      ast = esprima.parse 'a = true; a = 1;'
      expect ->
        inferrer.infer ast
      .toThrow()

    it 'should find type contradictions in array declarations', ->
      ast = esprima.parse 'a = [1, new vec2(0), 2, 3];'
      expect ->
        inferrer.inferrer ast
      .toThrow()
