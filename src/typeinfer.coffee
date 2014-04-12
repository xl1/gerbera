builtins = require '../glsl-tokenizer/lib/builtins'
keywords = require '../glsl-tokenizer/lib/literals'
Type = require './glsltype'
builtintypes = require './builtintypes'


class Scope
  constructor: (@parent) ->
    if parent
      parent.children.push @
    @children = []
    @symTable = {}
    @inouts = []
  set: (symbol, type) ->
    @symTable[symbol] = (type or new Type).unite @symTable[symbol]
  get: (symbol) ->
    if type = @symTable[symbol]
      return type
    if type = @parent?.get symbol
      if symbol not in @inouts
        @inouts.push symbol
      return type
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
      return node.glslType = f.call(@, node, scope) ? new Type
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
          @infer(left, scope).unite @infer(right, scope)
        else
          throw new Error 'Not implemented'
    if left.type isnt 'Identifier'
      throw new Error 'Not implemented'
    scope.set left.name, type

  inferLiteral: ({ value }) ->
    if typeof value is 'boolean'
      return new Type 'bool'
    new Type(if value % 1 then 'float' else 'number')

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
      calleeType.unite new Type 'function', arguments: argumentsTypes
    else
      calleeNode = calleeType.getNode()
      if calleeType.isUnresolved()
        calleeScope = calleeNode.scope
        for arg, i in calleeNode.params
          calleeScope.set arg.name, argumentsTypes[i]
          @infer arg, calleeScope
        @infer calleeNode.body, calleeScope
        calleeType.unite(
          new Type 'function',
            arguments: argumentsTypes
            returns: calleeScope.getLocal('#return') or new Type 'void'
        )
      else
        calleeType.unite new Type 'function', arguments: argumentsTypes
      if node.callee.name
        scope.set node.callee.name, calleeType
      else
        scope.set calleeNode.id.name, calleeType
    calleeType.getReturns()

  inferFunctionDeclaration: (node, scope) ->
    node.scope = new Scope scope
    scope.set node.id.name, new Type 'unresolvedFunction', node: node
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
    scope.set functionName, new Type 'unresolvedFunction', node: node

  inferReturnStatement: ({ argument }, scope) ->
    scope.set '#return',
      if argument then @infer(argument, scope) else new Type 'void'
    return

  inferNewExpression: (node, scope) ->
    argumentsTypes = node.arguments.map (c) => @infer c, scope
    calleeName = node.callee.name
    if calleeName in keywords
      return new Type calleeName
    throw new Error 'Not implemented'

  inferMemberExpression: ({ object, property, computed }, scope) ->
    if object.name is 'Math'
      if computed
        throw new Error 'Not supported'
      if typeof Math[property.name] is 'number'
        return new Type 'float'
      return new Type 'function', returns: new Type 'float'
    if object.name in keywords
      if computed
        throw new Error 'Not supported'
      return new Type 'function', returns: new Type object.name
    if computed
      @infer(property, scope).unite new Type 'int'
      type = @infer object, scope
      switch type.getName()
        when 'array'
          return type.getOf()
        when 'vec2', 'vec3', 'vec4'
          return new Type 'float'
        when 'ivec2', 'ivec3', 'ivec4'
          return new Type 'int'
        when 'bvec2', 'bvce3', 'bvec4'
          return new Type 'bool'
        when 'mat2' then return new Type 'vec2'
        when 'mat3' then return new Type 'vec3'
        when 'mat4' then return new Type 'vec4'
    throw new Error 'Not implemented'

  inferArrayExpression: ({ elements }, scope) ->
    new Type 'array',
      length: elements.length
      of: elements.reduce (p, c) =>
        p.unite @infer c, scope
      , new Type

  inferUnaryExpression: ({ operator, argument }, scope) ->
    type = @infer argument, scope
    switch operator
      when '+', '-'
        type
      when '!'
        new Type 'bool'
      else
        # ~, delete, typeof, void
        throw new Error 'Not supported'

  inferBinaryExpression: ({ operator, left, right }, scope) ->
    type = @infer(left, scope).unite @infer(right, scope)
    switch operator
      when '+', '-', '*', '/'
        type
      when '%'
        new Type 'float'
      when '<', '<=', '>', '>=', '==', '!=', '===', '!=='
        new Type 'bool'
      else
        # |, &, <<, >>, >>>, in, instanceof
        throw new Error 'Not supported'

  inferLogicalExpression: ({ operator, left, right }, scope) ->
    @infer left, scope
    @infer right, scope
    new Type 'bool'

  inferConditinalExpression: ({ test, consequent, alternate }, scope) ->
    @infer test, scope
    @infer(consequent, scope).unite @infer(alternate, scope)

  inferEmptyStatement: ->

  inferIfStatement: ({ test, consequent, alternate }, scope) ->
    @infer test, scope
    @infer consequent, scope
    if alternate
      @infer alternate, scope
    return

  inferUpdateExpression: ({ operator, argument, prefix }, scope) ->
    @infer(argument, scope).unite new Type 'int'

  inferWhileStatement: ({ test, body }, scope) ->
    @infer test, scope
    @infer body, scope
    return

  inferDoWhileStatement: (node, scope) ->
    @inferWhileStatement node, scope

  inferForStatement: ({ init, test, update, body }, scope) ->
    @infer init, scope
    @infer test, scope
    @infer update, scope
    @infer body, scope
    return
