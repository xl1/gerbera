class TypeUnit
  constructor: (@name, param={}) ->
    @holders = []
    switch name
      when 'function'
        @arguments = param.arguments
        @returns = param.returns or new Type
        @node = param.node
      when 'unresolvedFunction'
        @node = param.node
      when 'constructor'
        @arguments = param.arguments or []
        @node = param.node
      when 'array'
        @of = param.of
        @length = param.length
      when 'instance'
        if param.of.getName() isnt 'struct'
          throw new Error 'instance.of should be a struct'
        @of = param.of
        @transparent = !!param.transparent
      when 'struct'
        @members = param.members

  uniteFunction: (t) ->
    t = @uniteConstructor t
    t.returns = @returns.unite t.returns
    t

  uniteConstructor: (t) ->
    args =
      if args1 = @arguments
        if args2 = t.arguments
          if args1.length - args2.length
            throw new Error 'Type contradiction'
          x.unite(args2[i]) for x, i in args1
        args1
      else
        t.arguments
    new TypeUnit 'function', arguments: args, node: @node or t.node

  unite: (t) ->
    return t unless @name
    return @ unless t.name
    switch @name
      when 'number'
        if t.name in ['int', 'float', 'number']
          return t
      when 'int'
        if t.name is 'int' or t.name is 'number'
          return @
      when 'float'
        if t.name is 'float' or t.name is 'number'
          return @
      when 'unresolvedFunction'
        if t.name in ['function', 'constructor', 'unresolvedFunction']
          t.node = @node
          return t
      when 'function'
        if t.name is 'unresolvedFunction'
          return new TypeUnit 'function',
            arguments: @arguments
            returns: @returns
            node: t.node
        if t.name is 'function'
          return @uniteFunction t
      when 'constructor'
        if t.name is 'unresolvedFunction'
          return new TypeUnit 'constructor',
            arguments: @arguments
            node: t.node
        if t.name is 'constructor'
          return @uniteConstructor t
      when 'array'
        if t.name is 'array' and @length is t.length
          return new TypeUnit 'array',
            length: @length
            of: @of.unite t.of
      when 'struct'
        throw new Error 'Struct type cannot be united'
      when 'instance'
        if t.name is 'instance' and @transparent is t.transparent
          return @
      when t.name
        return new TypeUnit t.name
    throw new Error 'Type contradiction'


module.exports = class Type
  constructor: (name, param) ->
    @append new TypeUnit(name, param)

  append: (@unit) ->
    unit.holders.push @

  isUndef: -> not @unit.name
  isUnresolved: -> @unit.name is 'unresolvedFunction'
  isFunction: -> (@unit.name is 'function') or @isUnresolved()
  isConstructor: -> @unit.name is 'constructor'
  isStruct: -> @unit.name is 'struct'
  isInstance: -> @unit.name is 'instance'
  isArray: -> @unit.name is 'array'
  isTransparent: -> @unit.transparent

  getName: -> @unit.name
  getNode: -> @unit.node
  getOf: -> @unit.of
  getLength: -> @unit.length
  getReturns: -> @unit.returns
  getArguments: -> @unit.arguments
  getMember: (name) -> @unit.members[name]

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
      newUnit = @unit.unite type.unit
      t.append(newUnit) for t in @unit.holders
      t.append(newUnit) for t in type.unit.holders
    @
