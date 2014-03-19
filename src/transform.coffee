through = require 'through'
builtins = require '../glsl-tokenizer/lib/builtins'
keywords = require '../glsl-tokenizer/lib/literals'
typeop = require './typeoperation'


build = ({ type, data, children }) ->
  result = { type }
  if data
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
      children: program.body.map (x) -> transformers.transform x
    for child in root.children
      @queue child
    return


transformers =
  transform: (node) ->
    if f = @["transform#{node.type}"]
      return f.call @, node
    else
      throw new Error "Unsupported Node Type: #{node.type}"

  transformProgram: ({ body }) -> build
    type: 'stmtlist'
    children: body.map (x) => @transform x

  transformAssignmentExpression: ({ operator, left, right }) ->
    if right.type is 'FunctionExpression'
      throw new Error 'Not implemented'
    else
      build
        type: 'expr'
        children: [build
          type: 'assign'
          data: operator
          children: [
            @transform left
            @transform right
          ]
        ]

  transformLiteral: ({ value }) -> build
    type: 'literal'
    data: value

  transformIdentifier: ({ name }) -> build
    type:
      if name in keywords then 'keyword'
      else if name in builtins then 'builtin'
      else 'ident'
    data: name

  transformType: (type) -> @transformIdentifier type

  transformBlockStatement: ({ body }) -> build
    type: 'stmtlist'
    children: body.map (x) => @transform x

  transformExpressionStatement: ({ expression }) -> build
    type: 'stmt'
    children: [@transform expression]

  transformVariableDeclaration: ({ declarations, kind }) -> build
    type: 'stmt'
    children: [build
      type: 'decl'
      children: [
        @transformType declarations[0].glslType
      ].concat declarations.map (x) => @transform x
    ]

  transformVariableDeclarator: ({ id, init }) -> build
    type: 'decllist'
    children: [
      @transform id
      build
        type: 'expr'
        children: [@transform init]
    ]

  transformCallExpression: (node) -> build
    type: 'call'
    children: [
      @transform node.callee
    ].concat node.arguments.map (x) => @transform x

  transformFunctionDeclaration: (node) -> build
    type: 'decl'
    children: [
      @transformType typeop.returns(node.scope.parent.get node.id.name)
      build
        type: 'function'
        children: [
          @transform node.id
          build
            type: 'functionargs'
            children: node.params.map (x) =>
              build
                type: 'decl'
                children: [
                  @transformType x.glslType
                  build
                    type: 'decllist'
                    children: [@transform x]
                ]
          @transform node.body
        ]
    ]
