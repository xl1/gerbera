Type = require './glsltype'

bool = new Type 'bool'
int = new Type 'int'
float = new Type 'float'
vec4 = new Type 'vec4'

builtintypes =
  gl_Position: vec4
  gl_PointSize: float
  gl_FragCoord: vec4
  gl_FrontFacing: bool
  gl_PointCoord: int
  gl_FragColor: vec4
  gl_FragData: new Type 'array', of: vec4
  gl_MaxVertexAttribs: int
  gl_MaxVertexUniformVectors: int
  gl_MaxVaryingVectors: int
  gl_MaxVertexTextureImageUnits: int
  gl_MaxCombinedTextureImageUnits: int
  gl_MaxTextureImageUnits: int
  gl_MaxFragmentUniformVectors: int
  gl_MaxDrawBuffers: int
  gl_DepthRangeParameters: new Type 'struct',
    members:
      near: float
      far: float
      diff: float
builtintypes.gl_DepthRange = new Type 'instance',
  of: builtintypes.gl_DepthRangeParameters

module.exports = builtintypes
