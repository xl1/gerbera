Type = require '../src/glsltype'

describe 'Type', ->
  describe 'getName()', ->
    it 'should return its name', ->
      expect(new Type('float').getName()).toBe 'float'
      expect(new Type('unresolvedFunction').getName()).toBe 'unresolvedFunction'

  describe 'unite()', ->
    it 'should unite number + (undef) --> number', ->
      expect (new Type).unite(new Type 'number').getName()
        .toBe 'number'

    it 'should unite float + float --> float', ->
      expect (new Type 'float').unite(new Type 'float').getName()
        .toBe 'float'

    it 'should unite number + float --> float', ->
      expect (new Type 'number').unite(new Type 'float').getName()
        .toBe 'float'

    it 'should unite unresolvedFunction + function --> function', ->
      node = {}
      unresolved = new Type 'unresolvedFunction', node: node
      func = new Type 'function',
        arguments: [new Type 'float']
        returns: new Type 'int'
      type = unresolved.unite func
      expect(type.getName()).toBe 'function'
      expect(type.getNode()).toBe node
      expect(type.getArguments()[0].getName()).toBe 'float'
      expect(type.getReturns().getName()).toBe 'int'

    it 'should not unite float + int', ->
      expect ->
        (new Type 'float').unite new Type 'int'
      .toThrow()

    it 'should propagate type information', ->
      t1 = new Type 'number' # ---+
      t2 = new Type 'number' # ---+-+
      t3 = new Type 'float'  # -+   |
      t4 = new Type 'number' # -+---+--> float
      t1.unite t2
      t3.unite t4
      t2.unite t4
      expect(t1.getName()).toBe 'float'
