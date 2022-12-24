// Adapted from https://godotshaders.com/shader/green-screen-chromakey/ by BlueMoon_Coder

#pragma shaderfilter set key_color__description Key Color
#pragma shaderfilter set key_color__default 7FFF00FF
uniform float4 key_color;
#pragma shaderfilter set similarity__min 0
uniform int similarity = 40;
#pragma shaderfilter set smoothness__min 0
uniform int smoothness = 8;
#pragma shaderfilter set spill__min 0
uniform int spill = 10;
uniform int bias = 0;
#pragma shaderfilter set luma__min 0
uniform int luma = 0;
#pragma shaderfilter set p__min 1
uniform float p = 1.5;
#pragma shaderfilter set mode__min 0
#pragma shaderfilter set mode__max 3
#pragma shaderfilter set mode__default 3
#pragma shaderfilter set mode__description Mode: 0=Off,1=YUV,2=YCoCg,3=YPbPr
uniform int mode = 2;

// from wikipedia
float3 RGB2YCoCg(float3 c) {
  return float3(
       c.r / 4 + c.g / 2 + c.b / 4,
       c.r / 2           - c.g / 2,
      -c.r / 4 + c.g / 2 - c.b / 4
  );
}

float3 mix(float3 rgbA, float3 rgbB, float frac) {
  return rgbA + (rgbB - rgbA) * frac;
}

// same as OBS's Filter
float3 RGB2YUV(float3 rgb) {
    return float3(
    rgb.x * -0.100644 + rgb.y * -0.338572 + rgb.z *  0.439216 + 0.501961,
    rgb.x *  0.439216 + rgb.y * -0.398942 + rgb.z * -0.040274 + 0.501961,
    rgb.x *  0.182586 + rgb.y *  0.614231 + rgb.z *  0.062007 + 0.062745
  );
}

float RGB2YPbPrY(float3 rgb) {
    return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

float3 RGB2YPbPr(float3 rgb) {
    float y = RGB2YPbPrY(rgb);
    return float3(y, rgb.b - y, rgb.r - y);
}

float4 render(float2 texCoord) {
  float4 rgba = image.Sample(builtin_texture_sampler, texCoord);
  float bexp = exp(bias * 0.001);
  float3 bias = float3(luma * 0.001, bexp, 1/bexp);
  float3 xyz = rgba.rgb;
  float3 diff = bias;
  if (mode == 1) {
    xyz = RGB2YUV(xyz);
    diff *= (xyz - RGB2YUV(key_color.xyz));
  }
  if (mode == 2) {
    xyz = RGB2YCoCg(xyz);
    diff *= (xyz - RGB2YCoCg(key_color.xyz));
  }
  if (mode == 3) {
    xyz = RGB2YPbPr(xyz);
    diff *= (xyz - RGB2YPbPr(key_color.xyz));
  }
  float chromaDist = sqrt(dot(diff, diff));

  float baseMask = chromaDist - similarity * 0.001;
  float fullMask = pow(clamp(baseMask / smoothness * 1000, 0., 1.), p);
  rgba.a = fullMask;

  float spillVal = pow(clamp(baseMask / spill * 1000, 0., 1.), p);
  float desat = clamp(xyz.x, 0., 1.);
  rgba.xyz = mix(float3(desat, desat, desat), rgba.xyz, spillVal);

  if (mode == 0) {
    rgba.a = 1;
  }
  return rgba;
}

