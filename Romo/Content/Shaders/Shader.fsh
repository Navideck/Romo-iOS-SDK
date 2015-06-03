uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;

varying highp vec2 texCoordVarying;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    yuv.x = texture2D(SamplerY, texCoordVarying).r;
    yuv.yz = texture2D(SamplerUV, texCoordVarying).rg - vec2(0.5, 0.5);
    rgb = mat3(      1,       1,      1,
                     0, -.18732, 1.8556,
               1.57481, -.46813,      0) * yuv;
    gl_FragColor = vec4(rgb, 1);
}

