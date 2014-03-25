to = require './typeoperation'

array = (x) -> to.create 'array', of: x
struct = (x) -> to.create 'struct', of: x
ctor = (args) -> to.create 'constructor', arguments: args

bool = to.create 'bool'
int = to.create 'int'
float = to.create 'float'
vec2 = to.create 'vec2'
vec3 = to.create 'vec3'
vec4 = to.create 'vec4'
mat3 = to.create 'mat3'
mat4 = to.create 'mat4'

builtintypes =
  gl_Position: vec4
  gl_PointSize: float
  gl_ClipVertex: vec4
  gl_FragCoord: vec4
  gl_FrontFacing: bool
  gl_FragColor: vec4
  gl_FragData: array vec4
  gl_FragDepth: float
  gl_Color: vec4
  gl_SecondaryColor: vec4
  gl_Normal: vec3
  gl_Vertex: vec4
  gl_MultiTexCoord0: vec4
  gl_MultiTexCoord1: vec4
  gl_MultiTexCoord2: vec4
  gl_MultiTexCoord3: vec4
  gl_MultiTexCoord4: vec4
  gl_MultiTexCoord5: vec4
  gl_MultiTexCoord6: vec4
  gl_MultiTexCoord7: vec4
  gl_FogCoord: float
  gl_MaxLights: int
  gl_MaxClipPlanes: int
  gl_MaxTextureUnits: int
  gl_MaxTextureCoords: int
  gl_MaxVertexAttribs: int
  gl_MaxVertexUniformComponents: int
  gl_MaxVaryingFloats: int
  gl_MaxVertexTextureImageUnits: int
  gl_MaxCombinedTextureImageUnits: int
  gl_MaxTextureImageUnits: int
  gl_MaxFragmentUniformComponents: int
  gl_MaxDrawBuffers: int
  gl_ModelViewMatrix: mat4
  gl_ProjectionMatrix: mat4
  gl_ModelViewProjectionMatrix: mat4
  gl_TextureMatrix: array mat4
  gl_NormalMatrix: mat3
  gl_ModelViewMatrixInverse: mat4
  gl_ProjectionMatrixInverse: mat4
  gl_ModelViewProjectionMatrixInverse: mat4
  gl_TextureMatrixInverse: array mat4
  gl_ModelViewMatrixTranspose: mat4
  gl_ProjectionMatrixTranspose: mat4
  gl_ModelViewProjectionMatrixTranspose: mat4
  gl_TextureMatrixTranspose: array mat4
  gl_ModelViewMatrixInverseTranspose: mat4
  gl_ProjectionMatrixInverseTranspose: mat4
  gl_ModelViewProjectionMatrixInverseTranspose: mat4
  gl_TextureMatrixInverseTranspose: array mat4
  gl_NormalScale: float
  gl_DepthRangeParameters: ctor [float, float, float]
  gl_ClipPlane: array vec4
  gl_PointParameters: ctor [
    float, float, float, float, float, float, float
  ]
  gl_MaterialParameters: ctor [vec4, vec4, vec4, vec4, float]
  gl_LightSourceParameters: ctor [
    vec4, vec4, vec4, vec4, vec4,
    vec3, float, float, float, float, float, float
  ]
  gl_LightModelParameters: ctor [vec4]
  gl_LightModelProducts: ctor [vec4]
  gl_LightProducts: ctor [vec4, vec4, vec4]
  gl_FogParameters: ctor [vec4, float, float, float, float]
  gl_TextureEnvColor: array vec4
  gl_EyePlaneS: array vec4
  gl_EyePlaneT: array vec4
  gl_EyePlaneR: array vec4
  gl_EyePlaneQ: array vec4
  gl_ObjectPlaneS: array vec4
  gl_ObjectPlaneT: array vec4
  gl_ObjectPlaneR: array vec4
  gl_ObjectPlaneQ: array vec4
  gl_FrontColor: vec4
  gl_BackColor: vec4
  gl_FrontSecondaryColor: vec4
  gl_BackSecondaryColor: vec4
  gl_TexCoord: array vec4
  gl_FogFragCoord: float
  gl_PointCoord: vec2

extend =
  gl_DepthRange: struct builtintypes.gl_DepthRangeParameters
  gl_Point: struct builtintypes.gl_PointParameters
  gl_FrontMaterial: struct builtintypes.gl_MaterialParameters
  gl_BackMaterial: struct builtintypes.gl_MaterialParameters
  gl_LightSource: array struct builtintypes.gl_LightSourceParameters
  gl_LightModel: struct builtintypes.gl_LightSourceParameters
  gl_FrontLightModelProduct: struct builtintypes.gl_LightModelProducts
  gl_BackLightModelProduct: struct builtintypes.gl_LightModelProducts
  gl_FrontLightProduct: struct builtintypes.gl_LightProducts
  gl_BackLightProduct: struct builtintypes.gl_LightProducts
  gl_Fog: struct builtintypes.gl_FogParameters

for p in Object.keys extend
  builtintypes[p] = extend[p]

module.exports = builtintypes
