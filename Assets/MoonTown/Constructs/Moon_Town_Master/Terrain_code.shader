shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 Color_A : hint_color;
uniform vec3 UVScale_Far;
uniform sampler2D Albedo_A;
uniform sampler2D Albedo_B;
uniform vec4 Color_B : hint_color;
uniform bool NoiseInvert;
uniform float NoiseIntensity;
uniform bool NoiseAlpha;
uniform bool NoiseZ;
uniform vec3 UVScale_Noise;
uniform sampler2D Noise_RGB;
uniform bool NoiseY;
uniform sampler2D Albedo_Far;
uniform vec4 Color_Far : hint_color;
uniform float DistanceLerp;
uniform float DistanceSmooth;
uniform vec3 Metallic_A_B_Far;
uniform sampler2D Rough_AO_A : hint_albedo;
uniform vec3 Rough_AO_Int;
uniform float roughness_multiplier;
uniform sampler2D Rough_AO_B : hint_albedo;
uniform sampler2D Rough_AO_Far : hint_albedo;
uniform vec3 Rough_AO_Far_Int;
uniform vec3 Specular_A_B_Far;
uniform float specular_multiplier;
uniform sampler2D NormalMap_A : hint_normal;
uniform float Normal_Int;
uniform sampler2D NormalMap_B : hint_normal;
uniform sampler2D NormalMap_Far : hint_normal;
uniform float Normal_Far_Int;
uniform float blend_sharpness;
uniform vec3 triplanar_scale;

// StochasticTriplanar

void TriangleGrid ( vec2 uv ,
out float w1 , out float w2 , out float w3 ,
out vec2 vertex1 , out vec2 vertex2 , out vec2 vertex3 )
{
// Scaling of the input
uv *= 3.464; // 2 * sqrt (3)
// Skew input space into simplex triangle grid
const mat2 gridToSkewedGrid = mat2 (vec2(1.0 , 0.0) , vec2(-0.57735027 , 1.15470054)) ;
vec2 skewedCoord = gridToSkewedGrid * uv ;
// Compute local triangle vertex IDs and local barycentric coordinates
ivec2 baseId = ivec2 ( floor ( skewedCoord ));
vec3 temp = vec3 ( fract ( skewedCoord ) , 0) ;
temp .z = 1.0 - temp . x - temp .y;
if ( temp . z > 0.0)
{
w1 = temp .z;
w2 = temp .y;
w3 = temp .x;
vertex1 = vec2(float(baseId.x), float(baseId.y)) ;
vertex2 = vertex1 + vec2 (0 , 1) ;
vertex3 = vertex1 + vec2 (1 , 0) ;
}
else
{
w1 = - temp .z ;
w2 = 1.0 - temp .y;
w3 = 1.0 - temp .x;
vertex1 = vec2(float(baseId.x), float(baseId.y)) + vec2 (1 , 1) ;
vertex2 = vec2(float(baseId.x), float(baseId.y)) + vec2 (1 , 0) ;
vertex3 = vec2(float(baseId.x), float(baseId.y)) + vec2 (0 , 1) ;
}
}
vec2 hash2D2D (vec2 s)
{
	//magic numbers
	return fract(sin(mod(vec2(dot(s, vec2(127.1,311.7)), dot(s, vec2(269.5,183.3))), 3.14159))*43758.5453);
}

vec3 ProceduralTilingAndBlending (sampler2D input,   vec2 uv )
{
// Get triangle info
float w1 , w2 , w3 ;
vec2 vertex1 , vertex2 , vertex3 ;
TriangleGrid (uv , w1 , w2 , w3 , vertex1 , vertex2 , vertex3 );
// Assign random offset to each triangle vertex
vec2 uv1 = uv + hash2D2D ( vertex1 );
vec2 uv2 = uv + hash2D2D ( vertex2 );
vec2 uv3 = uv + hash2D2D ( vertex3 );
// Precompute UV derivatives
vec2 duvdx = dFdx ( uv ) ;
vec2 duvdy = dFdy ( uv ) ;
// Fetch input
vec3 I1 = textureGrad ( input , uv1 , duvdx , duvdy ). rgb ;
vec3 I2 = textureGrad ( input , uv2 , duvdx , duvdy ). rgb ;
vec3 I3 = textureGrad ( input , uv3 , duvdx , duvdy ). rgb ;
// Variance - preserving blending
vec3 G;
vec3 I = w1 * I1 + w2 * I2 + w3 * I3 ;
G = I - vec3 (0.5) ;
G = G * inversesqrt ( w1 * w1 + w2 * w2 + w3 * w3 ) ;
G = G + vec3 (0.5) ;
vec3 grayXfer = vec3(0.3, 0.59, 0.11);
vec3 gray = vec3(dot(grayXfer, G));
G = mix(G, gray, 0.5);

return mix(I,G,0.4);
}
 
