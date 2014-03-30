builtins = require '../glsl-tokenizer/lib/builtins'
keywords = require '../glsl-tokenizer/lib/literals'
typeop = require './typeoperation'
builtintypes = require './builtintypes'


class Scope
  constructor: (@parent) ->
    if parent
      parent.children.push @
    @children = []
    @symTable = {}  
  set: (symbol, type) ->
    @symTable[symbol] = typeop.unite type, @symTable[symbol]
  get: (symbol) ->
    if type = @symTable[symbol]
      return type
    if type = @parent?.get symbol
      return typeop.inout type
    throw new Error "Undeclared symbol #{symbol}"
  getLocal: (symbol) ->
    @symTable[symbol]


module.exports =
  createAnonymousFunctionName: do ->
    i = 0
    -> "anonymousFuncion#{i++}"

  infer: (node, scope) ->
    if f = @["infer#{node.type}"]
      node.scope = scope
      return node.glslType = f.call @, node, scope
    else
      throw new Error "Unsupported Node Type: #{node.type}"

  inferProgram: (node, scope) ->
    node.scope = new Scope
    for child in node.body
      @infer child, node.scope
    return

  inferAssignmentExpression: ({ operator, left, right }, scope) ->
    type =
      switch operator
        when '=', '+=', '-='
          typeop.unite @infer(left, scope), @infer(right, scope)
        else
          throw new Error 'Not implemented'
    if left.type isnt 'Identifier'
      throw new Error 'Not implemented'
    scope.set left.name, type

  inferLiteral: ({ value }) ->
    typeop.create(if typeof value is 'boolean' then 'bool' else 'float')

  inferIdentifier: ({ name }, scope) ->
    if name in builtins then builtintypes[name] else scope.get name
  
  inferBlockStatement: ({ body }, scope) ->
    for child in body
      @infer child, scope
    return

  inferExpressionStatement: ({ expression }, scope) ->
    @infer expression, scope
    return

  inferVariableDeclaration: ({ declarations, kind }, scope) ->
    for child in declarations
      @infer child, scope
    return

  inferVariableDeclarator: ({ id, init }, scope) ->
    scope.set id.name, init and @infer init, scope

  inferCallExpression: (node, scope) ->
    calleeType = @infer node.callee, scope
    argumentsTypes = node.arguments.map (c) => @infer c, scope
    if node.callee.type is 'MemberExpression'
      calleeType.arguments = argumentsTypes
    else
      if typeop.isUnresolved calleeType
        calleeScope = calleeType.node.scope
        for arg, i in calleeType.node.params
          calleeScope.set arg.name, argumentsTypes[i]
          @infer arg, calleeScope
        @infer calleeType.node.body, calleeScope
        calleeType = typeop.unite(
          calleeType
          typeop.create 'function',
            arguments: argumentsTypes
            returns: calleeScope.getLocal('#return') or typeop.create 'void'
        )
      else
        calleeType = typeop.unite(
          calleeType
          typeop.create 'function', arguments: argumentsTypes
        )
      if node.callee.name
        scope.set node.callee.name, calleeType
      else
        scope.set calleeType.node.id.name, calleeType
    typeop.returns calleeType

  inferFunctionDeclaration: (node, scope) ->
    node.scope = new Scope scope
    scope.set node.id.name, typeop.create 'unresolvedFunction', node: node
    return

  inferFunctionExpression: (node, scope) ->
    node.scope = new Scope scope
    if node.id
      functionName = node.id.name
    else
      functionName = @createAnonymousFunctionName()
      node.id =
        type: 'Identifier'
        name: functionName
    scope.set functionName, typeop.create 'unresolvedFunction', node: node

  inferReturnStatement: ({ argument }, scope) ->
    scope.set '#return', @infer argument, scope
    return

  inferNewExpression: (node, scope) ->
    argumentsTypes = node.arguments.map (c) => @infer c, scope
    calleeName = node.callee.name
    if calleeName in keywords
      return typeop.create calleeName
    throw new Error 'Not implemented'

  inferMemberExpression: ({ object, property, computed }, scope) ->
    if object.name is 'Math'
      if computed
        throw new Error 'Not supported'
      if typeof Math[property.name] is 'number'
        return typeop.create 'float'
      return typeop.create 'function', returns: typeop.create 'float'
    if object.name in keywords
      if computed
        throw new Error 'Not supported'
      return typeop.create 'function', returns: typeop.create object.name
    if computed
      type = @infer object, scope
      if typeop.isArray type
        return typeop.of type
      if type.name.match /vec[234]/
        return typeop.create 'float'
      if type.name.match /mat([234])/
        return typeop.create 'vec' + RegExp.$1
    throw new Error 'Not implemented'

  inferArrayExpression: ({ elements }, scope) ->
    typeop.create 'array',
      length: elements.length
      of: elements.reduce (p, c) =>
        typeop.unite p, @infer c, scope
      , undefined

  inferUnaryExpression: ({ operator, argument }, scope) ->
    type = @infer argument, scope
    switch operator
      when '+', '-'
        type
      when '!'
        typeop.create 'bool'
      else
        # ~, delete, typeof, void
        throw new Error 'Not supported'

  inferBinaryExpression: ({ operator, left, right }, scope) ->
    ltype = @infer left, scope
    rtype = @infer right, scope
    switch operator
      when '+', '-', '*', '/'
        typeop.unite ltype, rtype
      when '%'
        typeop.create 'float'
      when '<', '<=', '>', '>=', '==', '!=', '===', '!=='
        typeop.create 'bool'
      else
        # |, &, <<, >>, >>>, in, instanceof
        throw new Error 'Not supported'

  inferLogicalExpression: ({ operator, left, right }, scope) ->
    @infer left, scope
    @infer right, scope
    typeop.create 'bool'

  inferConditinalExpression: ({ test, consequent, alternate }, scope) ->
    @infer test, scope
    typeop.unite @infer(consequent, scope), @infer(alternate, scope)

  inferEmptyStatement: ->

  inferIfStatement: ({ test, consequent, alternate }, scope) ->
    @infer test, scope
    @infer consequent, scope
    if alternate
      @infer alternate, scope
    return
