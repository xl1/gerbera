esprima = require 'esprima'
deparser = require 'glsl-deparser'
inferrer = require './typeinfer'
transformer = require './transform'
Type = require './glsltype'


module.exports =
  compileShader: ({ attributes, uniforms, varyings, vertex, fragment }) ->
    vertex: @_compileShaderSource vertex, [
      { kind: 'attribute', value: attributes }
      { kind: 'uniform', value: uniforms }
      { kind: 'varying', value: varyings }
    ]
    fragment: @_compileShaderSource fragment, [
      { kind: 'uniform', value: uniforms }
      { kind: 'varying', value: varyings }
    ]


  _compileShaderSource: (source, params) ->
    ast = esprima.parse "(#{source})();"
    if not mainFuncExpr = ast.body[0].expression.callee
      throw new Error 'Shader source should be a function expression'
    # main という名前だったことにする
    mainFuncExpr.id =
      type: 'Identifier'
      name: 'main'
    # attributes, uniforms, varyings の型は root scope に与える
    scope = new (inferrer.Scope)
    for param, i in params
      scope.set mainFuncExpr.params[i].name,
        new Type 'instance',
          of: new Type('struct', members: param.value)
          transparent: true
    # 引数はなかったことにする
    mainFuncExpr.params = []

    inferrer.infer ast, scope
    # params が inout としてカウントされないようにする
    scope.children[0].inouts = []
    # CallExpression ではなく単に function があるだけだったことにする
    ast.body[0].expression = mainFuncExpr

    program = transformer.transform(ast)
    preamble = transformer.transformPrecisionDeclaration
      precision: 'mediump', type: @float
    for { kind, value } in params
      for own name, type of value
        preamble = preamble.concat(
          transformer.transformExternalDeclaration { name, kind, type }
        )

    result = ''
    stream = deparser(false).on('data', (r) -> result += r)
    for stmt in preamble
      stmt.parent = program
      stream.write stmt
    for stmt in program.children
      stream.write stmt
    result