//stochastic sampling
vec4 textureStochastic(sampler2D tex, vec2 uv)
{
	//triangle vertices and blend weights
	//BW_vx[0...2].xyz = triangle verts
	//BW_vx[3].xy = blend weights (z is unused)
	mat4 BW_vx;
 
	//uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
	vec2 newUV = (mat2(vec2(1.0 , 0.0) , vec2(-0.57735027 , 1.15470054))* uv * 3.464);
 
	//vertex IDs and barycentric coords
	vec2 vxID = vec2 (floor(newUV));
	vec3 fracted = vec3 (fract(newUV), 0);
	fracted.z = 1.0-fracted.x-fracted.y;
 
	BW_vx = ((fracted.z>0.0) ?
		mat4(vec4(vxID, 0,0), vec4(vxID + vec2(0, 1), 0,0), vec4(vxID + vec2(1, 0), 0,0), vec4(fracted,0)) :
		mat4(vec4(vxID + vec2 (1, 1), 0,0), vec4(vxID + vec2 (1, 0), 0,0), vec4(vxID + vec2 (0, 1), 0,0), vec4(-fracted.z, 1.0-fracted.y, 1.0-fracted.x,0)));
 
	//calculate derivatives to avoid triangular grid artifacts
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);

	//blend samples with calculated weights
	return (textureGrad(tex, uv + hash2D2D(BW_vx[0].xy), dx, dy) * BW_vx[3].x +
		   textureGrad(tex, uv + hash2D2D(BW_vx[1].xy), dx, dy) * BW_vx[3].y +
		   textureGrad(tex, uv + hash2D2D(BW_vx[2].xy), dx, dy) * BW_vx[3].z);
	
}
vec4 STexComplexB(sampler2D input, vec2 uv){
	vec4 tex = vec4(ProceduralTilingAndBlending(input, uv.xy),1);
	tex = mix(tex, textureStochastic(input, uv.xy), 0.4);
	return tex;
}
vec4 STexComplexC(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= STexComplexB(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= STexComplexB(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= STexComplexB(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	
	return samp;
}

// NormalMultiply

vec3 NormalMultFunc(vec3 _Normal, float _Amount){
	return vec3(_Normal.x * _Amount, _Normal.y * _Amount, 1.0);
}

// GlobalExpression:0
varying vec3 uv1_power_normal;
varying vec3 triplanar_pos;
	

void vertex() {
// Input:3
	vec3 n_out3p0 = NORMAL;

// VectorFunc:14
	vec3 n_out14p0 = abs(n_out3p0);

// VectorDecompose:6
	float n_out6p0 = n_out14p0.x;
	float n_out6p1 = n_out14p0.y;
	float n_out6p2 = n_out14p0.z;

// VectorOp:7
	vec3 n_in7p0 = vec3(0.00000, 0.00000, -1.00000);
	vec3 n_out7p0 = n_in7p0 * vec3(n_out6p0);

// VectorOp:10
	vec3 n_in10p0 = vec3(1.00000, 0.00000, 0.00000);
	vec3 n_out10p0 = n_in10p0 * vec3(n_out6p1);

// VectorOp:8
	vec3 n_out8p0 = n_out7p0 + n_out10p0;

// VectorOp:12
	vec3 n_in12p0 = vec3(1.00000, 0.00000, 0.00000);
	vec3 n_out12p0 = n_in12p0 * vec3(n_out6p2);

// VectorOp:11
	vec3 n_out11p0 = n_out8p0 + n_out12p0;

// VectorFunc:15
	vec3 n_out15p0 = normalize(n_out11p0);

// VectorOp:20
	vec3 n_in20p0 = vec3(0.00000, -1.00000, 0.00000);
	vec3 n_out20p0 = n_in20p0 * vec3(n_out6p0);

// VectorOp:19
	vec3 n_in19p0 = vec3(0.00000, 0.00000, 1.00000);
	vec3 n_out19p0 = n_in19p0 * vec3(n_out6p1);

// VectorOp:21
	vec3 n_out21p0 = n_out20p0 + n_out19p0;

// VectorOp:16
	vec3 n_in16p0 = vec3(0.00000, -1.00000, 0.00000);
	vec3 n_out16p0 = n_in16p0 * vec3(n_out6p2);

// VectorOp:18
	vec3 n_out18p0 = n_out21p0 + n_out16p0;

// VectorFunc:17
	vec3 n_out17p0 = normalize(n_out18p0);

// Output:0
	uv1_power_normal=pow(abs(NORMAL),vec3(blend_sharpness));
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	triplanar_pos = VERTEX * triplanar_scale;
	triplanar_pos *= vec3(1.0,-1.0, 1.0);
	TANGENT = n_out15p0;
	BINORMAL = n_out17p0;

}

void fragment() {
// ColorUniform:14
	vec3 n_out14p0 = Color_A.rgb;
	float n_out14p1 = Color_A.a;

// Input:7
	vec3 n_out7p0 = vec3(UV, 0.0);

// VectorUniform:9
	vec3 n_out9p0 = UVScale_Far;

// VectorOp:11
	vec3 n_out11p0 = n_out7p0 * n_out9p0;

// TextureUniform:12
	vec3 n_out12p0;
	float n_out12p1;
	{
		vec4 n_tex_read = texture(Albedo_A, n_out11p0.xy);
		n_out12p0 = n_tex_read.rgb;
		n_out12p1 = n_tex_read.a;
	}

// Expression:98
	vec3 n_out98p0;
	n_out98p0 = vec3(0.0, 0.0, 0.0);
	{
		n_out98p0 = uv1_power_normal;
	}

// Expression:96
	vec3 n_out96p0;
	n_out96p0 = vec3(0.0, 0.0, 0.0);
	{
		n_out96p0 = triplanar_pos;
	}

// StochasticTriplanar:99
	vec3 n_out99p0;
	{
		n_out99p0 = STexComplexC(Albedo_A,uv1_power_normal,triplanar_pos).rgb;
	}

// VectorOp:16
	vec3 n_out16p0 = n_out14p0 * n_out99p0;

// TextureUniform:62
	vec3 n_out62p0;
	float n_out62p1;
	{
		vec4 n_tex_read = texture(Albedo_B, n_out11p0.xy);
		n_out62p0 = n_tex_read.rgb;
		n_out62p1 = n_tex_read.a;
	}

// StochasticTriplanar:97
	vec3 n_out97p0;
	{
		n_out97p0 = STexComplexC(Albedo_B,uv1_power_normal,triplanar_pos).rgb;
	}

// ColorUniform:63
	vec3 n_out63p0 = Color_B.rgb;
	float n_out63p1 = Color_B.a;

// VectorOp:64
	vec3 n_out64p0 = n_out97p0 * n_out63p0;

// BooleanUniform:68
	bool n_out68p0 = NoiseInvert;

// ScalarUniform:69
	float n_out69p0 = NoiseIntensity;

// BooleanUniform:76
	bool n_out76p0 = NoiseAlpha;

// BooleanUniform:77
	bool n_out77p0 = NoiseZ;

// Input:66
	vec3 n_out66p0 = vec3(UV, 0.0);

// VectorUniform:67
	vec3 n_out67p0 = UVScale_Noise;

// VectorOp:81
	vec3 n_out81p0 = n_out66p0 * n_out67p0;

// TextureUniform:80
	vec3 n_out80p0;
	float n_out80p1;
	{
		vec4 n_tex_read = texture(Noise_RGB, n_out81p0.xy);
		n_out80p0 = n_tex_read.rgb;
		n_out80p1 = n_tex_read.a;
	}

// VectorDecompose:79
	float n_out79p0 = n_out80p0.x;
	float n_out79p1 = n_out80p0.y;
	float n_out79p2 = n_out80p0.z;

// ScalarSwitch:75
	float n_out75p0;
	if(n_out77p0)
	{
		n_out75p0 = n_out80p1;
	}
	else
	{
		n_out75p0 = n_out79p2;
	}

// BooleanUniform:78
	bool n_out78p0 = NoiseY;

// ScalarSwitch:74
	float n_out74p0;
	if(n_out78p0)
	{
		n_out74p0 = n_out79p1;
	}
	else
	{
		n_out74p0 = n_out79p0;
	}

// ScalarSwitch:73
	float n_out73p0;
	if(n_out76p0)
	{
		n_out73p0 = n_out75p0;
	}
	else
	{
		n_out73p0 = n_out74p0;
	}

// ScalarOp:71
	float n_out71p0 = n_out69p0 * n_out73p0;

// ScalarClamp:70
	float n_in70p1 = 0.00000;
	float n_in70p2 = 1.00000;
	float n_out70p0 = clamp(n_out71p0, n_in70p1, n_in70p2);

// ScalarFunc:72
	float n_out72p0 = 1.0 - n_out70p0;

// ScalarSwitch:43
	float n_out43p0;
	if(n_out68p0)
	{
		n_out43p0 = n_out72p0;
	}
	else
	{
		n_out43p0 = n_out70p0;
	}

// VectorMix:65
	vec3 n_out65p0 = mix(n_out16p0, n_out64p0, vec3(n_out43p0));

// TextureUniform:13
	vec3 n_out13p0;
	float n_out13p1;
	{
		vec4 n_tex_read = texture(Albedo_Far, n_out11p0.xy);
		n_out13p0 = n_tex_read.rgb;
		n_out13p1 = n_tex_read.a;
	}

// ColorUniform:15
	vec3 n_out15p0 = Color_Far.rgb;
	float n_out15p1 = Color_Far.a;

// VectorOp:17
	vec3 n_out17p0 = n_out13p0 * n_out15p0;

// Scalar:84
	float n_out84p0 = 2.000000;

// VectorOp:83
	vec3 n_out83p0 = n_out17p0 / vec3(n_out84p0);

// VectorScalarMix:86
	float n_in86p2 = 0.70000;
	vec3 n_out86p0 = mix(n_out65p0, n_out83p0, n_in86p2);

// Input:6
	vec3 n_out6p0 = VERTEX;

// ScalarUniform:4
	float n_out4p0 = DistanceLerp;

// ScalarUniform:5
	float n_out5p0 = DistanceSmooth;

// Expression:3
	float n_out3p0;
	n_out3p0 = 0.0;
	{
		//Get distance to camera based on vertex
		n_out3p0 = clamp(smoothstep(n_out5p0, n_out4p0, -n_out6p0.z), 0.0, 1.0);
	}

// VectorMix:18
	vec3 n_out18p0 = mix(n_out86p0, n_out17p0, vec3(n_out3p0));

// VectorUniform:54
	vec3 n_out54p0 = Metallic_A_B_Far;

// VectorDecompose:56
	float n_out56p0 = n_out54p0.x;
	float n_out56p1 = n_out54p0.y;
	float n_out56p2 = n_out54p0.z;

// ScalarMix:58
	float n_out58p0 = mix(n_out56p0, n_out56p1, n_out43p0);

// ScalarMix:25
	float n_out25p0 = mix(n_out58p0, n_out56p2, n_out3p0);

// TextureUniform:20
	vec3 n_out20p0;
	float n_out20p1;
	{
		vec4 n_tex_read = texture(Rough_AO_A, UV.xy);
		n_out20p0 = n_tex_read.rgb;
		n_out20p1 = n_tex_read.a;
	}

// Expression:106
	vec3 n_out106p0;
	n_out106p0 = vec3(0.0, 0.0, 0.0);
	{
		
	}

// Expression:107
	vec3 n_out107p0;
	n_out107p0 = vec3(0.0, 0.0, 0.0);
	{
		
	}

// StochasticTriplanar:105
	vec3 n_out105p0;
	{
		n_out105p0 = STexComplexC(Rough_AO_A,uv1_power_normal,triplanar_pos).rgb;
	}

// VectorUniform:48
	vec3 n_out48p0 = Rough_AO_Int;

// VectorOp:51
	vec3 n_out51p0 = n_out105p0 * n_out48p0;

// TextureUniform:45
	vec3 n_out45p0;
	float n_out45p1;
	{
		vec4 n_tex_read = texture(Rough_AO_B, UV.xy);
		n_out45p0 = n_tex_read.rgb;
		n_out45p1 = n_tex_read.a;
	}

// StochasticTriplanar:104
	vec3 n_out104p0;
	{
		n_out104p0 = STexComplexC(Rough_AO_B,uv1_power_normal,triplanar_pos).rgb;
	}

// VectorOp:50
	vec3 n_out50p0 = n_out104p0 * n_out48p0;

// VectorMix:52
	vec3 n_out52p0 = mix(n_out51p0, n_out50p0, vec3(n_out43p0));

// TextureUniform:21
	vec3 n_out21p0;
	float n_out21p1;
	{
		vec4 n_tex_read = texture(Rough_AO_Far, n_out11p0.xy);
		n_out21p0 = n_tex_read.rgb;
		n_out21p1 = n_tex_read.a;
	}

// VectorUniform:47
	vec3 n_out47p0 = Rough_AO_Far_Int;

// VectorOp:49
	vec3 n_out49p0 = n_out21p0 * n_out47p0;

// VectorMix:53
	vec3 n_out53p0 = mix(n_out52p0, n_out49p0, vec3(n_out3p0));

// VectorDecompose:23
	float n_out23p0 = n_out53p0.x;
	float n_out23p1 = n_out53p0.y;
	float n_out23p2 = n_out53p0.z;

// VectorUniform:55
	vec3 n_out55p0 = Specular_A_B_Far;

// VectorDecompose:57
	float n_out57p0 = n_out55p0.x;
	float n_out57p1 = n_out55p0.y;
	float n_out57p2 = n_out55p0.z;

// ScalarMix:59
	float n_out59p0 = mix(n_out57p0, n_out57p1, n_out43p0);

// ScalarMix:26
	float n_out26p0 = mix(n_out59p0, n_out57p2, n_out3p0);

// TextureUniform:31
	vec3 n_out31p0;
	float n_out31p1;
	{
		vec4 n_tex_read = texture(NormalMap_A, UV.xy);
		n_out31p0 = n_tex_read.rgb;
		n_out31p1 = n_tex_read.a;
	}

// Expression:100
	vec3 n_out100p0;
	n_out100p0 = vec3(0.0, 0.0, 0.0);
	{
		
	}

// Expression:102
	vec3 n_out102p0;
	n_out102p0 = vec3(0.0, 0.0, 0.0);
	{
		
	}

// StochasticTriplanar:103
	vec3 n_out103p0;
	{
		n_out103p0 = STexComplexC(NormalMap_A,uv1_power_normal,triplanar_pos).rgb;
	}

// VectorFunc:109
	vec3 n_out109p0 = normalize(n_out103p0);

// ScalarUniform:35
	float n_out35p0 = Normal_Int;

// NormalMultiply:93
	vec3 n_out93p0;
	{
		n_out93p0 = NormalMultFunc(n_out109p0,n_out35p0);
	}

// TextureUniform:39
	vec3 n_out39p0;
	float n_out39p1;
	{
		vec4 n_tex_read = texture(NormalMap_B, UV.xy);
		n_out39p0 = n_tex_read.rgb;
		n_out39p1 = n_tex_read.a;
	}

// StochasticTriplanar:101
	vec3 n_out101p0;
	{
		n_out101p0 = STexComplexC(NormalMap_B,uv1_power_normal,triplanar_pos).rgb;
	}

// VectorFunc:108
	vec3 n_out108p0 = normalize(n_out101p0);

// NormalMultiply:94
	vec3 n_out94p0;
	{
		n_out94p0 = NormalMultFunc(n_out108p0,n_out35p0);
	}

// VectorMix:41
	vec3 n_out41p0 = mix(n_out93p0, n_out94p0, vec3(n_out43p0));

// TextureUniform:32
	vec3 n_out32p0;
	float n_out32p1;
	{
		vec4 n_tex_read = texture(NormalMap_Far, n_out11p0.xy);
		n_out32p0 = n_tex_read.rgb;
		n_out32p1 = n_tex_read.a;
	}

// ScalarUniform:36
	float n_out36p0 = Normal_Far_Int;

// NormalMultiply:95
	vec3 n_out95p0;
	{
		n_out95p0 = NormalMultFunc(n_out32p0,n_out36p0);
	}

// VectorMix:33
	vec3 n_out33p0 = mix(n_out41p0, n_out95p0, vec3(n_out3p0));

// Scalar:110
	float n_out110p0 = 0.500000;

// Output:0
	ALBEDO = n_out18p0;
	METALLIC = n_out25p0;
	ROUGHNESS = roughness_multiplier*n_out23p0;
	SPECULAR = specular_multiplier*n_out26p0;
	AO = n_out23p1;
	NORMALMAP = n_out33p0;
	NORMALMAP_DEPTH = n_out110p0;
	//SSS_STRENGTH = 1.0;
}

void light() {
// Output:0

}
