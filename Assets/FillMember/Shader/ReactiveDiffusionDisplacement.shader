﻿Shader "Hidden/FillMember/ReactiveDiffusionDisplacement"
{
	Properties
	{

		_MainTex("", 2D) = "" {}
		_rdTex("", 2D) = "red" {}
		_workBuffer("", 2D) = "black" {}
		_motionBuffer("", 2D) = "black" {}

	}

	CGINCLUDE

	#include "UnityCG.cginc"

	sampler2D _MainTex;
	float4 _MainTex_TexelSize;

	sampler2D _rdTex;
	float4 _rdTex_TexelSize;

	sampler2D _workBuffer;
	float4 _workBuffer_TexelSize;

	sampler2D _motionBuffer;
	float4 _motionBuffer_TexelSize;

	float texelSize;

	float feedRate;
	float killRate;

	float decayRate;

	// Motion Vector
	sampler2D_half _CameraMotionVectorsTexture;
	float4 _CameraMotionVectorsTexture_TexelSize;

	// Vertex Shader

	struct v2f {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};

	v2f vert(appdata_full v) {

		v2f o;

		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = v.texcoord.xy;
		
	#if UNITY_UV_STARTS_AT_TOP
		if (_MainTex_TexelSize.y < 0.0) {
			o.uv.y = 1.0 - v.texcoord.y;
		}
	#endif

		return o;
	}

	// Fragment Shader

	float4 frag_rd(v2f source) : SV_Target {

		float2 v0 = tex2D( _rdTex , source.uv ).rg;
		float2 mv = tex2D( _CameraMotionVectorsTexture , source.uv ).rg;

		float laplaceFactor = lerp( 0.0 , 1.1 , length(mv) );
		float claplaceFactor = (1 - laplaceFactor) * 0.25;

		float2 laplace =
			+ laplaceFactor * tex2D( _rdTex , source.uv + mv ).rg
			+ claplaceFactor * (
				tex2D( _rdTex , source.uv + float2( -texelSize , 0.0 ) ).rg +
				tex2D( _rdTex , source.uv + float2( 0.0 , -texelSize ) ).rg +
				tex2D( _rdTex , source.uv + float2(  texelSize , 0.0 ) ).rg +
				tex2D( _rdTex , source.uv + float2( 0.0 ,  texelSize ) ).rg
			)
			- v0;

		float reaction = v0.r * v0.g * v0.g;
		float du = 1.0 * laplace.r - reaction + feedRate * ( 1.0 - v0.r );
		float dv = 0.5 * laplace.g + reaction - ( feedRate + killRate ) * v0.g;

		float2 dst = v0 + float2(du, dv) * 0.9;
		dst.g += min(0.5,length(mv));

		return float4( dst , mv.rg );

	}

	float4 frag_init(v2f source) : SV_Target {
		return float4(0, 0, 0, 0);
	}

	float4 frag_update(v2f source) : SV_Target {
		float2 mv = tex2D( _CameraMotionVectorsTexture , source.uv ).xy;
		float2 amv = tex2D( _motionBuffer , source.uv ).xy;
		return float4( (amv + mv) * decayRate , 0.0 , 1.0 );
	}

	float4 frag_disp_full(v2f source) : SV_Target {

		float2 uv = source.uv;
		float4 _rd = tex2D( _rdTex , uv );
		float4 _motion = tex2D( _motionBuffer , uv );
		float4 _main_disp = tex2D( _MainTex , uv + (_rd.ba + _motion.rg) * _rd.g );

		float4 _main = tex2D( _MainTex , uv );
		float4 _work = tex2D( _workBuffer , uv );
		float4 blend = lerp( _main , _work , 0.8 + _rd.g );

		return float4( lerp( blend , _main_disp , _rd.g ).rgb , 1.0 );

	}

	float4 frag_disp_distort(v2f source) : SV_Target {

		float2 uv = source.uv;
		float4 _rd = tex2D( _rdTex , uv );
		float4 _motion = tex2D( _motionBuffer , uv );
		float4 _main_disp = tex2D( _MainTex , uv + (_rd.ba + _motion.rg) * _rd.g );

		return float4( _main_disp.rgb , 1.0 );

	}

	ENDCG

	SubShader {

		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_init
			#pragma target 3.0
			ENDCG
		}

		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_rd
			#pragma target 3.0
			ENDCG
		}

		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_update
			#pragma target 3.0
			ENDCG
		}


		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_disp_distort
			#pragma target 3.0
			ENDCG
		}

		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode Off }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_disp_full
			#pragma target 3.0
			ENDCG
		}

	}

}
