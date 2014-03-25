through = require 'through'
builtins = require '../glsl-tokenizer/lib/builtins'
keywords = require '../glsl-tokenizer/lib/literals'
binaryops = 'add':'+', 'sub':'-', 'mult':'*', 'div':'/'
typeop = require './typeoperation'


flatmap = (ary, func) ->
  ary.reduce (result, x) ->
    result.concat func x
  , []


build = ({ type, data, children }) ->
  result = { type }
  if data?
    result.data = data
    result.token = { data }
  if children
    result.children = children
    for child in children
      child.parent = result
  result


module.exports = ->
  through (program) ->
    if program.parent
      return
    root = build
      type: 'stmtlist'
      children: flatmap program.body, (x) -> transformers.transform x
    for child in root.children
      @queue child
    return


transformers =
  transform: (node) ->
    if f = @["transform#{node.type}"]
      return f.call @, node
    else
      throw new Error "Unsupported Node Type: #{node.type}"

  transformAssignmentExpression: ({ operator, left, right }) ->
    if right.type is 'FunctionExpression'
      right.id = left
      @transform right
    else
      [
        build type: 'expr', children: [
          build
            type: 'assign'
            data: operator
            children: @transform(left).concat @transform(right)
        ]
      ]

  transformLiteral: ({ value }) -> [
    build type: 'literal', data: value
  ]

  transformIdentifier: ({ name }) -> [
    build
      type:
        if name in keywords then 'keyword'
        else if name in builtins then 'builtin'
        else 'ident'
      data: name
  ]

  transformType: (type) ->
    @transformIdentifier type

  transformBlockStatement: ({ body }) -> [
    build type: 'stmtlist', children: flatmap body, (x) => @transform x
  ]

  transformExpressionStatement: ({ expression }) -> [
    build type: 'stmt', children: @transform expression
  ]

  transformVariableDeclaration: ({ declarations, kind, scope }) ->
    for decl in declarations
      type = scope.get decl.id.name
      if typeop.isUndef type
        continue
      if typeop.isFunction type
        continue unless decl.init
        decl.init.id = decl.id
        @transform(decl.init)[0]
      else
        build type: 'stmt', children: [
          build type: 'decl', children: [
            build type: 'placeholder'
            if kind is 'const'
              build type: 'keyword', data: 'const'
            else
              build type: 'placeholder'
            build type: 'placeholder'
            build type: 'placeholder'
          ].concat(
            @transformType type
            @transform decl
          )
        ]

  transformVariableDeclarator: ({ id, init }) ->
    tid = @transform id
    [
      build type: 'decllist', children: if init
        tid.concat [build type: 'expr', children: @transform init]
      else
        tid
    ]

  transformCallExpression: (node) -> [
    if node.callee.type is 'MemberExpression' and
        node.callee.object.name in keywords and
        op = binaryops[node.callee.property.name]
      # binary operator
      build type: 'binary', data: op, children: node.arguments.map (a) =>
        child = @transform(a)[0]
        if child.type is 'binary' or child.type is 'expr'
          build type: 'group', children: [child]
        else
          child
    else
      build type: 'call', children: @transform(node.callee).concat(
        flatmap node.arguments, (x) => @transform x
      )
  ]

  transformFunctionDeclaration: (node) -> [
    build type: 'stmt', children: [
      build type: 'decl', children: [
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        @transformType(typeop.returns(node.scope.parent.get node.id.name))[0]
        build type: 'function', children: @transform(node.id).concat([
          build type: 'functionargs', children: node.params.map (x) =>
            build type: 'decl', children: [
              build type: 'placeholder'
              build type: 'placeholder'
              if typeop.isInout(x.glslType)
                build type: 'keyword', data: 'inout'
              else
                build type: 'placeholder'
              build type: 'placeholder'
              @transformType(x.glslType)[0]
              build type: 'decllist', children: @transform x
            ]
        ], @transform node.body)
      ]
    ]
  ]

  transformFunctionExpression: (node) ->
    @transformFunctionDeclaration node

  transformReturnStatement: ({ argument }) -> [
    build type: 'stmt', children: [
      build type: 'return', children: @transform argument
    ]
  ]

  transformNewExpression: (node) ->
    @transformCallExpression node

  transformMemberExpression: ({ object, property, computed }) ->
    if computed
      throw new Error 'Not implemented'
    @transform property
