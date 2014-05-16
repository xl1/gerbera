esprima = require 'esprima'
deparser = require 'glsl-deparser'
inferrer = require './typeinfer'
transformer = require './transform'
Type = require './glsltype'


class Converter
  constructor: ({ attributes, uniforms, @vertex, @fragment, @minify }) ->
    @_attribute = new Type 'struct', members: attributes
    @_uniform = new Type 'struct', members: uniforms
    @_varying = new Type 'struct'

  convert: ->
    option =
      minify: @minify ? true
      precision:
        float: 'mediump'
    vertex:
      @_convertShader @vertex, {
        attribute: @_attribute
        uniform: @_uniform
        varying: @_varying
      }, option
    fragment:
      @_convertShader @fragment, {
        uniform: @_uniform
        varying: @_varying
      }, option

  _convertShader: (source, param, option) ->
    source = "(#{source})(#{Object.keys(param).sort().join()})"
    ast = esprima.parse source
    if not mainFuncExpr = ast.body[0].expression.callee
      throw new Error 'Shader source should be a function expression'
    # add a function name
    mainFuncExpr.id =
      type: 'Identifier'
      name: 'main'
    # tell types of params
    scope = new (inferrer.Scope)
    for own kind, type of param
      scope.set kind, new Type 'instance', of: type, transparent: true

    inferrer.infer ast, scope
    # unwrap CallExpression
    ast.body[0].expression = mainFuncExpr

    program = transformer.transform(ast)
    preamble = []
    for own typeName, precision of option.precision ? {}
      preamble = preamble.concat(
        transformer.transformPrecisionDeclaration
          precision: precision
          type: Gerbera[typeName]
      )
    for own kind, paramType of param
      for { name, type } in paramType.getAllMembers()
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


module.exports = Gerbera =
  compileShader: (opt) ->
    new Converter(opt).convert()

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
