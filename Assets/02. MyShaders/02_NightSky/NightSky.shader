// NightSky.shader
// 별이 반짝이는 밤하늘 스카이박스 셰이더 (HLSL)
// Window > Rendering > Lighting > Environment > Skybox Material 에 NightSky.mat 을 넣어 쓴다.
//
// 동작 순서
//   1. 하늘 방향   : 스카이박스 메시의 정점 위치를 그대로 "하늘을 바라보는 방향"으로 쓴다.
//   2. 하늘 그라데이션: 방향의 높이(y)로 수평선 색 -> 꼭대기 색을 섞는다.
//   3. 별 놓기     : 방향에 Star Density 를 곱해 3D 칸으로 나누고, 칸마다 해시로 별이 있을지, 어디에 있을지 정한다.
//   4. 반짝임      : 별마다 다른 속도와 시작점으로 sin 을 돌려 밝기가 오르내리게 한다.

Shader "MyShaders/NightSky"
{
    Properties
    {
        _TopColor ("Top Color", Color) = (0.01, 0.02, 0.08, 1)
        _HorizonColor ("Horizon Color", Color) = (0.08, 0.12, 0.3, 1)
        _StarDensity ("Star Density", Range(20, 300)) = 120
        _StarAmount ("Star Amount", Range(0, 1)) = 0.35
        _StarSize ("Star Size", Range(0.02, 0.25)) = 0.15
        _StarBrightness ("Star Brightness", Range(0, 10)) = 3
        _TwinkleSpeed ("Twinkle Speed", Range(0, 10)) = 3
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Background"
            "RenderType" = "Background"
            "RenderPipeline" = "UniversalPipeline"
            "PreviewType" = "Skybox"
        }
        Cull Off
        ZWrite Off

        Pass
        {
            Name "NightSky"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _TopColor;
                half4 _HorizonColor;
                float _StarDensity;
                float _StarAmount;
                float _StarSize;
                half  _StarBrightness;
                float _TwinkleSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 direction  : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.direction = input.positionOS.xyz;    // 1. 하늘 방향
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
                float3 dir = normalize(input.direction);

                // 2. 하늘 그라데이션: 수평선 색 -> 꼭대기 색 (수평선 아래는 수평선 색 그대로)
                half3 sky = lerp(_HorizonColor.rgb, _TopColor.rgb, sqrt(saturate(dir.y)));

                // 3. 별 놓기: 방향을 3D 칸으로 나누고 칸마다 별 하나를 랜덤한 자리에 둔다
                float3 p = dir * _StarDensity;
                float3 cell = floor(p);
                float3 rnd = Hash33(cell);                                    // 칸마다 다른 랜덤 값
                float3 starPos = cell + 0.25 + 0.5 * Hash33(cell + 19.19);   // 칸 안 아무 곳 (가장자리 25% 는 비움)
                float  star = 1.0 - smoothstep(_StarSize * 0.3, _StarSize, length(p - starPos));
                star *= step(rnd.x, _StarAmount);                             // Star Amount 비율의 칸에만 별이 있다
                star *= smoothstep(0.0, 0.15, dir.y);                         // 수평선 아래에는 별이 없다

                // 4. 반짝임: 별마다 속도(rnd.y)와 시작점(rnd.z)이 달라 제각각 깜빡인다
                float twinkle = 0.55 + 0.45 * sin(_Time.y * _TwinkleSpeed * (0.5 + rnd.y) + rnd.z * 6.2831853);

                half3 color = sky + star * twinkle * _StarBrightness;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
