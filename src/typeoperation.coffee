module.exports =
  create: (name, param={}) ->
    result = { name }
    switch name
      when 'function'
        result.arguments = param.arguments or []
        result.returns = param.returns or @create 'undef'
      when 'unresolvedFunction'
        result.node = param.node
      else
        result.inout = !! param.inout
    result

  isUndef: (type) -> (not type) or type.name is 'undef'
  inout: (type) -> @create type.name, inout: true
  isInout: (type) -> type.inout
  isUnresolved: (type) -> type.name is 'unresolvedFunction'
  isFunction: (type) -> (type.name is 'function') or @isUnresolved type
  node: (type) -> type.node

  returns: (type) ->
    if type.name isnt 'function'
      throw new Error "Type #{type?.name} is not function"
    type.returns

  arguments: (type) ->
    if type.name isnt 'function'
      throw new Error "Type #{type?.name} is not function"
    type.arguments

  uniteFunction: (type1, type2) ->
    args1 = @arguments type1
    args2 = @arguments type2
    if args1?.length isnt args2?.length
      throw new Error 'Type contradiction'
    @create 'function',
      arguments: (@unite args1[i], args2[i] for i in [0...args1.length] by 1)
      returns: @unite @returns(type1), @returns(type2)

  unite: (type1, type2) ->
    if @isUndef type1
      return type2 or @create 'undef'
    if @isUndef type2
      return type1
    switch type1.name
      when 'unresolvedFunction'
        if type2.name is 'unresolvedFunction' or type2.name is 'function'
          return type2
      when 'function'
        if type2.name is 'unresolvedFunction'
          return type1
        if type2.name is 'function'
          return @uniteFunction type1, type2
      when type2.name
        return @create type1.name, inout: @isInout(type1) and @isInout(type2)
    throw new Error 'Type contradiction'
