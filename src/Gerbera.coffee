esprima = require 'esprima'
deparser = require 'glsl-deparser'
inferrer = require './typeinfer'
transformer = require './transform'
Type = require './glsltype'


module.exports =
  compileShader: ({ attributes, uniforms, varyings, vertex, fragment, minify }) ->
    minify ?= true
    vertex: @_compileShaderSource vertex, [
      { kind: 'attribute', value: attributes }
      { kind: 'uniform', value: uniforms }
      { kind: 'varying', value: varyings }
    ], { minify }
    fragment: @_compileShaderSource fragment, [
      { kind: 'uniform', value: uniforms }
      { kind: 'varying', value: varyings }
    ], { minify }


  _compileShaderSource: (source, params, option) ->
    ast = esprima.parse "(#{source})();"
    if not mainFuncExpr = ast.body[0].expression.callee
      throw new Error 'Shader source should be a function expression'
    # main という名前だったことにする
    mainFuncExpr.id =
      type: 'Identifier'
      name: 'main'
    # attributes, uniforms, varyings の型は root scope に与える
    scope = new (inferrer.Scope)
    for { name }, i in mainFuncExpr.params
      scope.set name, new Type 'instance',
        of: new Type('struct', members: params[i].value)
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
    stream = deparser(!option.minify).on('data', (r) -> result += r)
    for stmt in preamble
      stmt.parent = program
      stream.write stmt
    for stmt in program.children
      stream.write stmt
    result


  # types
  bool: new Type 'bool'
  int: new Type 'int'
  float: new Type 'float'
  vec2: new Type 'vec2'
  vec3: new Type 'vec3'
  vec4: new Type 'vec4'
  ivec2: new Type 'ivec2'
  ivec3: new Type 'ivec3'
  ivec4: new Type 'ivec4'
  bvec2: new Type 'bvec2'
  bvec3: new Type 'bvec3'
  bvec4: new Type 'bvec4'
  mat2: new Type 'mat2'
  mat3: new Type 'mat3'
  mat4: new Type 'mat4'
  array: (t) -> new Type 'array', of: t
  sampler2D: new Type 'sampler2D'
  samplerCube: new Type 'samplerCube'
