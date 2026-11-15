// WetDroplets.shader
// 표면에 물방울이 맺힌 모습을 그리는 셰이더 (HLSL)
//
// 동작 순서
//   1. 칸 나누기  : 월드 위치를 3D 칸으로 나눈다.
//   2. 물방울 놓기: 칸마다 작은 공(물방울) 하나를 놓는다. 표면이 그 공을 지나가는 곳이 물방울로 보인다.
//   3. 바탕 조명  : 빛을 받는 정도(법선과 빛 방향의 내적) + 주변광으로 바탕을 칠한다. 그림자도 받는다.
//   4. 반짝임     : 물방울 법선으로 햇빛 반짝임을 계산해 더한다.

Shader "MyShaders/WetDroplets"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _DropletDensity ("Droplet Density", Range(2, 60)) = 18
        _DropletSize ("Droplet Size", Range(0.05, 0.3)) = 0.25
        _DropletCoverage ("Droplet Coverage", Range(0, 1)) = 0.8
        _DropletDarkening ("Droplet Darkening", Range(0, 1)) = 0.3
        _DropletGlint ("Droplet Glint", Range(0, 10)) = 3
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "WetDroplets"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE   // 그림자를 받기 위한 키워드
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _DropletDensity;
                float _DropletSize;
                float _DropletCoverage;
                half  _DropletDarkening;
                half  _DropletGlint;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                return output;
            }

            // 3D 좌표를 넣으면 0~1 랜덤 값 3개를 돌려준다
            float3 Hash33(float3 p)
            {
                p = frac(p * float3(0.1031, 0.1030, 0.0973));
                p += dot(p, p.yxz + 33.33);
                return frac((p.xxy + p.yxx) * p.zyx);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float3 n = normalize(input.normalWS);                                // 표면 법선
                float3 V = normalize(_WorldSpaceCameraPos - input.positionWS);       // 카메라 쪽 방향

                // 1. 칸 나누기
                float3 p = input.positionWS * _DropletDensity;
                float3 cell = floor(p);
                float3 rnd = Hash33(cell);                                           // 칸마다 다른 랜덤 값

                // 2. 물방울 놓기: 칸 가운데쯤에 공 하나. 반지름이 0.3 이하라 칸 밖으로 넘치지 않는다
                float3 center = cell + 0.3 + 0.4 * rnd;
                float  radius = _DropletSize * (0.6 + 0.4 * rnd.x);                  // 물방울마다 크기가 다르다
                float3 d = p - center;
                float  mask = 1.0 - smoothstep(radius * 0.5, radius, length(d));     // 물방울 안 1, 밖 0 (가장자리는 부드럽게)
                mask *= step(rnd.y, _DropletCoverage);                               // 일부 칸에만 물방울을 둔다

                // 물방울 법선: 가운데에서 바깥으로 갈수록 법선을 바깥쪽으로 기울여 볼록하게 보이게 한다
                float3 t = d - n * dot(d, n);                                        // 표면을 따라 잰 방향 (가운데 -> 이 픽셀)
                float3 dropN = normalize(n + t / radius * mask);

                // 3. 바탕 조명
                Light light = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float lit = saturate(dot(n, light.direction)) * light.shadowAttenuation;   // 빛을 받는 정도 (그림자 속이면 0)
                half3 baseColor = _BaseColor.rgb * (1.0 - _DropletDarkening * mask);       // 젖은 곳은 조금 어둡게
                half3 color = baseColor * (SampleSH(n) + light.color * lit);

                // 4. 반짝임: 햇빛 반짝임 (블린-퐁)
                float3 H = normalize(light.direction + V);
                float  glint = pow(saturate(dot(dropN, H)), 256.0) * lit;
                color += mask * light.color * glint * _DropletGlint;

                return half4(color, 1.0);
            }
            ENDHLSL
        }

        // 그림자와 깊이는 URP 기본 Lit 셰이더의 패스를 그대로 빌려 쓴다
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
        UsePass "Universal Render Pipeline/Lit/DEPTHONLY"
        UsePass "Universal Render Pipeline/Lit/DEPTHNORMALS"
    }
}
