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


module.exports =
  infer: (node, scope) ->
    if f = @["infer#{node.type}"]
      return f.call @, node, scope
    else
      throw new Error "Unsupported Node Type: #{node.type}"

  inferProgram: (node, scope) ->
    node.scope = new Scope
    for child in node.body
      @infer child, node.scope
    node

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
    scope.set id.name, init and @infer(init, scope)

  inferCallExpression: (node, scope) ->
    calleeType = @infer node.callee, scope
    argumentsTypes = @infer(child, scope) for child in node.arguments
    if typeop.isUnresolved calleeType
      calleeScope = calleeType.node.scope
      for arg, i in calleeType.node.params
        calleeScope.set arg.name, argumentsTypes[i]
      calleeType = @infer calleeType.node.body, calleeScope
    else
      calleeType = unite calleeType,
        typeop.create 'function', arguments: argumentsTypes
    typeop.returns calleeType

  inferFunctionDeclaration: (node, scope) ->
    node.scope = new Scope scope
    scope.set node.id.name, typeop.create 'unresolvedFunction', node: node
    return

  inferFunctionExpression: (node, scope) ->
    node.scope = new Scope scope
    scope.set node.id?.name, typeop.create 'unresolvedFunction', node: node
