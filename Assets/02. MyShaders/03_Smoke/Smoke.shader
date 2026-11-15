// Smoke.shader
// 밑에서 위로 아지랑이처럼 일렁이며 피어오르는 연기 셰이더 (HLSL)
// 세워 둔 Quad 한 장에 Smoke.mat 을 넣어 쓴다. UV 의 아래(y=0)가 바닥, 위(y=1)가 꼭대기다.
//
// 동작 순서
//   1. sin 파 흔들림 : 높이(uv.y)와 시간으로 sin 값을 구해 연기를 좌우로 흔든다.
//                     물결이 위로 흘러가고, 위로 갈수록 흔들림이 커진다.
//   2. 피어오르는 노이즈: 노이즈를 시간에 따라 위로 흘린다. 세로로 늘인 노이즈라 연기 결이 위아래로 길다.
//   3. 연기 기둥 모양: 가운데에서 멀수록 옅게 하고, 위로 갈수록 넓게 퍼진다.
//                     바닥에서는 서서히 나타나고 꼭대기로 갈수록 사라진다.
//   4. 색과 투명도  : 연기 색 한 가지로 칠하고, 진한 정도를 투명도로 쓴다.

Shader "MyShaders/Smoke"
{
    Properties
    {
        _SmokeColor ("Smoke Color", Color) = (0.85, 0.85, 0.88, 1)
        _Opacity ("Opacity", Range(0, 1)) = 0.7
        _RiseSpeed ("Rise Speed", Range(0, 2)) = 0.35
        _NoiseScale ("Noise Scale", Range(1, 10)) = 4
        _ColumnWidth ("Column Width", Range(0.05, 0.5)) = 0.28
        _WaveAmplitude ("Wave Amplitude", Range(0, 0.3)) = 0.08
        _WaveFrequency ("Wave Frequency", Range(0, 5)) = 1.5
        _WaveSpeed ("Wave Speed", Range(0, 10)) = 3
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            Name "Smoke"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _SmokeColor;
                half  _Opacity;
                float _RiseSpeed;
                float _NoiseScale;
                float _ColumnWidth;
                float _WaveAmplitude;
                float _WaveFrequency;
                float _WaveSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            // 2D 좌표를 넣으면 0~1 랜덤 값 하나를 돌려준다
            float Hash21(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            // 값 노이즈: 격자 네 꼭짓점의 랜덤 값을 부드럽게 섞는다
            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = Hash21(i);
                float b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1));
                float d = Hash21(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;

                // 1. sin 파 흔들림: 물결이 위로 흘러가고, 위로 갈수록 크게 흔들린다
                float wave = sin(uv.y * _WaveFrequency * 6.2831853 - _Time.y * _WaveSpeed) * _WaveAmplitude * uv.y;
                float x = uv.x - 0.5 + wave;                    // 연기 기둥 가운데로부터의 가로 거리

                // 2. 피어오르는 노이즈: 위로 흘리고(y - 시간), 세로로 늘인다(y 에 0.4 를 곱함)
                float2 p = float2(x * _NoiseScale, (uv.y - _Time.y * _RiseSpeed) * _NoiseScale * 0.4);
                float noise = ValueNoise(p) * 0.6 + ValueNoise(p * 2.1) * 0.4;

                // 3. 연기 기둥 모양
                float width  = _ColumnWidth * lerp(0.4, 1.0, uv.y);                   // 위로 갈수록 넓어진다
                float column = 1.0 - smoothstep(0.0, width, abs(x));                  // 가운데가 진하다
                float fade   = sin(uv.y * 3.14159);                                    // 바닥과 꼭대기에서 0, 가운데에서 1
                fade *= 1.0 - smoothstep(0.4, 0.5, abs(uv.x - 0.5));                  // Quad 좌우 끝에서도 사라진다 (일자로 잘리지 않게)
                float density = column * fade * noise;

                // 4. 색과 투명도: 진한 곳일수록 불투명하다
                half alpha = saturate(density * 1.6) * _Opacity * _SmokeColor.a;
                return half4(_SmokeColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
