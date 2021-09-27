import lib-sampler.glsl
import lib-sparse.glsl
import lib-env.glsl
import lib-normal.glsl
import lib-pbr.glsl
import lib-alpha.glsl
import lib-vectors.glsl
import lib-utils.glsl
import lib-emissive.glsl


//: param auto main_light
uniform vec4 uniform_main_light;

//: param auto world_camera_direction
uniform vec3 uniform_world_camera_direction;

//: param auto camera_view_matrix
uniform mat4 uniform_camera_view_matrix;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shading Color Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;

//: param auto channel_user1
uniform SamplerSparse first_shade_tex;

//: param auto channel_user2
uniform SamplerSparse second_shade_tex;

//: param custom { "default": true, "label": "Use Shading", "group": "Shading Color Settings"}
uniform bool use_shading;

//: param custom { "default": [1.0, 1.0, 1.0],"label": "Basic Color", "widget": "color", "group": "Shading Color Settings"}
uniform vec3 basic_color;

//: param custom { "default": false, "label": "Use User1 Channel to 1st Shade Color", "group": "Shading Color Settings"}
uniform bool use_user1_channel;

//: param custom { "default": [0.5, 0.5, 0.5],"label": "1st Shade Color", "widget": "color", "group": "Shading Color Settings"}
uniform vec3 first_shade_color;

//: param custom { "default": false, "label": "Use User2 Channel to 2nd Shade Color", "group": "Shading Color Settings"}
uniform bool use_user2_channel;

//: param custom { "default": [0.2, 0.2, 0.2],"label": "2nd Shade Color", "widget": "color", "group": "Shading Color Settings"}
uniform vec3 second_shade_color;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shading Step and Feather Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param custom {"default": 0.8,"min": 0.0,"max": 1.0,"label": "1st Color Step", "group": "Shading Step and Feather Settings"}
uniform float first_color_step;

//: param custom {"default": 0.0,"min": 0.0,"max": 1.0,"label": "1st Color Feather", "group": "Shading Step and Feather Settings"}
uniform float first_color_feather;

//: param custom {"default": 0.5,"min": 0.0,"max": 1.0,"label": "2nd Color Step", "group": "Shading Step and Feather Settings"}
uniform float second_color_step;

//: param custom {"default": 0.0,"min": 0.0,"max": 1.0,"label": "2nd Color Feather", "group": "Shading Step and Feather Settings"}
uniform float second_color_feather;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shading Position Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param auto channel_user3
uniform SamplerSparse first_shade_position_tex;

//: param auto channel_user4
uniform SamplerSparse second_shade_position_tex;

//: param custom { "default": false, "label": "Use User3 Channel to 1st Shade Position Map", "group": "Shading Position Settings"}
uniform bool use_user3_channel;

//: param custom { "default": false, "label": "Use User4 Channel to 2nd Shade Position Map", "group": "Shading Position Settings"}
uniform bool use_user4_channel;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// High Light Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param custom { "default": false, "label": "Use High Light","group": "High Light Settings"}
uniform bool use_high_light;

//: param custom { "default": [1.0, 1.0, 1.0],"label": "High Light Color", "widget": "color","group": "High Light Settings"}
uniform vec3 high_light_color;

//: param custom {"default": 0.3,"min": 0.0,"max": 1.0,"label": "High Light Step","group": "High Light Settings"}
uniform float high_light_step;

//: param custom {"default": 0.0,"min": 0.0,"max": 1.0,"label": "High Light Feather","group": "High Light Settings"}
uniform float high_light_feather;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Rim Light Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param custom { "default": false, "label": "Use Rim Light","group": "Rim Light Settings"}
uniform bool use_rim_light;

//: param custom { "default": [1.0, 1.0, 1.0],"label": "Rim Light Color", "widget": "color","group": "Rim Light Settings"}
uniform vec3 rim_light_color;

//: param custom {"default": 0.3,"min": 0.0,"max": 1.0,"label": "Rim Light Step","group": "Rim Light Settings"}
uniform float rim_light_step;

//: param custom {"default": 0.0,"min": 0.0,"max": 1.0,"label": "Rim Light Feather","group": "Rim Light Settings"}
uniform float rim_light_feather;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sphere Mapping (Matcap) Settings
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//: param custom { "default": false, "label": "Use Sphere Mapping","group": "Sphere Mapping (Matcap) Settings"}
uniform bool use_sphere_map;

//: param custom { "default": true, "label": "Sphere Mapping Texture is sRGB","group": "Sphere Mapping (Matcap) Settings"}
uniform bool sphere_map_is_sRGB;

//: param custom { "default": "texture_name", "label": "Sphere Mapping Texture", "usage": "Texture" ,"group": "Sphere Mapping (Matcap) Settings"}
uniform sampler2D sphere_map_tex;

//: param custom {
//:   "default": 10,
//:   "label": "Blend Mode",
//:   "widget": "combobox",
//:   "values": {
//:     "LinearDodge(Add)": 10,
//:     "Multiply": 4,
//:     "Normal": 2
//:   },
//:   "group": "Sphere Mapping (Matcap) Settings"
//: }
uniform int sphere_map_blend_mode;

