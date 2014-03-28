module.exports =
  create: (name, param={}) ->
    result = { name }
    switch name
      when 'function'
        result.arguments = param.arguments or []
        result.returns = param.returns or @create 'undef'
      when 'unresolvedFunction'
        result.node = param.node
      when 'constructor'
        result.arguments = param.arguments or []
      when 'array'
        result.of = param.of
        result.length = param.length
        result.inout = !! param.inout
      when 'struct'
        result.of = param.of
        result.inout = !! param.inout
      else
        result.inout = !! param.inout
    result

  isUndef: (type) -> (not type) or type.name is 'undef'
  inout: (type) -> @create type.name, inout: true
  isInout: (type) -> type.inout
  isUnresolved: (type) -> type.name is 'unresolvedFunction'
  isFunction: (type) -> (type.name is 'function') or @isUnresolved type
  isConstructor: (type) -> type.name is 'constructor'
  isStruct: (type) -> type.name is 'struct'
  isArray: (type) -> type.name is 'array'
  node: (type) -> type.node
  of: (type) -> type.of
  length: (type) -> type.length

  returns: (type) ->
    if type.name isnt 'function'
      throw new Error "Type #{type?.name} is not function"
    type.returns

  arguments: (type) ->
    if type.name isnt 'function' and type.name isnt 'constructor'
      throw new Error "Type #{type?.name} is not function"
    type.arguments

  uniteFunction: (type1, type2) ->
    type = @uniteConstructor type1, type2
    type.returns = @unite @returns(type1), @returns(type2)
    type

  uniteConstructor: (type1, type2) ->
    args1 = @arguments type1
    args2 = @arguments type2
    if args1?.length isnt args2?.length
      throw new Error 'Type contradiction'
    @create 'function',
      arguments: (@unite args1[i], args2[i] for i in [0...args1.length] by 1)
      node: type1.node or type2.node

  unite: (type1, type2) ->
    if @isUndef type1
      return type2 or @create 'undef'
    if @isUndef type2
      return type1
    inout = @isInout(type1) and @isInout(type2)
    switch type1.name
      when 'unresolvedFunction'
        if type2.name is 'unresolvedFunction' or type2.name is 'function'
          return type2
      when 'function'
        if type2.name is 'unresolvedFunction'
          return @create 'function',
            arguments: type1.arguments
            returns: type1.returns
            node: type2.node
        if type2.name is 'function'
          return @uniteFunction type1, type2
      when 'constructor'
        if type2.name is 'unresolvedFunction'
          return @create 'constructor',
            arguments: type1.arguments
            node: type2.node
        if type2.name is 'constructor'
          return @uniteConstructor type1, type2
      when 'array'
        if type1.name is type2.name and @length(type1) is @length(type2)
          return @create 'array',
            inout: inout
            length: @length type1
            of: @unite @of(type1), @of(type2)
      when 'struct'
        if type1.name is type2.name
          return @create type1.name,
            inout: inout
            of: @unite @of(type1), @of(type2)
      when type2.name
        return @create type1.name, inout: inout
    throw new Error 'Type contradiction'
