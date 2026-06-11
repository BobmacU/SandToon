    //-------------------------------------------------------------------------------------------------
    // Geometry Shader — Fur, Outlines, and Shared Vertex Helpers
    //-------------------------------------------------------------------------------------------------
    // Owns all GS-emitted geometry: base mesh passthrough, fur shell strips, and outline shell.
    // Fur helpers are declared first because InitializeGeneratedPixelInput and AppendFurPoint
    // are shared dependencies used by both the fur and outline emission paths.
    //-------------------------------------------------------------------------------------------------

    //-------------------------------------------------------------------------------------------------
    // Fur Geometry Declarations
    //-------------------------------------------------------------------------------------------------
    #if S_SHADING_MODE == 5
    SamplerState g_sFurVectorSampler < Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
    CreateInputTexture2D(FurNormalMap, Linear, 8, "NormalizeNormals", "_furnormal", "Fur Shading,10/Fur Normal Map,20/1", DefaultFile( "BoBiCo Shader/Textures/Normals/FlatNormal.png"));
    Texture2D FurNormalTexture < Channel(RGBA, Box(FurNormalMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float2 FurNormalTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Fur Shading,10/Fur Normal Map,20/2"); >;
    float2 FurNormalOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Fur Shading,10/Fur Normal Map,20/3"); >;
    float FurNormalMapIntensity < UiType(Slider); Range(-5.0, 5.0); Default1(1.0); UiGroup("Fur Shading,10/Fur Settings,50/2"); >;
    float3 FurDirection < UiType(Slider); Range3(-1.0, -1.0, -1.0, 1.0, 1.0, 1.0); Default3(0.0, 0.0, 1.0); UiGroup("Fur Shading,10/Fur Settings,50/3"); >;
    float FurLength < UiType(Slider); Range(0.0, 1.0); Default1(0.05); UiGroup("Fur Shading,10/Fur Settings,50/4"); >;
    float FurGravity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Fur Shading,10/Fur Settings,50/5"); >;
    float FurRandomize < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Fur Shading,10/Fur Settings,50/6"); >;
    int FurLayerCounts < UiType(Slider); Range(0, 3); Default(2); UiGroup("Fur Shading,10/Fur Settings,50/1"); >;
    #endif

    //-------------------------------------------------------------------------------------------------
    // Generated Vertex Helpers
    //-------------------------------------------------------------------------------------------------
    PixelInput InitializeGeneratedPixelInput( PixelInput v, float3 worldPosition, float isOutline, float furLayer, float furShell )
    {
        // All GS-generated vertices go through the same finalizer so engine-provided pixel inputs stay valid.
        v.vPositionWs = worldPosition;
        v.vPositionPs = Position3WsToPs( worldPosition );
        if ( isOutline > 0.5 )
        {
            v.vPositionPs.z -= OutlineZBias * 0.15 * v.vPositionPs.w;
        }
        v.isOutline = isOutline;
        v.furLayer = furLayer;
        v.furShell = furShell;
        return FinalizeVertex( v );
    }

    //-------------------------------------------------------------------------------------------------
    // Fur Geometry Helpers
    //-------------------------------------------------------------------------------------------------
    float LerpFurScalar( float a, float b, float c, float3 factor )
    {
        // Barycentric interpolation helper used when fur emits extra strip points.
        return a * factor.x + b * factor.y + c * factor.z;
    }

    float2 LerpFurFloat2( float2 a, float2 b, float2 c, float3 factor )
    {
        return a * factor.x + b * factor.y + c * factor.z;
    }

    float3 LerpFurFloat3( float3 a, float3 b, float3 c, float3 factor )
    {
        return a * factor.x + b * factor.y + c * factor.z;
    }

    float4 LerpFurFloat4( float4 a, float4 b, float4 c, float3 factor )
    {
        return a * factor.x + b * factor.y + c * factor.z;
    }

    #if S_SHADING_MODE == 5
    float3 SafeNormalizeFurVector( float3 value, float3 fallback )
    {
        float lengthSq = dot( value, value );
        return lengthSq > 0.00001 ? value * rsqrt( lengthSq ) : fallback;
    }

    float3 BuildFurFallbackTangent( float3 normalWs )
    {
        float3 upWs = abs( normalWs.z ) < 0.999 ? float3( 0.0, 0.0, 1.0 ) : float3( 0.0, 1.0, 0.0 );
        return SafeNormalizeFurVector( cross( upWs, normalWs ), float3( 1.0, 0.0, 0.0 ) );
    }

    float MapFurVectorIntensityToStrengthGs( float intensity )
    {
        // Signed and linear: negative values flip strand steering, positive values strengthen it.
        return intensity * 0.8;
    }

    float3 DecodeFurVectorMapSampleGs( float3 packedNormal, float strength )
    {
        float3 tangentNormal = packedNormal * 2.0 - 1.0.xxx;
        tangentNormal.xy *= strength;
        tangentNormal.z = sqrt( saturate( 1.0 - min( dot( tangentNormal.xy, tangentNormal.xy ), 1.0 ) ) );
        return normalize( float3( tangentNormal.xy, max( tangentNormal.z, 1e-5 ) ) );
    }

    float3 BlendFurTangentVectorGs( float3 baseVectorTs, float3 detailVectorTs )
    {
        return float3( baseVectorTs.xy + detailVectorTs.xy, baseVectorTs.z * detailVectorTs.z );
    }

    float3 BuildFurRandomVectorFromHash( uint3 hashed )
    {
        float3 randomVector = float3(hashed) * ( 2.0 / 4294967295.0 ) - 1.0.xxx;
        float randomLengthSq = dot(randomVector, randomVector);
        return randomLengthSq > 0.00001 ? randomVector * rsqrt(randomLengthSq) : float3(0.0, 0.0, 1.0);
    }

    float3 BuildFurTriangleRandomVector( float dominantSeed, float seedB, float seedC )
    {
        // Mix the triangle's vertex IDs before randomizing.
        uint mixedSeed = (uint)dominantSeed * 3U + (uint)seedB + (uint)seedC;
        uint3 hashed = mixedSeed * uint3( 1597334677U, 3812015801U, 2912667907U );
        return BuildFurRandomVectorFromHash( hashed );
    }

    float GetFurLengthValue()
    {
        // Match lilToon's fur-length scale while keeping the slider continuous across the full range.
        float FurLength01 = saturate( FurLength );
        float boostedLength = FurLength * 15.0;
        return boostedLength * lerp( 1.0, 1.5, FurLength01 );
    }

    PixelInput InterpolateFurPixelInput( PixelInput p1, PixelInput p2, PixelInput p3, float3 factor )
    {
        // Build an interpolated root vertex for shell strips. The tip is added in AppendFurPoint().
        PixelInput result = p1;
        result.vPositionWs = LerpFurFloat3( p1.vPositionWs, p2.vPositionWs, p3.vPositionWs, factor );
        float3 interpolatedNormalWs = SafeNormalizeFurVector( LerpFurFloat3( p1.vNormalWs, p2.vNormalWs, p3.vNormalWs, factor ), float3( 0.0, 0.0, 1.0 ) );
        float3 interpolatedTangentUWs = LerpFurFloat3( p1.vTangentUWs, p2.vTangentUWs, p3.vTangentUWs, factor );
        interpolatedTangentUWs -= interpolatedNormalWs * dot( interpolatedTangentUWs, interpolatedNormalWs );
        interpolatedTangentUWs = SafeNormalizeFurVector( interpolatedTangentUWs, BuildFurFallbackTangent( interpolatedNormalWs ) );
        float3 interpolatedTangentVWs = LerpFurFloat3( p1.vTangentVWs, p2.vTangentVWs, p3.vTangentVWs, factor );
        interpolatedTangentVWs -= interpolatedNormalWs * dot( interpolatedTangentVWs, interpolatedNormalWs );
        interpolatedTangentVWs = SafeNormalizeFurVector( interpolatedTangentVWs, SafeNormalizeFurVector( cross( interpolatedNormalWs, interpolatedTangentUWs ), float3( 0.0, 1.0, 0.0 ) ) );
        result.vNormalWs = interpolatedNormalWs;
        result.vTextureCoords = LerpFurFloat4( p1.vTextureCoords, p2.vTextureCoords, p3.vTextureCoords, factor );
        result.vLightmapUV = LerpFurFloat2( p1.vLightmapUV, p2.vLightmapUV, p3.vLightmapUV, factor );
        result.vTangentUWs = interpolatedTangentUWs;
        result.vTangentVWs = interpolatedTangentVWs;
        result.furRandomSeed = LerpFurScalar( p1.furRandomSeed, p2.furRandomSeed, p3.furRandomSeed, factor );
        result.furLengthMask = LerpFurScalar( p1.furLengthMask, p2.furLengthMask, p3.furLengthMask, factor );
        result.isOutline = 0.0;
        result.furLayer = -2.0;
        result.furShell = 0.0;
        return result;
    }

    void AppendFurPoint( inout TriangleStream<PixelInput> stream, PixelInput p1, PixelInput p2, PixelInput p3, float3 furVector1, float3 furVector2, float3 furVector3, float3 factor )
    {
        // Each point appends root and tip vertices. Interpolated furLayer gives the pixel shader its shell gradient.
        PixelInput rootVertex = InterpolateFurPixelInput( p1, p2, p3, factor );
        float3 rootPositionWs = rootVertex.vPositionWs;
        float3 furVectorWs = LerpFurFloat3( furVector1, furVector2, furVector3, factor );
        stream.Append( InitializeGeneratedPixelInput( rootVertex, rootPositionWs, 0.0, 0.0, 1.0 ) );
        stream.Append( InitializeGeneratedPixelInput( rootVertex, rootPositionWs + furVectorWs, 0.0, 1.0, 1.0 ) );
    }

    float3 ComputeFurVectorWs( PixelInput v, float furLengthValue, float3 furDirectionBaseTs, float furNormalMapStrength )
    {
        // Fur Direction is the stable base strand direction. Fur Normal Map adds local strand bend on top of it.
        float3 tangentUWs = normalize( v.vTangentUWs );
        float3 tangentVWs = normalize( v.vTangentVWs );
        float3 normalWs = normalize( v.vNormalWs );
        float3 furDirectionTs = furDirectionBaseTs;
        float2 furNormalUv = v.vTextureCoords.xy * FurNormalTiling + FurNormalOffset;
        float3 furVectorMapTs = DecodeFurVectorMapSampleGs( FurNormalTexture.SampleLevel( g_sFurVectorSampler, furNormalUv, 0 ).rgb, furNormalMapStrength );
        furDirectionTs = BlendFurTangentVectorGs( furDirectionTs, furVectorMapTs );
        float furDirectionLengthSq = dot( furDirectionTs, furDirectionTs );
        furDirectionTs = furDirectionLengthSq > 0.00001 ? furDirectionTs * rsqrt( furDirectionLengthSq ) : float3( 0.0, 0.0, 1.0 );
        float3 furVectorWs = normalize( tangentVWs * furDirectionTs.x + tangentUWs * furDirectionTs.y + normalWs * furDirectionTs.z );
        furVectorWs *= furLengthValue;

        // lilToon subtracts world Y because Unity is Y-up. In s&box, Z is up so we subtract from Z instead.
        furVectorWs.z -= FurGravity * furLengthValue;
        return furVectorWs;
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Geometry Shader Entry Point
    //-------------------------------------------------------------------------------------------------
    [maxvertexcount(32)]
    void MainGs( triangle PixelInput vertices[3], inout TriangleStream<PixelInput> stream )
    {
        PixelInput p1 = vertices[0];
        PixelInput p2 = vertices[1];
        PixelInput p3 = vertices[2];

        // Emit the original mesh first; optional fur and outline geometry are appended below.
        stream.Append( InitializeGeneratedPixelInput( p1, p1.vPositionWs, 0.0, -2.0, 0.0 ) );
        stream.Append( InitializeGeneratedPixelInput( p2, p2.vPositionWs, 0.0, -2.0, 0.0 ) );
        stream.Append( InitializeGeneratedPixelInput( p3, p3.vPositionWs, 0.0, -2.0, 0.0 ) );
        stream.RestartStrip();

        // Fur geometry is emitted as additional points in the same pass. FurLayerCounts determines how many shell layers are emitted.
        #if S_SHADING_MODE == 5
        int furLayerCount = clamp( FurLayerCounts, 0, 3 );
        float furLengthValue = GetFurLengthValue();
        if ( furLayerCount > 0 && furLengthValue > 0.0001 )
        {
            float3 furDirectionBaseTs = FurDirection + float3( 0.0, 0.0, 0.001 );
            float furNormalMapStrength = MapFurVectorIntensityToStrengthGs( FurNormalMapIntensity );
            float3 furVector1 = ComputeFurVectorWs( p1, furLengthValue, furDirectionBaseTs, furNormalMapStrength );
            float3 furVector2 = ComputeFurVectorWs( p2, furLengthValue, furDirectionBaseTs, furNormalMapStrength );
            float3 furVector3 = ComputeFurVectorWs( p3, furLengthValue, furDirectionBaseTs, furNormalMapStrength );
            float furRandomScale = furLengthValue * FurRandomize;
            if ( furRandomScale > 0.00001 )
            {
                furVector1 += BuildFurTriangleRandomVector( p1.furRandomSeed, p2.furRandomSeed, p3.furRandomSeed ) * furRandomScale;
                furVector2 += BuildFurTriangleRandomVector( p2.furRandomSeed, p1.furRandomSeed, p3.furRandomSeed ) * furRandomScale;
                furVector3 += BuildFurTriangleRandomVector( p3.furRandomSeed, p1.furRandomSeed, p2.furRandomSeed ) * furRandomScale;
            }
            furVector1 *= saturate( p1.furLengthMask );
            furVector2 *= saturate( p2.furLengthMask );
            furVector3 *= saturate( p3.furLengthMask );

            if ( furLayerCount == 1 )
            {
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 0.0, 0.0 ) / 1.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 1.0, 0.0 ) / 1.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 0.0, 1.0 ) / 1.0 );
            }
            else if ( furLayerCount >= 2 )
            {
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 0.0, 0.0 ) / 1.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 1.0, 1.0 ) / 2.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 1.0, 0.0 ) / 1.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 0.0, 1.0 ) / 2.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 0.0, 1.0 ) / 1.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 1.0, 0.0 ) / 2.0 );
            }
            if ( furLayerCount >= 3 )
            {
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 4.0, 1.0 ) / 6.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 0.0, 1.0, 1.0 ) / 2.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 1.0, 4.0 ) / 6.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 0.0, 1.0 ) / 2.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 4.0, 1.0, 1.0 ) / 6.0 );
                AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 1.0, 0.0 ) / 2.0 );
            }
            AppendFurPoint( stream, p1, p2, p3, furVector1, furVector2, furVector3, float3( 1.0, 0.0, 0.0 ) / 1.0 );
            stream.RestartStrip();
        }
        #endif

        #if !S_MODE_DEPTH
        // Emit the expanded outline shell.
        if ( OutlineEnabled && OutlineWidth > 0.0001 )
        {
            PixelInput o1 = p1;
            PixelInput o2 = p2;
            PixelInput o3 = p3;
            // Only pay for the 3x sqrt(length) when distance scaling is actually active.
            float outlineDistanceScale1 = 1.0;
            float outlineDistanceScale2 = 1.0;
            float outlineDistanceScale3 = 1.0;
            if ( OutlineFixWidthByDistance > 0.0001 )
            {
                float distanceToCamera1 = length( o1.vPositionWs - g_vCameraPositionWs );
                float distanceToCamera2 = length( o2.vPositionWs - g_vCameraPositionWs );
                float distanceToCamera3 = length( o3.vPositionWs - g_vCameraPositionWs );
                float outlineDistanceWeight1 = saturate( OutlineFixWidthByDistance * saturate( distanceToCamera1 / 120.0 ) );
                float outlineDistanceWeight2 = saturate( OutlineFixWidthByDistance * saturate( distanceToCamera2 / 120.0 ) );
                float outlineDistanceWeight3 = saturate( OutlineFixWidthByDistance * saturate( distanceToCamera3 / 120.0 ) );
                outlineDistanceScale1 = lerp( 1.0, 1.0 + distanceToCamera1 * 0.025, outlineDistanceWeight1 );
                outlineDistanceScale2 = lerp( 1.0, 1.0 + distanceToCamera2 * 0.025, outlineDistanceWeight2 );
                outlineDistanceScale3 = lerp( 1.0, 1.0 + distanceToCamera3 * 0.025, outlineDistanceWeight3 );
            }
            float outlineModeScale1 = 1.0;
            float outlineModeScale2 = 1.0;
            float outlineModeScale3 = 1.0;
            if ( OutlineMode > 0 )
            {
                float3 directionalLightColor = max(g_DirectionalLightColor.rgb, 0.0.xxx);
                float directionalLightStrength = max(directionalLightColor.x, max(directionalLightColor.y, directionalLightColor.z));
                if ( directionalLightStrength > 0.00001 )
                {
                    float3 sunDirectionWs = normalize(-g_DirectionalLightDirection.xyz);
                    float outlineFacing1 = saturate(dot(normalize(o1.vNormalWs), sunDirectionWs));
                    float outlineFacing2 = saturate(dot(normalize(o2.vNormalWs), sunDirectionWs));
                    float outlineFacing3 = saturate(dot(normalize(o3.vNormalWs), sunDirectionWs));
                    outlineModeScale1 = lerp(1.0, outlineFacing1, saturate(OutlineMode));
                    outlineModeScale2 = lerp(1.0, outlineFacing2, saturate(OutlineMode));
                    outlineModeScale3 = lerp(1.0, outlineFacing3, saturate(OutlineMode));
                }
            }

            o1.vPositionWs += normalize( o1.vNormalWs ) * OutlineWidth * 0.5 * outlineDistanceScale1 * outlineModeScale1;
            o2.vPositionWs += normalize( o2.vNormalWs ) * OutlineWidth * 0.5 * outlineDistanceScale2 * outlineModeScale2;
            o3.vPositionWs += normalize( o3.vNormalWs ) * OutlineWidth * 0.5 * outlineDistanceScale3 * outlineModeScale3;

            stream.Append( InitializeGeneratedPixelInput( o3, o3.vPositionWs, 1.0, -2.0, 0.0 ) );
            stream.Append( InitializeGeneratedPixelInput( o1, o1.vPositionWs, 1.0, -2.0, 0.0 ) );
            stream.Append( InitializeGeneratedPixelInput( o2, o2.vPositionWs, 1.0, -2.0, 0.0 ) );
            stream.RestartStrip();
        }
        #endif
    }
