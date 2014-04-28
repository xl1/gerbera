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
        @typeName = param.typeName
        @members = param.members or {}

  uniteFunction: (t) ->
    new TypeUnit 'function',
      arguments: @_uniteArguments t
      node: @node or t.node
      returns: @returns.unite t.returns

  uniteConstructor: (t) ->
    new TypeUnit 'constructor',
      arguments: @_uniteArguments t
      node: @node or t.node
      of: if @of then @of.unite(t.of) else t.of

  _uniteArguments: (t) ->
    if args1 = @arguments
      if args2 = t.arguments
        if args1.length - args2.length
          throw new Error 'Type contradiction'
        x.unite(args2[i]) for x, i in args1
      args1
    else
      t.arguments

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
          @node = t.node
          return @
        if t.name is 'function'
          return @uniteFunction t
        if t.name is 'constructor'
          return t.uniteConstructor @
      when 'constructor'
        if t.name is 'unresolvedFunction'
          @node = t.node
          return @
        if t.name is 'function' or t.name is 'constructor'
          return @uniteConstructor t
      when 'array'
        if t.name is 'array' and @length is t.length
          return new TypeUnit 'array',
            length: @length
            of: @of.unite t.of
      when 'struct'
        if t.name is 'struct'
          for own name, type of t.members
            if @members[name]
              @members[name].unite type
            else
              @members[name] = type
          @typeName or= t.typeName
          return @
      when 'instance'
        if t.name is 'instance' and @transparent is t.transparent
          return new TypeUnit 'instance',
            transparent: @transparent
            of: @of.unite t.of
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
  getTypeName: -> @unit.typeName
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
