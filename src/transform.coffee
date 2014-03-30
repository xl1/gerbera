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
    switch right.type
      when 'FunctionExpression'
        right.id = left
        @transform right
      when 'ArrayExpression'
        @_transformArrayAssignment id: left, init: right
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

  _transformType: (type) ->
    @transformIdentifier if typeop.isArray(type) then typeop.of(type) else type

  transformBlockStatement: ({ body }) -> [
    build type: 'stmtlist', children: flatmap body, (x) => @transform x
  ]

  transformExpressionStatement: ({ expression }) ->
    children = @transform expression
    if children[0].type is 'stmt'
      return children
    [build type: 'stmt', children: children]

  transformVariableDeclaration: ({ declarations, kind, scope }) ->
    flatmap declarations, (decl) =>
      if decl.id.name in builtins
        return []
      type = scope.get decl.id.name
      if typeop.isUndef type
        return []
      if typeop.isFunction type
        if not decl.init?
          return []
        decl.init.id = decl.id
        return @transform decl.init
      stmts = [
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
            @_transformType type
            if typeop.isArray type
              [
                build type: 'decllist', children: @transform(decl.id).concat [
                  build type: 'quantifier', children: [
                    build type: 'expr', children: [
                      build type: 'literal', data: typeop.length type
                    ]
                  ]
                ]
              ]
            else
              @transform decl
          )
        ]
      ]
      if typeop.isArray(type) and decl.init?
        stmts.concat @_transformArrayAssignment decl
      else
        stmts

  _transformArrayAssignment: ({ id, init }) ->
    tid = @transform id
    for e, i in init.elements
      build type: 'stmt', children: [
        build type: 'expr', children: [
          build type: 'assign', data: '=', children: [
            build type: 'binary', data: '[', children: [
              tid[0]
              build type: 'expr', children: [
                build type: 'literal', data: i
              ]
            ]
          ].concat @transform e
        ]
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
      build type: 'binary', data: op, children: (
        flatmap node.arguments, (x) => (@_optionalGrouping @transform) x
      )
    else
      build type: 'call', children: @transform(node.callee).concat(
        flatmap node.arguments, (x) => @transform x
      )
  ]

  _transformWithOptionalGrouping: (node) ->
    t = @transform node
    if t.length isnt 1
      throw new Error 'Not implemented'
    switch t[0].type
      when 'binary', 'ternary', 'expr'
        [build type: 'group', children: t]
      else
        t

  transformFunctionDeclaration: (node) -> [
    build type: 'stmt', children: [
      build type: 'decl', children: [
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        @_transformType(typeop.returns(node.scope.parent.get node.id.name))[0]
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
              @_transformType(x.glslType)[0]
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
      return [
        build type: 'binary', data: '[', children:
          (@_optionalGrouping @transform)(object).concat @transform(property)
      ]
    if object.name is 'Math' and typeof Math[property.name] is 'number'
      return [build type: 'literal', data: Math[property.name]]
    @transform property

  transformArrayExpression: ({ elements }) ->
    throw new Error 'Should not reach here'

  transformUnaryExpression: ({ operator, argument }) -> [
    build type: 'unary', data: operator, children:
      (@_optionalGrouping @transform) argument
  ]

  transformBinaryExpression: ({ operator, left, right }) -> [
    build type: 'binary', data: operator, children:
      flatmap [left, right], (@_optionalGrouping @transform).bind @
  ]

  transformConditinalExpression: ({ test, consequent, alternate }) -> [
    build type: 'ternary', data: '?', children: (
      @transform(test).concat @transform(consequent), @transform(alternate)
    )
  ]

  transformEmptyStatement: -> []

  _optionalGrouping: (f) -> (node) =>
    children = f.call @, node
    if children.length isnt 1
      throw new Error 'Not implemented'
    if children[0].type is 'expr'
      switch children[0].children[0].type
        when 'binary', 'ternary', 'assign'
          return [build type: 'group', children: children]
    children

  _optionalCast: (typeName, f) -> (node) =>
    children = f.call @, node
    if node.glslType.name is typeName
      children
    else
      [
        build type: 'expr', children: [
          build type: 'call', children:
            @transformIdentifier(name: typeName).concat children
        ]
      ]
