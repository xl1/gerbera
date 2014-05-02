builtins = require '../glsl-tokenizer/lib/builtins'
keywords = require '../glsl-tokenizer/lib/literals'
binaryops = 'add':'+', 'sub':'-', 'mult':'*', 'div':'/'
Type = require './glsltype'


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


module.exports =
  transform: (node) ->
    if f = @["transform#{node.type}"]
      return f.call @, node
    else
      throw new Error "Unsupported Node Type: #{node.type}"

  _appendToRoot: (trees) ->
    for t in trees
      @root.children.push t
      t.parent = @root
    []

  transformProgram: ({ body }) ->
    @root = build type: 'stmtlist', children: []
    for x in body
      @_appendToRoot @transform x
    @root

  transformAssignmentExpression: ({ operator, left, right }) ->
    switch right.type
      when 'FunctionExpression'
        right.id = left
        @transform right
      when 'ArrayExpression'
        @_transformArrayAssignment id: left, init: right
      else
        [
          build type: 'assign', data: operator, children:
            @transform(left).concat @transform(right)
        ]

  transformLiteral: ({ value, glslType }) ->
    if (glslType.getDeclarationName() is 'float') and (value % 1 is 0)
      value = (value |0) + '.'
    [build type: 'literal', data: value]

  transformIdentifier: ({ name }) -> [
    build
      type:
        if name in keywords then 'keyword'
        else if name in builtins then 'builtin'
        else 'ident'
      data: name
  ]

  _transformType: (type) ->
    @transformIdentifier name: type.getDeclarationName()

  transformBlockStatement: ({ body }) -> [
    build type: 'stmtlist', children: flatmap body, (x) => @transform x
  ]

  transformExpressionStatement: ({ expression }) ->
    children = @transform expression
    if children.length is 0
      return []
    if children[0].type is 'stmt'
      return children
    [
      build type: 'stmt', children: [
        build type: 'expr', children: children
      ]
    ]

  transformVariableDeclaration: ({ declarations, kind, scope }) ->
    flatmap declarations, (decl) =>
      if decl.id.name in builtins
        return []
      type = scope.get decl.id.name
      if type.isUndef()
        return []
      if type.isFunction()
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
            if type.isArray()
              [
                build type: 'decllist', children: @transform(decl.id).concat [
                  build type: 'quantifier', children: [
                    build type: 'expr', children: [
                      build type: 'literal', data: type.getLength()
                    ]
                  ]
                ]
              ]
            else
              @transform decl
          )
        ]
      ]
      if type.isArray() and decl.init?
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
              build type: 'literal', data: i
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

  transformCallExpression: (node) ->
    isBinary =
      node.callee.type is 'MemberExpression' and
      node.callee.object.name in keywords and
      op = binaryops[node.callee.property.name]
    if isBinary
      return [
        build type: 'binary', data: op, children: (
          flatmap node.arguments, (x) => (@_optionalGrouping @transform) x
        )
      ]
    calleeNode = node.callee.glslType?.getNode()
    callee = @transform node.callee
    if callee.length is 0
      callee = @transform calleeNode.id
    [
      build type: 'call', children: callee.concat(
        flatmap node.arguments, (x) => @transform x
        flatmap calleeNode?.scope.inouts or [], (x) =>
          @transformIdentifier name: x
      )
    ]

  transformFunctionDeclaration: (node) -> @_appendToRoot [
    build type: 'stmt', children: [
      build type: 'decl', children: [
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        build type: 'placeholder'
        @_transformType(node.scope.parent.get(node.id.name).getReturns())[0]
        build type: 'function', children: @transform(node.id).concat([
          build type: 'functionargs', children: node.params.map((x) =>
            build type: 'decl', children: [
              build type: 'placeholder'
              build type: 'placeholder'
              build type: 'placeholder'
              build type: 'placeholder'
              @_transformType(x.glslType)[0]
              build type: 'decllist', children: @transform x
            ]
          ).concat node.scope.inouts.map((sym) =>
            build type: 'decl', children: [
              build type: 'placeholder'
              build type: 'placeholder'
              build type: 'keyword', data: 'inout'
              build type: 'placeholder'
              @_transformType(node.scope.get sym)[0]
              build type: 'decllist', children: [
                build type: 'ident', data: sym
              ]
            ]
          )
        ], @transform node.body)
      ]
    ]
  ]

  transformFunctionExpression: (node) ->
    @transformFunctionDeclaration node

  transformReturnStatement: ({ argument }) -> [
    build type: 'stmt', children: [
      build type: 'return', children:
        if argument
          [build type: 'expr', children: @transform argument]
        else
          []
    ]
  ]

  transformNewExpression: (node) ->
    @transformCallExpression node

  transformMemberExpression: ({ object, property, computed }) ->
    if computed
      [
        build type: 'binary', data: '[', children:
          (@_optionalGrouping @transform)(object).concat @transform(property)
      ]
    else if object.name is 'Math'
      if typeof Math[property.name] is 'number'
        [build type: 'literal', data: Math[property.name]]
      else
        @transform property
    else if object.name in keywords
      @transform property
    else if object.glslType.isTransparent()
      @transform property
    else
      [
        build type: 'operator', data: '.', children:
          (@_optionalGrouping @transform)(object).concat @transform(property)
      ]

  transformArrayExpression: ({ elements }) ->
    throw new Error 'Should not reach here'

  transformUnaryExpression: ({ operator, argument }) -> [
    build type: 'unary', data: operator, children:
      (@_optionalGrouping @transform) argument
  ]

  transformBinaryExpression: ({ operator, left, right }) -> [
    if operator is '%'
      build
        type: 'call'
        children: @transformIdentifier name: 'mod'
          .concat @transform(left), @transform(right)
    else
      build
        type: 'binary'
        data: operator.slice 0, 2 # (===, !==) -> (==, !=)
        children:
          flatmap [left, right], (@_optionalGrouping @transform).bind @
  ]

  transformLogicalExpression: ({ operator, left, right }) -> [
    build
      type: 'binary'
      data: operator
      children: flatmap [left, right],
        (@_optionalGrouping @_optionalCast 'bool', @transform).bind @
  ]

  transformConditinalExpression: ({ test, consequent, alternate }) -> [
    build type: 'ternary', data: '?', children: (
      @transform(test).concat @transform(consequent), @transform(alternate)
    )
  ]

  transformEmptyStatement: -> []

  transformIfStatement: ({ test, consequent, alternate }) ->
    children =
      (@_optionalCast 'bool', @transform)(test).concat @transform(consequent)
    if alternate
      children.push(build type: 'stmt', children: @transform alternate)
    [build type: 'stmt', children: [build type: 'if', children: children]]

  transformUpdateExpression: ({ operator, argument, prefix }) -> [
    if prefix
      build type: 'assign', data: operator[0] + '=', children:
        @transform(argument).concat [build type: 'literal', data: 1]
    else
      build type: 'suffix', data: operator, children: @transform argument
  ]

  transformWhileStatement: ({ test, body }) -> [
    build type: 'stmt', children: [
      build type: 'whileloop', children:
        (@_optionalCast 'bool', @transform)(test).concat @transform body
    ]
  ]

  transformDoWhileStatement: ({ test, body }) -> [
    build type: 'stmt', children: [
      build type: 'do-while', children:
        @transform(body).concat (@_optionalCast 'bool', @transform)(test)
    ]
  ]

  transformForStatement: ({ init, test, update, body }) ->
    emptyExpr = -> [build type: 'expr', children: []]
    [
      build type: 'stmt', children: [
        build type: 'forloop', children: [].concat(
          if init then @transform(init)[0].children else emptyExpr()
          if test then (@_optionalCast 'bool', @transform) test else emptyExpr()
          if update then @transform update else emptyExpr()
          @transform body
        )
      ]
    ]

  transformBreakStatement: -> [
    build type: 'stmt', children: [build type: 'break']
  ]

  transformContinueStatement: -> [
    build type: 'stmt', children: [build type: 'continue']
  ]

  transformThisExpression: -> [
    build type: 'ident', data: 'this'
  ]

  transformPrecisionDeclaration: ({ precision, type }) -> [
    build type: 'stmt', children: [
      build type: 'precision', children: [
        build type: 'keyword', data: precision
      ].concat @_transformType type
    ]
  ]

  transformExternalDeclaration: ({ name, kind, type }) -> [
    build type: 'stmt', children: [
      build type: 'decl', children: [
        build type: 'placeholder'
        build type: 'keyword', data: kind
        build type: 'placeholder'
        build type: 'placeholder'
        @_transformType(type)[0]
        build type: 'decllist', children: [
          build type: 'ident', data: name
        ]
      ]
    ]
  ]

  _optionalGrouping: (f) -> (node) =>
    children = f.call @, node
    if children.length isnt 1
      throw new Error 'Not implemented'
    switch children[0].type
      when 'binary', 'ternary', 'assign'
        return [build type: 'group', children: children]
    children

  _optionalCast: (typeName, f) -> (node) =>
    children = f.call @, node
    if node.glslType.getName() is typeName
      children
    else
      [
        build type: 'call', children:
          @transformIdentifier(name: typeName).concat children
      ]