const vec3 DEFAULT_USER_COLOR = vec3(1.0,1.0,1.0);

vec3 getUserColor(vec4 sampledValue)
{
  return sampledValue.rgb + DEFAULT_USER_COLOR * (1.0 - sampledValue.a);
}

vec3 getUserColor(SamplerSparse sampler, SparseCoord coord)
{
  return getUserColor(textureSparse(sampler, coord));
}

float remap(float val, float inMin, float inMax){
  return (val-inMin)/(inMax-inMin);
}

void shade(V2F inputs)
{
  inputs.normal = normalize(inputs.normal);
  LocalVectors vectors = computeLocalFrame(inputs);

  vec3 white = vec3(1.0,1.0,1.0);
  vec3 black = vec3(0.0,0.0,0.0);

  vec3 N = vectors.normal;
  vec3 light_dir = normalize(uniform_main_light.xyz);
  vec3 view_dir = getEyeVec(camera_dir);
  // vec3 view_dir = getEyeVec(uniform_world_camera_direction);
  vec3 half_dir = normalize(light_dir + view_dir);

  vec3 basecolor_map = getBaseColor(basecolor_tex, inputs.sparse_coord);
  vec3 color = basecolor_map;

  // Shading
  if (use_shading){
    float half_lambert = (0.5 * dot(N, light_dir)) + 0.5;

    float first_shade = clamp(remap(half_lambert,first_color_step,first_color_step+first_color_feather),0.0,1.0);
    float second_shade = clamp(remap(half_lambert,second_color_step,second_color_step+second_color_feather),0.0,1.0);
    second_shade = clamp(1-first_shade-second_shade,0.0,1.0);
    first_shade = clamp(1-first_shade,0.0,1.0);
    
    vec3 first_shade_position_map = sRGB2linear(getUserColor(first_shade_position_tex,inputs.sparse_coord));
    vec3 second_shade_position_map = sRGB2linear(getUserColor(second_shade_position_tex, inputs.sparse_coord));

    vec3 first_shade_color_map = sRGB2linear(getUserColor(first_shade_tex,inputs.sparse_coord));
    vec3 second_shade_color_map = sRGB2linear(getUserColor(second_shade_tex, inputs.sparse_coord));

    vec3 first_color = use_user1_channel ? first_shade_color_map * first_shade_color : basecolor_map * first_shade_color;
    vec3 second_color = use_user2_channel ? second_shade_color_map * second_shade_color : basecolor_map * second_shade_color;

    first_shade_position_map = use_user3_channel ? mix(1-first_shade_position_map,white,first_shade) : vec3(first_shade,first_shade,first_shade);
    second_shade_position_map = use_user4_channel ? mix(1-second_shade_position_map,white,second_shade) : vec3(second_shade,second_shade,second_shade);

    color = basecolor_map * basic_color;
    vec3 shade = mix(color,first_color,first_shade_position_map);
    color = mix(shade,second_color,second_shade_position_map);
  }

  // High Light
  float high_light_map = 1.0 - ((0.5 * dot(N, half_dir)) + 0.5);
  high_light_map = clamp(remap(high_light_map,pow(high_light_step,5),pow(high_light_step,5)+(high_light_step*high_light_feather)),0.0,1.0);
  vec3 high_light = use_high_light ? high_light_color * clamp(1.0 - high_light_map,0.0,1.0) : black;

  // Rim Light
  float rim_light_map = dot(N, view_dir);
  rim_light_map = clamp(remap(rim_light_map,rim_light_step,rim_light_step+rim_light_feather),0.0,1.0);
  vec3 rim_light = use_rim_light ? rim_light_color *  clamp(1.0 - rim_light_map,0.0,1.0) : black;

  // Sphere Mapping
  if (use_sphere_map){
    vec4 view_normal_matrix = normalize((uniform_camera_view_matrix * vec4(N, 0.0)));
    vec2 sphere_map_tex_coord = view_normal_matrix.xy * 0.5 + 0.5;
    vec4 sphere_map_color = sphere_map_is_sRGB ? sRGB2linear(texture(sphere_map_tex, sphere_map_tex_coord)) : texture(sphere_map_tex, sphere_map_tex_coord);
    vec3 sphere_map = sphere_map_blend_mode == BlendingMode_LinearDodge ? color + sphere_map_color.xyz
    : sphere_map_blend_mode == BlendingMode_Multiply ? color * sphere_map_color.xyz
    : sphere_map_blend_mode == BlendingMode_Normal ? sphere_map_color.xyz
    : color;
    color = sphere_map;
  }

  // 両面を描画する
  //: state cull_face off

  // アルファブレンドを有効にする
  //: state blend over

  vec3 shadow = vec3(getShadowFactor());
  
  float alpha = getOpacity(opacity_tex, inputs.sparse_coord);

  alphaOutput(alpha);
  diffuseShadingOutput((color+high_light+rim_light)*shadow);
  emissiveColorOutput(pbrComputeEmissive(emissive_tex, inputs.sparse_coord));
}
