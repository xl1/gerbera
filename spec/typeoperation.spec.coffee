typeop = require '../src/typeoperation'

describe 'typeoperation', ->
  describe 'create()', ->
    it 'should return a type', ->
      expect(typeop.create 'hoge').toBeDefined()
