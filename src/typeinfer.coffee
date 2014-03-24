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
      node.glslType = f.call @, node, scope
      return node
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
          typeop.unite(
            @infer(left, scope).glslType
            @infer(right, scope).glslType
          )
        else
          throw new Error 'Not implemented'
    if left.type isnt 'Identifier'
      throw new Error 'Not implemented'
    scope.set left.name, type

  inferLiteral: ({ value, raw }) ->
    typeop.create(if raw is 'true' or raw is 'false' then 'bool' else 'float')

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
    scope.set id.name, init and @infer(init, scope).glslType

  inferCallExpression: (node, scope) ->
    calleeType = @infer(node.callee, scope).glslType
    argumentsTypes = node.arguments.map (c) => @infer(c, scope).glslType
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
    scope.set '#return', @infer(argument, scope).glslType
    return

  inferNewExpression: (node, scope) ->
    argumentsTypes = node.arguments.map (c) => @infer(c, scope).glslType
    calleeName = node.callee.name
    if calleeName in keywords
      return typeop.create calleeName
    throw new Error 'Not implemented'

  inferMemberExpression: ({ object, property, computed }, scope) ->
    if computed
      throw new Error 'Not implemented'
    typeop.create 'function', returns: typeop.create object.name
