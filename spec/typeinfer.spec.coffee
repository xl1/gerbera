esprima = require 'esprima'
inferrer = require '../src/typeinfer'

describe 'typeinfer', ->
  describe 'infer()', ->
    it 'should return annotated JavaScript AST', ->
      ast = esprima.parse 'var a; a = 1.5;'
      inferrer.infer ast
      atype = ast.scope?.get? 'a'
      expect(atype).toBeDefined()
      expect(atype.getName()).toBe 'float'

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

    it 'should infer constructor/struct/instance types properly', ->
      code = '''
      function A(x){
        this.hoge = x;
      }
      var a = new A(3.14);
      '''
      ast = esprima.parse code
      inferrer.infer ast
      Atype = ast.scope.get 'A'
      atype = ast.scope.get 'a'
      expect(Atype.getName()).toBe 'constructor'
      expect(atype.getName()).toBe 'instance'
      expect(atype.getOf().getName()).toBe 'struct'
      expect(atype.getOf().getTypeName()).toBe '_A'
      expect(atype.getOf().getMember('hoge').getName()).toBe 'float'

    it 'should infer update expressions', ->
      ast = esprima.parse '''
      var a = 42;   // number
      var b = 3.14; // float
      var c = a++;  // should be int
      var d = b++;  // should be float
      '''
      inferrer.infer ast
      expect(ast.scope.get('a').getName()).toBe 'int'
      expect(ast.scope.get('b').getName()).toBe 'float'
      expect(ast.scope.get('c').getName()).toBe 'int'
      expect(ast.scope.get('d').getName()).toBe 'float'
