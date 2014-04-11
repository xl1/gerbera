class TypeUnit
  constructor: (@name, param={}) ->
    switch name
      when 'function'
        @arguments = param.arguments
        @returns = param.returns or new Type
      when 'unresolvedFunction'
        @node = param.node
      when 'constructor'
        @arguments = param.arguments or []
      when 'array'
        @of = param.of
        @length = param.length
      when 'struct'
        @of = param.of


module.exports = class Type
  constructor: (name, param) ->
    @unit = new TypeUnit name, param

  isUndef: -> not @unit.name
  isUnresolved: -> @unit.name is 'unresolvedFunction'
  isFunction: -> (@unit.name is 'function') or @isUnresolved()
  isConstructor: -> @unit.name is 'constructor'
  isStruct: -> @unit.name is 'struct'
  isArray: -> @unit.name is 'array'

  getName: -> @unit.name  
  getNode: -> @unit.node
  getOf: -> @unit.of
  getLength: -> @unit.length
  getReturns: -> @unit.returns
  getArguments: -> @unit.arguments

  getDeclarationName: ->
    switch @getName()
      when 'number'
        'float'
      when 'array'
        @getOf().getDeclarationName()
      when 'unresolvedFunction', ''
        null
      else
        @getName()

  unite: (type) ->
    if type
      @unit = type.unit = @_unite(type).unit
    @

  _uniteFunction: (type) ->
    type = @_uniteConstructor type
    type.unit.returns = @getReturns().unite type.getReturns()
    type

  _uniteConstructor: (type) ->
    args =
      if args1 = @getArguments()
        if args2 = type.getArguments()
          if args1.length - args2.length
            throw new Error 'Type contradiction'
          x.unite(args2[i]) for x, i in args1
        args1
      else
        type.getArguments()
    new Type 'function', arguments: args, node: @getNode() or type.getNode()

  _unite: (type) ->
    if @isUndef()
      return type
    if type.isUndef()
      return @
    typeName = type.getName()
    switch @getName()
      when 'number'
        if typeName is 'int' or typeName is 'float' or typeName is 'number'
          return type
      when 'int'
        if typeName is 'int' or typeName is 'number'
          return @
      when 'float'
        if typeName is 'float' or typeName is 'number'
          return @
      when 'unresolvedFunction'
        if type.isFunction()
          return type
      when 'function'
        if typeName is 'unresolvedFunction'
          return new Type 'function',
            arguments: @getArguments()
            returns: @getReturns()
            node: type.getNode()
        if typeName is 'function'
          return @_uniteFunction type
      when 'constructor'
        if typeName is 'unresolvedFunction'
          return new Type 'constructor',
            arguments: @getArguments()
            node: type.getNode()
        if typeName is 'constructor'
          return @_uniteConstructor type
      when 'array'
        if typeName is 'array' and @getLength() is type.getLength()
          return new Type 'array',
            length: @getLength
            of: @getOf().unite type.getOf()
      when 'struct'
        if typeName is 'struct'
          return new Type 'struct', of: @getOf().unite type.getOf()
      when typeName
        return new Type typeName
    throw new Error 'Type contradiction'
