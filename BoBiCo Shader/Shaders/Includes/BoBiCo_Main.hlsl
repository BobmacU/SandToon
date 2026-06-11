    //-------------------------------------------------------------------------------------------------
    // BoBiCo Shading Model and main functions.
    //-------------------------------------------------------------------------------------------------
    // Included inside the PS block. This file owns final output, direct/indirect lighting, and MainPs.
    //-------------------------------------------------------------------------------------------------
    // Final output model for BoBiCo's already-built toon color. This keeps the
    // engine output plumbing, but skips Standard's hidden lighting pass.
    class ShadingModelBoBiCo
    {
        static float4 Shade(Material m, float4 color)
        {
            Decals::Apply(m.WorldPosition, m);
            AdjustAlphaToCoverage(m);
            color.a = m.Opacity;

            if (DepthNormals::WantsDepthNormals())
            {
                return DepthNormals::Output(m.Normal, m.Roughness, color.a);
            }

            if (ToolsVis::WantsToolsVis())
            {
                LightingTerms_t lightingTerms = InitLightingTerms();
                lightingTerms.vDiffuse.rgb = color.rgb;
                return ShadingModelStandard::DoToolsVis(color, m, lightingTerms);
            }

            if (g_bWireframeMode)
            {
                return g_vWireframeColor;
            }

            return DoAtmospherics(m.WorldPosition, m.ScreenPosition.xy, color);
        }

        static float4 Shade(PixelInput i, Material m, float4 color)
        {
            // Match Standard's PixelInput overload so fog/decals use the engine's expected position space.
            m.WorldPositionWithOffset = i.vPositionWithOffsetWs;
            m.WorldPosition = i.vPositionWithOffsetWs + g_vHighPrecisionLightingOffsetWs.xyz;
            m.ScreenPosition = i.vPositionSs;
            return Shade(m, color);
        }
    };

    //-------------------------------------------------------------------------------------------------
    // Pipeline: Shared Initialization
    //-------------------------------------------------------------------------------------------------
	// Build the shared data used by the lighting and layered texture passes.
    // This runs before Direct()/Indirect(), so anything the light loop needs should be prepared here.
	void Init(PixelInput i, Material m)
	{
        // The base UVs are always in the same place, but layered features can opt into UV1.
        baseUv = surfaceUv0;
        uv1Coords = surfaceUv1;
        mainUv = BuildLayerUv(surfaceUv0, MainColorTiling, MainColorOffset, MainColorScroll, MainColorRotate, MainColorRotation);
        mainTex = ColorMap.Sample(g_sAniso, mainUv);
        bool initPixelIsFurShell = i.furShell > EPS_COL;
        selfShadowOverrideAmount = 0.0;

        // View ray and geometric normal feed stylized features like matcap, rim, outlines, and fur.
        viewRayWs = CalculatePositionToCameraDirWs(i.vPositionWithOffsetWs + g_vCameraPositionWs);
        geometricNormalWs = normalize(float3(i.vNormalWs.x, i.vNormalWs.y, i.vNormalWs.z));
        normalWs = m.Normal;

        // Keep the shading normal stable for the main lighting path.
        normalWs = normalize(normalWs);
        // Use the mesh normal for body lighting and the geometric normal for outline checks.
        shadowNormalWs = geometricNormalWs;
        shadowShadeNormalWs = normalize(normalWs);

        // Build base color and alpha before lighting. Later layers assume this is the material foundation.
        float4 tintedBase = mainTex;
        if (ColorAdjustEnabled)
        {
            float2 colorAdjustMaskUv = BuildStaticLayerUv(baseUv, ColorTintMaskTiling, ColorTintMaskOffset, ColorTintMaskRotation);
            float4 colorAdjustMask = saturate(ColorTintMaskTexture.Sample(g_sAniso, colorAdjustMaskUv));
            colorAdjustMask = ApplyInvertMask4(colorAdjustMask, float(ColorTintMaskInvert));
            colorAdjustMask = ApplyMaskIntensity4(colorAdjustMask, ColorTintMaskingIntensity);
            float tintAdjustWeight = dot(colorAdjustMask, 0.25.xxxx);

            float3 adjustedColor = mainTex.rgb;
            float adjustedAlpha = mainTex.a;

            if (TintMaskType <= 1)
            {
                float3 tintBranchColor = ApplyTintBranch(mainTex.rgb, TintColor);
                tintBranchColor = ApplyColorAdjustmentsMasked(tintBranchColor, ColorHue, ColorHueShiftSpeed, ColorBrightness, ColorSaturation, ColorGamma, HueColorSpace, HueMode, colorAdjustMask);
                adjustedColor = lerp(mainTex.rgb, tintBranchColor, tintAdjustWeight);
                adjustedAlpha = lerp(mainTex.a, mainTex.a * TintColor.a, tintAdjustWeight);
            }
            else if (TintMaskType == 2)
            {
                float3 tintBranch1Color = ApplyTintBranch(mainTex.rgb, TintColor);
                tintBranch1Color = ApplyColorAdjustmentsMasked(tintBranch1Color, ColorHue, ColorHueShiftSpeed, ColorBrightness, ColorSaturation, ColorGamma, HueColorSpace, HueMode, colorAdjustMask);

                float3 tintBranch2Color = ApplyTintBranch(mainTex.rgb, SecondTintColor);
                tintBranch2Color = ApplyColorAdjustmentsMasked(tintBranch2Color, SecondTintHue, SecondTintHueShiftSpeed, SecondTintBrightness, SecondTintSaturation, SecondTintGamma, SecondTintHueColorSpace, SecondTintHueMode, colorAdjustMask);

                adjustedColor = lerp(tintBranch2Color, tintBranch1Color, tintAdjustWeight);
                adjustedAlpha = lerp(mainTex.a * SecondTintColor.a, mainTex.a * TintColor.a, tintAdjustWeight);
            }
            else
            {
                float3 gradationColor = ApplyGradientMapColor(mainTex.rgb, GradientMapStrength);
                gradationColor = ApplyColorAdjustmentsMasked(gradationColor, ColorHue, ColorHueShiftSpeed, ColorBrightness, ColorSaturation, ColorGamma, HueColorSpace, HueMode, colorAdjustMask);
                adjustedColor = lerp(mainTex.rgb, gradationColor, tintAdjustWeight);
                adjustedAlpha = mainTex.a;
            }

            tintedBase = float4(adjustedColor, adjustedAlpha);
        }

        #if S_ALPHA_MODE != 0
        // Without an external mask, Alpha Intensity fades from fully opaque toward the resolved texture alpha.
        // With an external mask, the same slider becomes the alpha-mask blend strength.
        alpha = saturate(lerp(1.0, tintedBase.a, saturate(AlphaIntensity)));
        if (UseAlphaMask)
        {
            alpha = saturate(tintedBase.a);
            float2 alphaUv = BuildLayerUv(baseUv, AlphaMaskTiling, AlphaMaskOffset, AlphaMaskScroll, AlphaMaskRotate, AlphaMaskRotation);
            float alphaMaskSample = AlphaMaskTexture.Sample(g_sAniso, alphaUv).r;
            alphaMaskSample = ApplyInvertMask(alphaMaskSample, float(AlphaMaskInvert));
            alpha = ApplyAlphaMask(alpha, alphaMaskSample, AlphaIntensity);
        }
        #else
        alpha = tintedBase.a;
        #endif

        // Backlit is sampled once and reused by every direct light.
        // That keeps masks stable and avoids re-sampling for each light in the scene.
        backlitMaskWeight = 0.0;
        backlitNormalWs = normalWs;
        backlitColor = BacklitColor.rgb;
        if (!initPixelIsFurShell && BacklitEnabled && BacklitIntensity > EPS_COL)
        {
            float2 backlitUv = BuildStaticLayerUv(surfaceUv0, BacklitMaskTiling, BacklitMaskOffset, BacklitMaskRotation);
            float backlitMaskSample = BacklitMaskTexture.Sample(g_sAniso, backlitUv).r;
            backlitMaskSample = ApplyInvertMask(backlitMaskSample, float(BacklitMaskInvert));
            backlitMaskSample = ApplyMaskIntensity(backlitMaskSample, BacklitMaskIntensity);
            backlitNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(BacklitNormalMapStrength)));
            backlitMaskWeight = saturate(backlitMaskSample * BacklitIntensity);
        }

        // Glitter state is prepared once here and reused by each light contribution.
        // The actual sparkle still happens per light so highlights face the right direction.
        glitterUv = surfaceUv0;
        glitterMaskWeight = 0.0;
        glitterBaseColor = GlitterColor.rgb * GlitterColor.a;
        glitterNormalWs = normalWs;
        glitterCacheValid = false;
        if (!initPixelIsFurShell && GlitterEnabled && GlitterIntensity > EPS_COL)
        {
            float2 glitterBaseUv = GetLayerBaseUv(GlitterUvMode);
            glitterUv = glitterBaseUv;
            float2 glitterMaskUv = BuildStaticLayerUv(glitterBaseUv, GlitterMaskTiling, GlitterMaskOffset, GlitterMaskRotation);
            float glitterMaskSample = GlitterMaskTexture.Sample(g_sAniso, glitterMaskUv).r;
            glitterMaskWeight = ApplyMaskIntensity(glitterMaskSample, GlitterMaskIntensity);
            glitterBaseColor = ApplyGlitterColorAdjustments(GlitterColor.rgb) * GlitterColor.a;
            glitterNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(GlitterNormalMapStrength)));

            // Pre-compute Voronoi, sparkle, shape, and color. Everything that does not
            // depend on the light direction. ComputeGlitterContribution() reuses this per light.
            if (!isBackFacePixel && glitterMaskWeight > EPS_COL)
            {
                float densityScale = max(GlitterDensityToScale(), 1.0);
                float2 glitterScale = densityScale.xx;
                float2 gPos = glitterUv * glitterScale;
                float2 dd = fwidth(gPos);
                float2 mipGrid = max(floor(dd + 3.0), 1.0.xx);
                float mipNoise = frac(sin(dot(floor(gPos / mipGrid), float2(12.9898, 78.233))) * 46203.4357) + 0.5;
                float2 mipFactor = max(floor(dd + mipNoise * 0.5), 1.0.xx);
                gPos = gPos / mipFactor + glitterScale * mipFactor;

                float2 nearestPoint;
                float3 nearestRandom;
                float nearestDistance;
                GlitterVoronoi(gPos, nearestPoint, nearestRandom, nearestDistance);

                float randomSpeed = lerp(1.0, 0.35 + nearestRandom.x * 1.65, saturate(GlitterRandomizeSpeed));
                float blinkPhase = nearestRandom.y * 6.2831853 * saturate(GlitterRandomizeSpeed);
                float blinkTime = g_flTime * GlitterBlinkSpeedToValue() * randomSpeed + blinkPhase;

                float3 sparkleNormal = abs(frac(nearestRandom * 14.274 + blinkTime) * 2.0 - 1.0);
                sparkleNormal = normalize(sparkleNormal * 2.0 - 1.0);

                glitterCachedCameraDir = normalize(viewRayWs);
                float sparkle = dot(sparkleNormal, glitterCachedCameraDir);
                float sensitivity = max(GlitterSensitivityToValue(), EPS_COL);
                sparkle = abs(frac(sparkle * sensitivity + sensitivity) - 0.5) * 4.0 - 1.0;
                glitterCachedSparkleBase = saturate(1.0 - (sparkle + 1.0));

                float randomSize = lerp(1.0, rsqrt(max(nearestRandom.z, 0.001)), saturate(GlitterRandomizeSize));
                float glitterSize = max(GlitterSize * (densityScale / 256.0) * randomSize, EPS_COL);
                float2 localUv = nearestPoint / glitterSize * 0.5 + 0.5;
                float randomAngleDegrees = nearestRandom.z * 360.0 * saturate(GlitterRandomizeRotation);
                float4 shapeResult = ComputeGlitterShapeMask(localUv, randomAngleDegrees);
                glitterCachedShapeMask = shapeResult.a;
                glitterCachedShapeColor = shapeResult.rgb;
                glitterCachedRandomColor = 1.0.xxx - frac(nearestRandom * 278.436) * saturate(GlitterRandomizeColor);
                glitterCacheValid = true;
            }
        }

        // Reflection material state is sampled once here and reused by the light loop.
        // Channel controls let different packed PBR texture layouts use the same shader.
        #if S_SHADING_MODE != 5
        reflectionSmoothness = saturate(Smoothness);
        reflectionMetallic = 0.0;
        reflectionPbrResponse = 0.0;
        toonSpecularMapMask = 1.0;
        reflectionAoMask = 0.0;
        reflectionShadowMask = 0.0;
        reflectionLayerColor = float4(SpecularTint.rgb, 0.0);
        reflectionNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(PbrNormalStrength)));
        if (PbrEnabled)
        {
            // Packed PBR texture. Metallic and smoothness shape reflection response.
            // AO and shadow channels gate the Realistic indirect/direct masks.
            float2 PBRMapUv = BuildStaticLayerUv(surfaceUv0, PBRMapTiling, PBRMapOffset, PBRMapRotation);
            float4 PBRMapSample = PBRMapTexture.Sample(g_sAniso, PBRMapUv);
            float pbrMetallicMask = GetPackedMaskChannel(PBRMapSample, PBRMetallicChannel);
            float pbrSmoothnessMask = GetPackedMaskChannel(PBRMapSample, PBRSmoothnessChannel);
            float pbrAoMask = GetPackedMaskChannel(PBRMapSample, PBRAOChannel);
            float pbrShadowMask = GetPackedMaskChannel(PBRMapSample, PBRShadowMapChannel);
            float4 specularTintSample = SpecularTint;
            reflectionSmoothness = saturate(Smoothness * pbrSmoothnessMask);
            reflectionMetallic = saturate(Metallic * pbrMetallicMask);
            reflectionPbrResponse = saturate(max(reflectionSmoothness, reflectionMetallic));
            toonSpecularMapMask = saturate(pbrSmoothnessMask);
            reflectionAoMask = saturate(pbrAoMask);
            reflectionShadowMask = saturate(pbrShadowMask);
            reflectionLayerColor = float4(specularTintSample.rgb, reflectionPbrResponse);
        }

        // Perceptual roughness from smoothness, clamped to avoid precision issues at roughness=0.
        GSAAForSmoothness(reflectionSmoothness, reflectionNormalWs, PbrEnabled ? SpecularGsaa : 0.0);
        float perceptualRoughness = 1.0 - reflectionSmoothness;
        reflectionRoughness = max(perceptualRoughness * perceptualRoughness, 0.002);
        reflectionSpecularColor = lerp(0.04.xxx, tintedBase.rgb, reflectionMetallic);
        #else
        reflectionSmoothness = 0.5;
        reflectionMetallic = 0.0;
        reflectionPbrResponse = 0.0;
        reflectionLayerColor = float4(0.0, 0.0, 0.0, 0.0);
        reflectionNormalWs = normalWs;
        reflectionRoughness = 0.25;
        reflectionSpecularColor = 0.04.xxx;
        #endif

        #if S_SHADING_MODE == 4
        realisticAoFactor = 1.0.xxx;
        realisticShadowFactor = 1.0.xxx;
        bool needsRealisticAoMap = UseMultiChannelAo
            ? (AoRIntensity > EPS_COL || AoGIntensity > EPS_COL || AoBIntensity > EPS_COL || AoAIntensity > EPS_COL)
            : (AoIntensity > EPS_COL);

        if (needsRealisticAoMap)
        {
            // Realistic shading's AO affects indirect light. It is sampled only when a control needs it.
            float2 aoUv = BuildStaticLayerUv(mainUv, AoMapTiling, AoMapOffset, AoMapRotation);
            float4 aoMapSample = AoMapTexture.Sample(g_sAniso, aoUv);
            float3 aoMapFactor = 1.0.xxx;
            if (UseMultiChannelAo)
            {
                float3 aoRgbFactor = float3(
                    lerp(1.0, aoMapSample.r, saturate(AoRIntensity)),
                    lerp(1.0, aoMapSample.g, saturate(AoGIntensity)),
                    lerp(1.0, aoMapSample.b, saturate(AoBIntensity))
                );
                float aoAlphaFactor = lerp(1.0, aoMapSample.a, saturate(AoAIntensity));
                aoMapFactor = aoRgbFactor * aoAlphaFactor;
            }
            else
            {
                aoMapFactor = lerp(1.0.xxx, aoMapSample.r.xxx, saturate(AoIntensity));
            }
            realisticAoFactor = aoMapFactor;
        }

        bool needsRealisticShadowMap = UseMultiChannelShadowMap
            ? (ShadowMapRIntensity > EPS_COL || ShadowMapGIntensity > EPS_COL || ShadowMapBIntensity > EPS_COL || ShadowMapAIntensity > EPS_COL)
            : (ShadowMapIntensity > EPS_COL);
        if (needsRealisticShadowMap)
        {
            // Realistic shadow map is direct-light detail only. 
            float2 realisticShadowUv = BuildStaticLayerUv(mainUv, ShadowMapTiling, ShadowMapOffset, ShadowMapRotation);
            float4 realisticShadowSample = ShadowMapTexture.Sample(g_sAniso, realisticShadowUv);
            if (UseMultiChannelShadowMap)
            {
                float3 shadowRgbFactor = float3(
                    lerp(1.0, realisticShadowSample.r, saturate(ShadowMapRIntensity)),
                    lerp(1.0, realisticShadowSample.g, saturate(ShadowMapGIntensity)),
                    lerp(1.0, realisticShadowSample.b, saturate(ShadowMapBIntensity))
                );
                float shadowAlphaFactor = lerp(1.0, realisticShadowSample.a, saturate(ShadowMapAIntensity));
                realisticShadowFactor = shadowRgbFactor * shadowAlphaFactor;
            }
            else
            {
                realisticShadowFactor = lerp(1.0.xxx, realisticShadowSample.r.xxx, saturate(ShadowMapIntensity));
            }
        }
        #else
        realisticAoFactor = 1.0.xxx;
        realisticShadowFactor = 1.0.xxx;
        #endif
        #if S_ENABLE_EXPENSIVE_FEATURES
        postProcessSsaoFactor = ComputePostProcessSsao(m.ScreenPosition);
        #else
        postProcessSsaoFactor = 1.0.xxx;
        #endif
        #if S_SHADING_MODE == 4
        realisticAoFactor *= postProcessSsaoFactor;
        float pbrAoWeight = saturate(AmbientOcclusion);
        realisticAoFactor *= lerp(1.0.xxx, reflectionAoMask.xxx, pbrAoWeight);
        float pbrShadowWeight = saturate(DetailShadowing);
        realisticShadowFactor *= lerp(1.0.xxx, reflectionShadowMask.xxx, pbrShadowWeight);
        #endif
        float4 reflectionBase = tintedBase;
        reflectionBase.rgb *= (1.0 - reflectionMetallic);
        reflectionEnvmapAccumulated = 0.0.xxx;
        #if S_SHADING_MODE != 5
        if (IsPbrLightingActive())
        {
            // Env reflections are accumulated separately so stylized modes can blend them after toon shading.
            float viewNormalDot = saturate(dot(reflectionNormalWs, normalize(viewRayWs)));
            float3 envmapFresnel = ComputeReflectionFresnel(reflectionSpecularColor, viewNormalDot);
            bool wantsPbrReflection = EnvmapReflections;
            #if S_SHADING_MODE != 5
            bool wantsCubemapPbrReflection = CubemapEnabled && (ForcePbrReflection || UseAsPbrFallback);
            wantsPbrReflection = wantsPbrReflection || wantsCubemapPbrReflection;
            #endif
            if (wantsPbrReflection && reflectionPbrResponse > EPS_COL)
            {
                float3 envmapSample = 0.0.xxx;
                if (EnvmapReflections)
                {
                    envmapSample = SampleReflectionEnvMap(m.WorldPosition, m.ScreenPosition, reflectionNormalWs, reflectionRoughness);
                }
                #if S_SHADING_MODE != 5
                float envmapHasSceneProbe = max(envmapSample.r, max(envmapSample.g, envmapSample.b));
                if (CubemapEnabled && (ForcePbrReflection || (UseAsPbrFallback && envmapHasSceneProbe <= EPS_COL)))
                {
                    envmapSample = SampleCubemapReflectionFallback();
                }
                #endif
                reflectionEnvmapAccumulated += envmapSample * ReflectionTint.rgb * envmapFresnel * reflectionPbrResponse;
            }
        }
        #endif
        float4 scaledBase = float4(reflectionBase.rgb * (LitIntensity * 2.0), reflectionBase.a);
		lit = scaledBase;
        shade = BuildInternalShade(scaledBase);

        #if S_SHADING_MODE != 5
        // SubsurfaceScattering is cached once per pixel so the light loop only does direction math.
        SubsurfaceScatteringNormalWs = shadowShadeNormalWs;
        SubsurfaceScatteringTint = 0.0.xxx;
        SubsurfaceScatteringMaskWeight = 0.0;
        if (!initPixelIsFurShell && SubsurfaceScatteringEnabled && SubsurfaceScatteringIntensity > EPS_COL)
        {
            float4 SubsurfaceScatteringSample = SubsurfaceScatteringTexture.Sample(g_sAniso, mainUv);
            SubsurfaceScatteringTint = max(SubsurfaceScatteringColor.rgb * SubsurfaceScatteringSample.rgb, 0.0.xxx);
            SubsurfaceScatteringTint = lerp(SubsurfaceScatteringTint, SubsurfaceScatteringTint * lit.rgb, saturate(SubsurfaceScatteringMainColorMix));
            SubsurfaceScatteringMaskWeight = saturate(SubsurfaceScatteringSample.a);
        }
        #endif

        isOutline = i.isOutline > 0.5;
	}

	// Compute the contribution from one direct light.
    //-------------------------------------------------------------------------------------------------
    // Pipeline: Direct Lighting
    //-------------------------------------------------------------------------------------------------
	float4 Direct(PixelInput i, Material m, Light l)
	{
        // Direct() is called once per light. It gathers the dominant light for toon shadows
        // while also accumulating specular/backlit/glitter contributions.
        bool directPixelIsFurShell = i.furShell > EPS_COL;
        float3 worldPosition = m.WorldPosition;
        float3 rawLightDirectionWs = dot(l.Direction, l.Direction) > EPS_COL ? normalize(l.Direction) : float3(0.0, 0.0, 1.0);
        float3 controlledLightDirectionWs = ResolveOverwriteLightDirection(rawLightDirectionWs);
		float dotNL = dot(controlledLightDirectionWs, shadowNormalWs);
        float rawAttenuation = max(l.Attenuation, 0.0);
        float attenuation = rawAttenuation;
        float halfLambert = saturate(dotNL * 0.5 + 0.5);
        bool isDirectionalLight = l.LightData.Type == LightType::LightTypeDirectional;
        if (isDirectionalLight)
        {
            // Directional lights behave like the sun, so they get a stricter light wrap than local lights.
            hasDirectionalLightInLoop = true;
        }
        float wrappedLighting = halfLambert;
        if (isDirectionalLight)
        {
            // Directional lights get a tighter wrap than local lights.
            wrappedLighting = saturate(dotNL);
        }
        float3 controlledLightColor = ApplyShaderLightControls(max(l.Color, 0.0.xxx));
        float3 attenuatedLightColor = controlledLightColor * attenuation;
        // Realistic owns engine visibility. Toon modes only read it through the explicit Self Shadow feature.
        float3 stylizedLightColor = attenuatedLightColor;
        float3 visibleLightColor = attenuatedLightColor;
        #if S_SHADING_MODE == 4 && S_ALPHA_MODE != 2
            // Realistic is the only mode that should consume engine shadow visibility.
            // Toon modes keep lighting direction/color, but not receive-shadow darkening.
            if (SelfShadowingEnabled)
            {
                visibleLightColor *= lerp(1.0, saturate(l.Visibility), saturate(SelfShadowingIntensity));
            }
        #endif
        float customSelfShadowVisibility = 1.0;
        float customSelfShadowAmount = 0.0;
        bool customSelfShadowApplied = false;
        float selfShadowLightScoreCandidate = 0.0;
        bool supportsCustomSelfShadow = l.LightData.Type == LightType::LightTypeSpot || l.LightData.Type == LightType::LightTypePoint;
        #if S_SHADING_MODE != 4 && S_ALPHA_MODE != 2
        bool allowCustomSelfShadowPixel = !directPixelIsFurShell;
        if (IsSelfShadowRuntimeActive() && allowCustomSelfShadowPixel && supportsCustomSelfShadow)
        {
            customSelfShadowVisibility = saturate(l.Visibility);
            float selfShadowFacing = saturate(dot(rawLightDirectionWs, shadowShadeNormalWs));
            customSelfShadowAmount = saturate((1.0 - customSelfShadowVisibility) * SelfShadowIntensity) * selfShadowFacing;
            customSelfShadowApplied = customSelfShadowAmount > EPS_COL;
            visibleLightColor = attenuatedLightColor * (1.0 - customSelfShadowAmount);
            selfShadowLightScoreCandidate = max(stylizedLightColor.x, max(stylizedLightColor.y, stylizedLightColor.z)) * customSelfShadowAmount;
        }
        #endif
        float lightBrightness = RangeResponse(max(stylizedLightColor.x, max(stylizedLightColor.y, stylizedLightColor.z)));
        float attenuationResponse = RangeResponse(attenuation);
        float transitionSoftness = lerp(0.22, 0.06, lightBrightness);

        float currentLightIntensity = wrappedLighting;
        currentLightIntensity *= lerp(0.25, 1.0, attenuationResponse);

        float shadowShadeDotNL = dot(controlledLightDirectionWs, shadowShadeNormalWs);
        float shadowShadeWrappedLighting = saturate(shadowShadeDotNL * 0.5 + 0.5);
        float currentShadowLightMap = shadowShadeWrappedLighting;
        if (isDirectionalLight)
        {
            // The directional light vector can differ slightly from the loop light vector in S&box.
            // Taking the max keeps toon shadow maps from disappearing on fully lit white sun setups.
            shadowShadeWrappedLighting = saturate(shadowShadeDotNL);
            currentShadowLightMap = shadowShadeWrappedLighting;
            float3 sunDirectionWs = ResolveOverwriteLightDirection(normalize(-g_DirectionalLightDirection.xyz));
            float directionalShadowWrap = saturate(dot(sunDirectionWs, shadowShadeNormalWs) * 0.5 + 0.5);
            currentShadowLightMap = max(currentShadowLightMap, directionalShadowWrap);
        }
        currentShadowLightMap *= attenuation;
        float shadowScoreMap = currentShadowLightMap;
        float shadowScore = shadowScoreMap * max(stylizedLightColor.x, max(stylizedLightColor.y, stylizedLightColor.z));
        bool isDominantShadowLight = false;
        if (shadowScore > shadowLightScore)
        {
            // Use the strongest light as the source for shadow-layer maps and SDF direction.
            isDominantShadowLight = true;
            shadowLightMap = currentShadowLightMap;
            shadowLightScore = shadowScore;
            float3 dominantLightDirectionWs = controlledLightDirectionWs;
            float dominantLightDirectionLenSq = dot(dominantLightDirectionWs, dominantLightDirectionWs);
            shadowLightDirectionWs = dominantLightDirectionLenSq > EPS_COL ? dominantLightDirectionWs * rsqrt(dominantLightDirectionLenSq) : float3(0.0, 0.0, 1.0);
        }
        if (customSelfShadowApplied && selfShadowLightScoreCandidate > selfShadowLightScore)
        {
            selfShadowLightScore = selfShadowLightScoreCandidate;
            selfShadowOverrideAmount = customSelfShadowAmount;
        }

        currentLightIntensity = ComputeToonBlend(currentLightIntensity, transitionSoftness);
        lightIntensity = max(lightIntensity, currentLightIntensity);
        debugAttenuation = max(debugAttenuation, saturate(attenuation));
        if (isDirectionalLight)
        {
            debugDirectionalFactor = max(debugDirectionalFactor, currentLightIntensity);
            debugDirectionalColor = max(debugDirectionalColor, visibleLightColor);
        }

        float3 visibleEffectLightColor = visibleLightColor;
        float3 stylizedDirectLightColor = max(stylizedLightColor, EPS_COL);

        #if S_SHADING_MODE != 5
        if (!directPixelIsFurShell)
        {
            float3 SubsurfaceScatteringLightColor = controlledLightColor;
            #if S_SHADING_MODE == 4 && S_ALPHA_MODE != 2
                if (SelfShadowingEnabled)
                {
                    SubsurfaceScatteringLightColor *= lerp(1.0, saturate(l.Visibility), saturate(SelfShadowingIntensity));
                }
            #endif
            float SubsurfaceScatteringWeight = ComputeSubsurfaceScatteringWeight(controlledLightDirectionWs, attenuation);
            SubsurfaceScatteringAccumulated += SubsurfaceScatteringLightColor * SubsurfaceScatteringTint * SubsurfaceScatteringWeight;
            SubsurfaceScatteringEmissionAccumulated += SubsurfaceScatteringTint * SubsurfaceScatteringWeight;
        }
        #endif

        #if S_SHADING_MODE != 5
            if (IsPbrLightingActive() && SpecularMode > 0)
            {
                // Reflections are accumulated here, then blended in PostProcess() after the base shading.
                float3 specularLightDirectionWs = controlledLightDirectionWs;
                float specularBaseVisibility = saturate(dot(specularLightDirectionWs, reflectionNormalWs));
                float specularLitSideGate = saturate(dot(specularLightDirectionWs, shadowShadeNormalWs));
                float specularLightingVisibility = lerp(specularBaseVisibility, min(specularBaseVisibility, specularLitSideGate), saturate(SpecularLightingMix));
                if (specularLightingVisibility > EPS_COL)
                {
                    float3 specularLightColor = visibleEffectLightColor * specularLightingVisibility;
                    if (SpecularMode == 1)
                    {
                        AccumulateToonSpecular(specularLightDirectionWs, specularLightColor);
                    }
                    else
                    {
                        reflectionAccumulated += ComputeReflectionSpecular(specularLightDirectionWs, specularLightColor);
                    }
                }
            }
        #endif
        if (!directPixelIsFurShell)
        {
            float backlightWeight = ComputeBacklightWeight(controlledLightDirectionWs, attenuation);
            backlightAccumulated += visibleEffectLightColor * backlitColor * backlightWeight;
            backlightEmissionAccumulated += backlitColor * backlightWeight;
            glitterAccumulated += ComputeGlitterContribution(controlledLightDirectionWs, visibleEffectLightColor, attenuation);
        }
 
        float3 visibleDirectLighting = visibleEffectLightColor * DirectLightIntensity;
		float3 stylizedDirectLighting = stylizedDirectLightColor * DirectLightIntensity;

        #if S_SHADING_MODE == 4
        // Realistic bypasses toon band composition and uses normal direct lambert + PBR response.
        float3 directLightDirection = controlledLightDirectionWs;
        if (isDirectionalLight || isDominantShadowLight)
        {
            realisticDirectionalShade = ComputeRealisticDirectionalShade(reflectionNormalWs, directLightDirection);
        }

        float directLambert = ComputeRealisticDirectResponse(saturate(dot(reflectionNormalWs, directLightDirection)));
        visibleDirectLighting = ApplyRealisticDirectControls(visibleDirectLighting, directLambert);
        lighting += visibleDirectLighting * directLambert;
        float3 resultColor = lit.rgb * visibleDirectLighting * directLambert;
        directSurfaceLighting += resultColor;
        return float4(resultColor, 1);
        #else
		// Stylized modes keep direct light as a colored lift over the toon base.
		float surfaceBlend = max(currentLightIntensity, ambientToonBlend);
        lighting += stylizedDirectLighting * surfaceBlend;
		float3 resultColor = lerp(shade.rgb, lit.rgb, surfaceBlend);
		resultColor *= stylizedDirectLighting;
        directSurfaceLighting += resultColor;
 
		return float4(resultColor,1);
        #endif
		
	}

	// Compute the ambient and indirect light contribution.
    //-------------------------------------------------------------------------------------------------
    // Pipeline: Indirect Lighting
    //-------------------------------------------------------------------------------------------------
	float4 Indirect(PixelInput i, Material m)
	{
        // Indirect light is the ambient/scene side of the shader. SSAO is applied here, never to direct light.
		float3 resultColor = float3(0,0,0);
        ambientSurfaceColor = lit.rgb;

        // Reuse the ambient sample already computed in MainPs.
        float3 ambientSample = cachedAmbientSample;
        float3 indirectSignal = ambientSample;
        float indirectBoost = saturate(IndirectBoost);
        float ambientBlurAmount = saturate(IndirectSoftness * 0.5);
        float ambientAverage = dot(ambientSample, float3(0.333333, 0.333333, 0.333333));
        float3 blurredAmbient = lerp(ambientSample, ambientAverage.xxx, ambientBlurAmount);

        if (IndirectLightingEnabled)
        {
            float boost = lerp(1.0, 1.5, indirectBoost);
            indirectSignal = blurredAmbient * boost;
        }
        else
        {
            float ambientRange = max(ambientSample.x, max(ambientSample.y, ambientSample.z));
            float ambientResponse = RangeResponse(ambientRange);
            ambientToonBlend = ComputeAmbientLift(ambientResponse);
            indirectLighting = 0.0.xxx;
            indirectSurfaceLighting = 0.0.xxx;
            return float4(0.0.xxx, 0);
        }

        float ambientRange = max(indirectSignal.x, max(indirectSignal.y, indirectSignal.z));
        float ambientResponse = RangeResponse(ambientRange);
        ambientToonBlend = ComputeAmbientLift(ambientResponse);

        #if S_SHADING_MODE == 4
        // Realistic mode keeps indirect light fully active and lets AO maps/SSAO shape it later.
        ambientToonBlend = 1.0;
        indirectLighting = indirectSignal * INDIRECT_LIGHT_INTENSITY;

        float3 indirectColor = indirectLighting * ambientSurfaceColor;
        resultColor = BlendIndirectLighting(ambientSurfaceColor, indirectColor, IndirectBlendMode);
        indirectSurfaceLighting = resultColor;
        return float4(resultColor, 0);
        #else
        // Stylized modes use ambient lift so shadowed areas do not collapse into flat black.
        indirectLighting = indirectSignal * ambientToonBlend * INDIRECT_LIGHT_INTENSITY;
        indirectLighting *= postProcessSsaoFactor;

		float3 indirectColor = indirectLighting * ambientSurfaceColor;
        resultColor = BlendIndirectLighting(ambientSurfaceColor, indirectColor, IndirectBlendMode);
        indirectSurfaceLighting = resultColor;

		return float4(resultColor,0);
        #endif
    }

    //-------------------------------------------------------------------------------------------------
    // Pipeline: Layered Post Process
    //-------------------------------------------------------------------------------------------------
    // Converts accumulated lighting into the final stylized material result.
    // Keep the section order stable: later overlays intentionally build on earlier shading.
	float4 PostProcess(PixelInput i, float4 color)
	{
        float3 lightResponse = saturate(lighting + indirectLighting);
        float3 debugShadingColor = 0.0.xxx;
        bool postProcessPixelIsFurShell = i.furShell > EPS_COL;

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Realistic Base Resolve
        //-------------------------------------------------------------------------------------------------
        #if S_SHADING_MODE == 4
        // Realistic is composed here from the direct/indirect surfaces prepared by the lighting passes.
        color.rgb = directSurfaceLighting * realisticShadowFactor + indirectSurfaceLighting * realisticAoFactor * realisticDirectionalShade;
        debugShadingColor = color.rgb;
        #endif

        #if S_SHADING_MODE != 4 && S_SHADING_MODE != 5
        if (PbrEnabled)
        {
            color.rgb = lerp(color.rgb, color.rgb * reflectionAoMask.xxx, saturate(AmbientOcclusion));
            color.rgb = lerp(color.rgb, color.rgb * reflectionShadowMask.xxx, saturate(DetailShadowing));
            debugShadingColor = color.rgb;
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Extra Color Layer
        //-------------------------------------------------------------------------------------------------
        #if S_ENABLED_EXTRA_LAYERS
        if (SecondColorEnabled && (SecondColorOpacity > EPS_COL || SecondColorEmission > EPS_COL || SecondColorAlphaMode > 0))
        {
            // Second Color can be a decal, tint layer, emission patch, or translucent alpha influence.
            float SecondColorDecalVisibility = 1.0;
            float2 SecondColorUv = BuildSecondColorDecalUv(surfaceUv0, SecondColorDecalVisibility);
            float4 SecondColorSample = SecondColorTexture.Sample(g_sAniso, SecondColorUv);
            // SecondColorTintIntensity keeps Second color tinting independent of the base tint chain.
            SecondColorSample.rgb = lerp(SecondColorSample.rgb, SecondColorSample.rgb * SecondColorTint.rgb, saturate(SecondColorTintIntensity));
            SecondColorSample.a = lerp(SecondColorSample.a, SecondColorSample.a * SecondColorTint.a, saturate(SecondColorTintIntensity));
            // Apply Second color adjustments. Defaults are neutral so existing materials are unaffected.
            SecondColorSample.rgb = ApplyColorAdjustments(SecondColorSample.rgb, SecondColorHue, SecondColorHueShiftSpeed, SecondColorBrightness, SecondColorSaturation, SecondColorGamma, SecondColorHueColorSpace, SecondColorHueMode);
            float2 SecondColorMaskUv = BuildStaticLayerUv(SecondColorUv, SecondColorMaskTiling, SecondColorMaskOffset, SecondColorMaskRotation);
            float SecondColorMask = SecondColorMaskTexture.Sample(g_sAniso, SecondColorMaskUv).r;
            SecondColorMask = ApplyInvertMask(SecondColorMask, float(SecondColorMaskInvert));
            float SecondColorCulling = 1.0;
            if (SecondColorCullingMode == 4)
            {
                SecondColorCulling = 0.0;
            }
            else if (SecondColorCullingMode == 2 && !isBackFacePixel)
            {
                SecondColorCulling = 0.0;
            }
            else if (SecondColorCullingMode == 3 && isBackFacePixel)
            {
                SecondColorCulling = 0.0;
            }

            float secondColorTextureAlpha = lerp(1.0, SecondColorSample.a, float(SecondColorUseAlpha));
            float mainSecondWeight = saturate(SecondColorOpacity * secondColorTextureAlpha * ApplyMaskIntensity(SecondColorMask, SecondColorMaskIntensity) * SecondColorDecalVisibility * SecondColorCulling);
            float3 mainSecondColor = SecondColorSample.rgb * lerp(1.0.xxx, lightResponse, SecondColorLightingMix * (Unlit ? 0.0 : 1.0));
            mainSecondColor += SecondColorSample.rgb * max(SecondColorEmission, 0.0);
            SecondColorUnlitColor = mainSecondColor;
            SecondColorUnlitWeight = mainSecondWeight;
            color.rgb = BlendLayerColor(color.rgb, mainSecondColor, mainSecondWeight, SecondColorBlendMode);
            // SecondColorAlphaMode: applies Second layer alpha to surface opacity in Translucent mode only.
            #if S_ALPHA_MODE == 2
            if (SecondColorAlphaMode > 0)
            {
                float layerAlpha = mainSecondWeight;
                float tSecond = saturate(SecondColorOpacity);
                if (SecondColorAlphaMode == 1) alpha = saturate(lerp(alpha, layerAlpha, tSecond));        // Replace
                else if (SecondColorAlphaMode == 2) alpha = saturate(alpha * lerp(1.0, layerAlpha, tSecond)); // Multiply
                else if (SecondColorAlphaMode == 3) alpha = saturate(alpha + layerAlpha * tSecond);       // Add
                else                             alpha = saturate(alpha - layerAlpha * tSecond);       // Subtract
            }
            #endif
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Final Alpha Extras
        //-------------------------------------------------------------------------------------------------
        #if S_ALPHA_MODE != 0
        // Alpha extras are resolved after Second Color so that Second alpha modes can feed the final chain.
        alpha = ResolveFinalAlpha(alpha, i.vPositionSs.xy);
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Shading Mode Resolve
        //-------------------------------------------------------------------------------------------------
        float shadowShadingPresence = 0.0;
        #if S_SHADING_MODE == 1 || S_SHADING_MODE == 5
        // Multi-layer shading is also reused by Fur base shading, including the AO mask when enabled.
        float shadeMapLight = saturate(shadowLightMap);
        bool allowSelfShadowResolve = true;
        #if S_SHADING_MODE == 5
        allowSelfShadowResolve = !postProcessPixelIsFurShell;
        #endif
        if (IsSelfShadowRuntimeActive() && allowSelfShadowResolve)
        {
            float selfShadowMask = saturate(selfShadowOverrideAmount);
            float3 shadowBaseColor = color.rgb;
            float3 shadowLayerColor = 0.0.xxx;
            float mainShadowMask = selfShadowMask;

            shadowShadingPresence = saturate(mainShadowMask);
            color.rgb = lerp(shadowBaseColor, shadowLayerColor, mainShadowMask);
            debugShadingColor = color.rgb;
        }
        else
        {
            float shadowDirectionValid = step(EPS_COL, dot(shadowLightDirectionWs, shadowLightDirectionWs));
            float shadowLayer1WrappedLight = saturate(dot(shadowLightDirectionWs, normalize(lerp(geometricNormalWs, shadowShadeNormalWs, saturate(ShadowNormalMapStrength)))) * 0.5 + 0.5);
            float shadowLayer2WrappedLight = saturate(dot(shadowLightDirectionWs, normalize(lerp(geometricNormalWs, shadowShadeNormalWs, saturate(SecondShadowNormalMapStrength)))) * 0.5 + 0.5);
            float shadowLayer3WrappedLight = saturate(dot(shadowLightDirectionWs, normalize(lerp(geometricNormalWs, shadowShadeNormalWs, saturate(ThirdShadowNormalMapStrength)))) * 0.5 + 0.5);
            float shadowLayer1Light = lerp(shadeMapLight, shadowLayer1WrappedLight, shadowDirectionValid);
            float shadowLayer2Light = lerp(shadeMapLight, shadowLayer2WrappedLight, shadowDirectionValid);
            float shadowLayer3Light = lerp(shadeMapLight, shadowLayer3WrappedLight, shadowDirectionValid);
            float2 shadowMapUv = BuildStaticLayerUv(mainUv, ShadowMapTiling, ShadowMapOffset, ShadowMapRotation);
            float shadowMapStrength = saturate(ShadowMapIntensity);
            float4 shadowMapSample = 1.0.xxxx;
            float4 shadowMapFlatSample = 1.0.xxxx;
            float4 shadowMapSdfSample = 1.0.xxxx;
            if (ShadowMapType == 0 && shadowMapStrength > EPS_COL)
            {
                // Strength map: generic RGB/A channels attenuate the three shadow layers and edge border.
                shadowMapSample = ShadowMapTexture.Sample(g_sAniso, shadowMapUv);
                shadowMapSample = ApplyInvertMask4(shadowMapSample, float(ShadowMapInvert));
            }
            else if (ShadowMapType == 1)
            {
                // Flat shadow map: sampled with LOD-style gradients so softness behaves like texture blur.
                shadowMapFlatSample = ShadowMapTexture.Sample(g_sAniso, shadowMapUv);
                shadowMapFlatSample = ApplyInvertMask4(shadowMapFlatSample, float(ShadowMapInvert));
            }
            else if (ShadowMapType == 2)
            {
                // SDF shadow map: R/G are left-right fields, B blends back to normal shadows, A is strength.
                shadowMapSdfSample = ShadowMapTexture.Sample(g_sAniso, shadowMapUv);
                shadowMapSdfSample = ApplyInvertMask4(shadowMapSdfSample, float(ShadowMapInvert));
            }

            // Keep shadow color contrast centered so tinting does not crush soft colors.
            float3 shadowColor = ApplyShadowContrast(ShadowColor.rgb, 1.0 + ShadowContrast);
            float3 secondShadowColor = ApplyShadowContrast(SecondShadowColor.rgb, 1.0 + ShadowContrast);
            float3 thirdShadowColor = ApplyShadowContrast(ThirdShadowColor.rgb, 1.0 + ShadowContrast);
            float shadeMapAa = EPS_COL; // Fixed minimum softness floor; blur sliders handle per-layer softness

            float shadowBlurMaskStrength = saturate(ShadowBlurMaskIntensity);
            float3 shadowBlurMask = 1.0.xxx;
            if (shadowBlurMaskStrength > EPS_COL)
            {
                float4 shadowBlurMaskSample = ShadowBlurMaskTexture.Sample(g_sAniso, mainUv);
                shadowBlurMask = lerp(1.0.xxx, shadowBlurMaskSample.rgb, shadowBlurMaskStrength);
            }

            float3 shadowAoMask = 1.0.xxx;
            bool ignoreShadowAoBorder = false;
            if (UseShadowAoMask)
            {
                float4 shadowAoMaskSample = ShadowAoMaskTexture.Sample(g_sAniso, mainUv);
                shadowAoMaskSample = ApplyInvertMask4(shadowAoMaskSample, float(ShadowAoMaskInvert));
                ignoreShadowAoBorder = ShadowAoMaskIgnoreBorderProperties;
                shadowAoMask = float3(
                    Remap01Range(shadowAoMaskSample.r, ShadowAoMask1Min, ShadowAoMask1Max),
                    Remap01Range(shadowAoMaskSample.g, ShadowAoMask2Min, ShadowAoMask2Max),
                    Remap01Range(shadowAoMaskSample.b, ShadowAoMask3Min, ShadowAoMask3Max)
                );
            }

            // Artist softness is calibrated to the current toon-band response.
            float shadowSoftness = max(ShadowSoftness * 0.5 * shadowBlurMask.r, shadeMapAa);
            float secondShadowSoftness = max(SecondShadowSoftness * 0.5 * shadowBlurMask.g, shadeMapAa);
            float thirdShadowSoftness = max(ThirdShadowSoftness * 0.5 * shadowBlurMask.b, shadeMapAa);

            float3 shadowInputs = float3(shadowLayer1Light, shadowLayer2Light, shadowLayer3Light);
            float shadowEdgeInput = shadeMapLight;
            float3 shadowMaskChannels = shadowMapSample.rgb;
            float shadowMaskBorder = shadowMapSample.a;

            if (ShadowMapType == 1)
            {
                // Flat mode fakes a simple up-biased lighting field, then the map chooses where it applies.
                float3 flatUpWs = dot(worldTangentVWs, worldTangentVWs) > EPS_COL ? normalize(worldTangentVWs) : geometricNormalWs;
                float3 flatNormalWs = normalize(geometricNormalWs + flatUpWs * 0.25);
                float flatLight = saturate((dot(flatNormalWs, shadowLightDirectionWs) + FlatShadowMapArea) / max(FlatShadowMapSoftness, EPS_COL));
                shadowInputs = lerp(flatLight.xxx, shadeMapLight.xxx, shadowMapFlatSample.rgb);
                shadowEdgeInput = shadowInputs.r;
                shadowMaskChannels = shadowMapFlatSample.rgb;
                shadowMaskBorder = shadowMapFlatSample.a;
            }
            else if (ShadowMapType == 2)
            {
                // SDF mode follows the lilToon channel contract and blends back toward normal shade maps with B.
                float3 sdfLightDirection = shadowLightDirectionWs;
                float3 sdfRightWs = dot(worldTangentUWs, worldTangentUWs) > EPS_COL ? normalize(worldTangentUWs) : float3(1.0, 0.0, 0.0);
                float3 sdfUpWs = dot(worldTangentVWs, worldTangentVWs) > EPS_COL ? normalize(worldTangentVWs) : float3(0.0, 1.0, 0.0);
                float3 sdfForwardWs = cross(sdfRightWs, sdfUpWs);
                sdfLightDirection.y *= SDFMapBlendYDirection;
                sdfForwardWs.y *= SDFMapBlendYDirection;
                sdfLightDirection = dot(sdfLightDirection, sdfLightDirection) > EPS_COL ? normalize(sdfLightDirection) : float3(0.0, 0.0, 1.0);
                sdfForwardWs = dot(sdfForwardWs, sdfForwardWs) > EPS_COL ? normalize(sdfForwardWs) : float3(0.0, 0.0, 1.0);

                float LdotR = dot(sdfLightDirection, sdfRightWs);
                float sdf = LdotR < 0.0 ? shadowMapSdfSample.g : shadowMapSdfSample.r;
                float lnSDF = dot(sdfLightDirection, sdfForwardWs);
                float sdfLight = saturate(lnSDF * 0.5 + sdf * 0.5 + 0.25);
                float sdfBlendedLight = lerp(sdfLight, shadeMapLight, shadowMapSdfSample.b);

                shadowInputs = sdfBlendedLight.xxx;
                shadowEdgeInput = sdfBlendedLight;
                shadowMaskChannels = shadowMapSdfSample.aaa;
                shadowMaskBorder = shadowMapSdfSample.a;
            }

            if (!ignoreShadowAoBorder)
            {
                shadowInputs *= shadowAoMask;
                shadowEdgeInput *= shadowAoMask.r;
            }

            float firstShadeFeatherStep = ShadowArea - shadowSoftness;
            float secondShadeFeatherStep = SecondShadowArea - secondShadowSoftness;
            float thirdShadeFeatherStep = ThirdShadowArea - thirdShadowSoftness;
            float mainShadowPresence = saturate(1.0 - ((shadowInputs.r - firstShadeFeatherStep) / max(ShadowArea - firstShadeFeatherStep, EPS_COL)));
            float secondShadowPresence = saturate(1.0 - ((shadowInputs.g - secondShadeFeatherStep) / max(SecondShadowArea - secondShadeFeatherStep, EPS_COL)));
            float thirdShadowPresence = saturate(1.0 - ((shadowInputs.b - thirdShadeFeatherStep) / max(ThirdShadowArea - thirdShadeFeatherStep, EPS_COL)));

            float mainShadowMask = mainShadowPresence;
            float secondShadowMask = secondShadowPresence;
            float thirdShadowMask = thirdShadowPresence;
            float shadowEdgeMask = BorderScale(1.0, shadowEdgeInput, ShadowArea, shadowSoftness, ShadowEdgeRange);

            float shadowMask1 = lerp(1.0, shadowMaskChannels.r, shadowMapStrength);
            float shadowMask2 = lerp(1.0, shadowMaskChannels.g, shadowMapStrength);
            float shadowMask3 = lerp(1.0, shadowMaskChannels.b, shadowMapStrength);
            shadowMaskBorder = lerp(1.0, shadowMaskBorder, shadowMapStrength);
            float3 shadowEnvironmentLighting = lerp(1.0.xxx, max(lightResponse, EPS_COL), saturate(ShadowEnvironmentStrength));
            float3 shadowBaseColor = color.rgb;

            // Multilayer shadowing already bakes light response into the layer masks.
            // Do not multiply by extra visibility here or the bands get weak and washed out.
            mainShadowMask *= ShadowIntensity * shadowMask1;
            secondShadowMask *= SecondShadowIntensity * shadowMask2;
            thirdShadowMask *= ThirdShadowIntensity * shadowMask3;
            if (ignoreShadowAoBorder)
            {
                mainShadowMask *= shadowAoMask.r;
                secondShadowMask *= shadowAoMask.g;
                thirdShadowMask *= shadowAoMask.b;
                shadowEdgeMask *= shadowAoMask.r;
            }
            shadowShadingPresence = saturate(max(mainShadowMask, max(secondShadowMask, thirdShadowMask)));

            float3 shadowLayerColor = lerp(shadowColor, secondShadowColor, secondShadowMask);
            shadowLayerColor = lerp(shadowLayerColor, thirdShadowColor, thirdShadowMask);
            shadowLayerColor *= shadowEnvironmentLighting;
            // Build the shadow result first, then recover the edge back toward the base color for edge tinting.
            float3 fullShadowColor = BlendShadowColor(shadowBaseColor, shadowLayerColor, 1.0, 1);
            float3 edgedShadowColor = lerp(fullShadowColor, shadowBaseColor, saturate(shadowEdgeMask * shadowMaskBorder * ShadowEdgeColor.rgb));
            color.rgb = lerp(shadowBaseColor, edgedShadowColor, mainShadowMask);
            debugShadingColor = color.rgb;
        }
        #elif S_SHADING_MODE == 2

        // TextureRamp is a ramp lookup, not a normal toon threshold. The texture itself defines the shade color.
        float rampSampleV = 0.5;
        if (RampUVMode > 0)
        {
            rampSampleV = saturate(uv1Coords.y);
        }
        float rampStrength = saturate(RampIntensity * RampTint.a);
        float rampLight = ComputeRampLight(RampOffset);
        float3 rampSample = SampleRampTexture(TextureRampTexture, rampLight, rampSampleV) * RampTint.rgb;
        float3 rampedLightMap = lerp(1.0.xxx, saturate(rampSample), rampStrength);
        #if S_ENABLED_EXTRA_LAYERS
        float secondRampStrength = saturate(SecondTextureRampIntensity * SecondTextureRampTint.a);
        float secondRampLight = ComputeRampLight(SecondTextureRampOffset);
        float3 secondRampSample = SampleRampTexture(SecondTextureRampTexture, secondRampLight, rampSampleV) * SecondTextureRampTint.rgb;
        rampedLightMap *= lerp(1.0.xxx, saturate(secondRampSample), secondRampStrength);
        #else
        float secondRampStrength = 0.0;
        #endif
        float rampLightValue = max(rampedLightMap.x, max(rampedLightMap.y, rampedLightMap.z));
        float rampShadowAmount = saturate(1.0 - rampLightValue);
        float rampEdgeMask = saturate(1.0 - abs(rampLightValue - 0.5) * 2.0) * rampShadowAmount;
        float3 rampShadowColor = color.rgb * rampedLightMap;
        rampShadowColor = lerp(rampShadowColor, rampShadowColor * ShadowTint.rgb, rampEdgeMask * saturate(ShadowTintIntensity));

        // Let ramp texture color peek through on black albedo without turning this into a toon shadow branch.
        float rampTexturePresence = saturate(1.0 - min(rampedLightMap.r, min(rampedLightMap.g, rampedLightMap.b)));
        float rampVisibilityOnBlack = saturate((1.0 - Luminance(color.rgb)) * rampTexturePresence * max(rampStrength, secondRampStrength) * 0.2);
        rampShadowColor += rampedLightMap * rampVisibilityOnBlack;

        color.rgb = rampShadowColor;
        shadowShadingPresence = rampShadowAmount;
        debugShadingColor = color.rgb;
        #elif S_SHADING_MODE == 3
        // Shademap mode: two texture-based shadow layers, simplified from Multi-layer Shading.
        // Replace mode intentionally slaps the shademap color over the base instead of multiplying it.
        float shadowVisibilitySM = saturate(max(lightIntensity, shadowLightScore));
        float shadeMapLightSM = saturate(shadowLightMap);
        float shadeMapAaSM = EPS_COL;

        float2 shademapUv = GetLayerBaseUv(ShademapUvMode);
        float3 sm1Sample = ShademapTexture.Sample(g_sAniso, shademapUv).rgb;
        float3 sm1SourceColor = UseMainColorAs1stShademap ? lit.rgb : sm1Sample;
        float3 sm1Color = ApplyShadowContrast(sm1SourceColor * ShademapTint.rgb, 1.0 + ShademapContrast);
        #if S_ENABLED_EXTRA_LAYERS
        float3 sm2Sample = SecondShademapTexture.Sample(g_sAniso, shademapUv).rgb;
        float3 sm2SourceColor = Use1stAsSecondShademap ? sm1SourceColor : sm2Sample;
        float3 sm2Color = ApplyShadowContrast(sm2SourceColor * SecondShademapTint.rgb, 1.0 + ShademapContrast);
        #endif

        float sm1Softness = max(ShademapSoftness * 0.5, shadeMapAaSM);
        #if S_ENABLED_EXTRA_LAYERS
        float sm2Softness = max(SecondShademapSoftness * 0.5, shadeMapAaSM);
        #endif

        float sm1FeatherStep = ShademapArea - sm1Softness;
        #if S_ENABLED_EXTRA_LAYERS
        float sm2FeatherStep = SecondShademapArea - sm2Softness;
        #endif

        float sm1Presence = saturate(1.0 - ((shadeMapLightSM - sm1FeatherStep) / max(ShademapArea - sm1FeatherStep, EPS_COL)));
        #if S_ENABLED_EXTRA_LAYERS
        float sm2Presence = saturate(1.0 - ((shadeMapLightSM - sm2FeatherStep) / max(SecondShademapArea - sm2FeatherStep, EPS_COL)));
        #endif

        float sm1Mask = sm1Presence * ShademapIntensity * shadowVisibilitySM;
        #if S_ENABLED_EXTRA_LAYERS
        float sm2Mask = sm2Presence * SecondShademapIntensity * shadowVisibilitySM;
        #else
        float sm2Mask = 0.0;
        float3 sm2Color = sm1Color;
        #endif

        // Layer 2 sits deeper than layer 1.
        float3 smLayerColor = lerp(sm1Color, sm2Color, sm2Mask);
        float3 smShadowBase = color.rgb;
        if (ShademapBlendMode == 1)
        {
            smLayerColor = smShadowBase * smLayerColor;
        }

        color.rgb = lerp(smShadowBase, smLayerColor, sm1Mask);
        shadowShadingPresence = saturate(max(sm1Mask, sm2Mask));
        debugShadingColor = color.rgb;
        #elif S_SHADING_MODE == 4
        shadowShadingPresence = 0.0;
        #endif

        #if S_SHADING_MODE != 1 && S_SHADING_MODE != 4 && S_SHADING_MODE != 5
        if (IsSelfShadowRuntimeActive())
        {
            float selfShadowMask = saturate(selfShadowOverrideAmount);
            float3 selfShadowBaseColor = color.rgb;
            float3 selfShadowLayerColor = 0.0.xxx;
            color.rgb = lerp(selfShadowBaseColor, selfShadowLayerColor, selfShadowMask);
            shadowShadingPresence = max(shadowShadingPresence, selfShadowMask);
            debugShadingColor = color.rgb;
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Wrap Shade And Backlit
        //-------------------------------------------------------------------------------------------------
        // Wrap Shade adds view-wrapped depth without fighting the main shadow bands.
        #if S_SHADING_MODE != 4
        if (WrapShadeEnabled && WrapShadeIntensity > EPS_COL)
        {
            float2 wrapShadeMaskUv = BuildStaticLayerUv(mainUv, WrapShadeMaskTiling, WrapShadeMaskOffset, WrapShadeMaskRotation);
            float wrapShadeMask = WrapShadeMaskTexture.Sample(g_sAniso, wrapShadeMaskUv).r;
            wrapShadeMask = ApplyInvertMask(wrapShadeMask, float(WrapShadeInvertMask));
            wrapShadeMask = ApplyMaskIntensity(wrapShadeMask, WrapShadeMaskIntensity);
            float3 wrapShadeNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(WrapNormalMapStrength)));
            float wrapViewFactor = abs(dot(wrapShadeNormalWs, viewRayWs));
            float wrapShadePower = max(WrapShadeFresnel * 0.5, EPS_COL);
            float wrapShadeFactor = pow(saturate(1.0 - wrapViewFactor), wrapShadePower);
            wrapShadeFactor = BorderScale(1.0, wrapShadeFactor, 1.0 - saturate(WrapShadeArea), WrapShadeSoftness);
            float3 wrapEnvironmentLighting = lerp(1.0.xxx, max(lightResponse, EPS_COL), saturate(WrapEnvironmentStrength));
            float3 wrapLightSide = lerp(1.0.xxx, WrapLightSideColor.rgb, saturate(WrapLightSideColor.a));
            float3 wrapShadeSide = lerp(1.0.xxx, WrapShadeColor.rgb, saturate(WrapShadeColor.a));
            float3 wrapColor = lerp(wrapLightSide, wrapShadeSide, wrapShadeFactor) * wrapEnvironmentLighting;
            float wrapShadeWeight = saturate(wrapShadeMask * WrapShadeIntensity * 2.0);
            color.rgb = lerp(color.rgb, color.rgb * saturate(wrapColor), wrapShadeWeight);
        }
        #endif

        // SubsurfaceScattering and backlit sit after wrap shade so transmitted light stays additive.
        if (!postProcessPixelIsFurShell)
        {
            #if S_SHADING_MODE != 5
            if (SubsurfaceScatteringEnabled && SubsurfaceScatteringIntensity > EPS_COL)
            {
                float3 SubsurfaceScatteringUnlit = SubsurfaceScatteringEmissionAccumulated;
                float3 SubsurfaceScatteringLighting = SubsurfaceScatteringAccumulated;
                SubsurfaceScatteringLighting += SubsurfaceScatteringUnlit * max(SubsurfaceScatteringEmission, 0.0);
                color.rgb += SubsurfaceScatteringLighting;
            }
            #endif
            color.rgb += backlightAccumulated + backlightEmissionAccumulated * max(BacklitEmission, 0.0);
        }

        //-------------------------------------------------------------------------------------------------
        // PostProcess: PBR Reflections And Cubemap
        //-------------------------------------------------------------------------------------------------
        // Direct reflections sit above the backlit base before the later stylized passes.
        // This keeps highlights visible even when toon shading is strong.
        #if S_SHADING_MODE != 5
            if (IsPbrLightingActive() && (SpecularMode > 0 || EnvmapReflections))
            {
                float3 pbrLightingAdaptation = lerp(1.0.xxx, max(lightResponse, EPS_COL), saturate(SpecularLightingMix));
                float3 specularReflectionLayer = reflectionAccumulated * pbrLightingAdaptation;
                float3 envmapReflectionLayer = reflectionEnvmapAccumulated * pbrLightingAdaptation;
                #if S_SHADING_MODE == 4
                    envmapReflectionLayer *= realisticAoFactor;
                #endif

                // Keeps toon specular strength in the highlight mask itself, not smoothness/metallic response.
                if (SpecularMode == 1)
                {
                    float3 toonSpecularSrcCol = toonSpecularSrcColor * pbrLightingAdaptation;
                    float toonSpecularBlend = toonSpecularBlendWeight;
                    if (toonSpecularBlend > EPS_COL)
                    {
                        color.rgb = ToonSpecularBlendColor(color.rgb, toonSpecularSrcCol, toonSpecularBlend, SpecularBlendMode);
                    }

                    float envmapStrength = max(max(envmapReflectionLayer.r, envmapReflectionLayer.g), envmapReflectionLayer.b);
                    if (envmapStrength > EPS_COL)
                    {
                        float3 envmapLayer = BuildReflectionBlendColor(envmapReflectionLayer, SpecularBlendMode);
                        color.rgb = BlendSpecularColor(color.rgb, envmapLayer, SpecularBlendMode, reflectionPbrResponse);
                    }
                }
                else
                {
                    float3 reflectionLayerRaw = specularReflectionLayer + envmapReflectionLayer;
                    float reflectionLayerStrength = max(max(reflectionLayerRaw.r, reflectionLayerRaw.g), reflectionLayerRaw.b);
                    if (reflectionLayerStrength > EPS_COL)
                    {
                        float3 reflectionLayer = BuildReflectionBlendColor(reflectionLayerRaw, SpecularBlendMode);
                        color.rgb = BlendSpecularColor(color.rgb, reflectionLayer, SpecularBlendMode, reflectionPbrResponse);
                    }
                }
            }
        #endif

        // User cubemap overlay. This samples an explicit cube texture, separate from scene envmaps.
        // Explicit cubemap overlay, separate from scene envmaps. Fur keeps it disabled for texture budget.
        #if S_SHADING_MODE != 5
        if (CubemapEnabled && CubemapIntensity > EPS_COL)
        {
            float3 cubemapDirection = BuildCubemapDirection();
            float4 cubemapSample = CubemapTexture.SampleLevel(g_sAniso, cubemapDirection, ComputeCubemapMip());
            float2 cubemapMaskUv = BuildStaticLayerUv(mainUv, CubemapMaskTiling, CubemapMaskOffset, CubemapMaskRotation);
            float cubemapMask = CubemapMaskTexture.Sample(g_sAniso, cubemapMaskUv).r;
            float3 cubemapLighting = lerp(1.0.xxx, max(lightResponse, EPS_COL), saturate(CubemapLightingMix));
            float3 cubemapColor = cubemapSample.rgb * CubemapTint.rgb * CubemapIntensity * cubemapLighting;
            float cubemapWeight = saturate(CubemapTint.a * cubemapMask);
            color.rgb = BlendCubemapColor(color.rgb, cubemapColor, cubemapWeight);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Matcap Layers
        //-------------------------------------------------------------------------------------------------
        if (!postProcessPixelIsFurShell && MatcapEnabled && MatcapIntensity > EPS_COL)
        {
            float3 matcapBaseNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(MatcapNormalMapStrength)));
            // Project the normal onto the camera plane for matcap sampling.
            float2 matcapUv = CalcMatcapUv(matcapBaseNormalWs, viewRayWs);
            float matcapMip = MatcapSoftness * 8.0;
            float4 matcapSample = MatCapTexture.SampleLevel(g_sAniso, matcapUv, matcapMip);
            float3 matcapTinted = ApplyMatcapTintColor(matcapSample.rgb, MatcapTint, MatcapTintIntensity);
            // Mask with the model UVs, not the matcap UVs.
            float2 matcapMaskUv = BuildStaticLayerUv(mainUv, MatcapMaskTiling, MatcapMaskOffset, MatcapMaskRotation);
            float matcapMask = MatCapMask.Sample(g_sAniso, matcapMaskUv).r;
            matcapMask = ApplyInvertMask(matcapMask, float(MatcapInvertMask));
            matcapMask = ApplyMaskIntensity(matcapMask, MatcapMaskIntensity);

            // Matcap can be mixed with main color and lighting.
            float3 matcapMainMixed = lerp(matcapTinted, matcapTinted * lit.rgb, saturate(MatcapMainColorMix));
            float3 matcapLighting = matcapMainMixed * lerp(1.0.xxx, lightResponse, saturate(MatcapLightingMix));
            float3 matcapFinal = ApplyColorAdjustments(matcapLighting, MatcapHue, MatcapHueShiftSpeed, MatcapBrightness, MatcapSaturation, MatcapGamma, MatcapHueColorSpace, MatcapHueMode);
            float matcapShadowVisibility = ApplyShadowShadingMask(shadowShadingPresence, MatcapShadowMask);
            float matcapWeight = saturate(MatcapIntensity * matcapSample.a * matcapMask);
            matcapWeight *= matcapShadowVisibility;
            color.rgb = BlendLayerColor(color.rgb, matcapFinal, matcapWeight, MatcapBlendMode);
        }

        // Optional second matcap layer. Compiled out unless Extra Layers is enabled.
        #if S_ENABLED_EXTRA_LAYERS
        if (!postProcessPixelIsFurShell && SecondMatcapEnabled && SecondMatcapIntensity > EPS_COL)
        {
            float3 matcap2BaseNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(SecondMatcapNormalMapStrength)));
            float2 matcap2Uv = CalcMatcapUv(matcap2BaseNormalWs, viewRayWs);
            float matcap2Mip = SecondMatcapSoftness * 8.0;
            float4 matcap2Sample = SecondMatcapTexture.SampleLevel(g_sAniso, matcap2Uv, matcap2Mip);
            float3 matcap2Tinted = ApplyMatcapTintColor(matcap2Sample.rgb, SecondMatcapTint, SecondMatcapTintIntensity);
            float2 matcap2MaskUv = BuildStaticLayerUv(mainUv, SecondMatcapMaskTiling, SecondMatcapMaskOffset, SecondMatcapMaskRotation);
            float matcap2Mask = SecondMatcapMaskTexture.Sample(g_sAniso, matcap2MaskUv).r;
            matcap2Mask = ApplyInvertMask(matcap2Mask, float(SecondMatcapInvertMask));
            matcap2Mask = ApplyMaskIntensity(matcap2Mask, SecondMatcapMaskIntensity);
            float3 matcap2MainMixed = lerp(matcap2Tinted, matcap2Tinted * lit.rgb, saturate(SecondMatcapMainColorMix));
            float3 matcap2Lighting = matcap2MainMixed * lerp(1.0.xxx, lightResponse, saturate(SecondMatcapLightingMix));
            float3 matcap2Final = ApplyColorAdjustments(matcap2Lighting, SecondMatcapHue, SecondMatcapHueShiftSpeed, SecondMatcapBrightness, SecondMatcapSaturation, SecondMatcapGamma, SecondMatcapHueColorSpace, SecondMatcapHueMode);
            float matcap2ShadowVisibility = ApplyShadowShadingMask(shadowShadingPresence, SecondMatcapShadowMask);
            float matcap2Weight = saturate(SecondMatcapIntensity * matcap2Sample.a * matcap2Mask);
            matcap2Weight *= matcap2ShadowVisibility;
            color.rgb = BlendLayerColor(color.rgb, matcap2Final, matcap2Weight, SecondMatcapBlendMode);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Rim Lighting
        //-------------------------------------------------------------------------------------------------
        // Rim Lighting adds a colored silhouette lift.
        bool useMainRimLighting = !postProcessPixelIsFurShell;
        if (useMainRimLighting && RimLightingEnabled && RimLightingIntensity > EPS_COL)
        {
            float4 rimSample = RimLightingColor;
            float3 rimSurfaceBase = lit.rgb;
            float rimMainColorMix = saturate(RimLightingMainColorMix);
            float3 rimColor = lerp(rimSample.rgb, rimSample.rgb * rimSurfaceBase, rimMainColorMix);
            float4 rimIndirectTint = RimLightingIndirectTint;
            float3 rimNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(RimLightingNormalMapStrength)));
            float rimViewFactor = abs(dot(rimNormalWs, viewRayWs));
            float rimFresnel = pow(saturate(1.0 - rimViewFactor), max(RimLightingFresnelPower, EPS_COL));

            // Rim lighting follows the shared light response by default. Rim Emission adds a self-lit lift on top.
            float3 rimLighting = max(lightResponse, EPS_COL);
            float3 rimFinal = rimColor * (rimLighting + RimLightingEmission);

            // Mask and weight the rim effect.
            float2 rimLightingMaskUv = BuildStaticLayerUv(mainUv, RimLightingMaskTiling, RimLightingMaskOffset, RimLightingMaskRotation);
            float rimMaskValue = RimLightingMaskTexture.Sample(g_sAniso, rimLightingMaskUv).r;
            rimMaskValue = ApplyInvertMask(rimMaskValue, float(RimLightingInvertMask));
            rimMaskValue = ApplyMaskIntensity(rimMaskValue, RimLightingMaskIntensity);
            float rimShadowVisibility = ApplyShadowShadingMask(shadowShadingPresence, RimLightingShadowMask);
            float rimVisibility = rimSample.a * rimMaskValue * RimLightingIntensity * rimShadowVisibility;
            // In Translucent mode, scale rim by surface alpha so transparent parts fade out cleanly.
            #if S_ALPHA_MODE == 2
            if (RimLightingUseAlpha) rimVisibility *= alpha;
            #endif

            float rimDirectionalStrength = saturate(RimLightingDirectionalStrength);
            if (rimDirectionalStrength > EPS_COL)
            {
                float shadowDirectionValid = step(EPS_COL, dot(shadowLightDirectionWs, shadowLightDirectionWs));
                float rimDirectionalMix = rimDirectionalStrength * shadowDirectionValid;
                rimDirectionalMix = rimDirectionalMix * rimDirectionalMix * (3.0 - 2.0 * rimDirectionalMix);
                float lnRaw = dot(rimNormalWs, shadowLightDirectionWs);
                float directDirectional = saturate((lnRaw + RimLightingDirectionalWidth) / max(1.0 + RimLightingDirectionalWidth, EPS_COL));
                directDirectional = smoothstep(0.0, 1.0, directDirectional);
                float indirectDirectional = saturate((1.0 - lnRaw + RimLightingIndirectWidth) / max(1.0 + RimLightingIndirectWidth, EPS_COL));
                indirectDirectional = smoothstep(0.0, 1.0, indirectDirectional);

                float rimDirect = TooningScale(1.0, saturate(lerp(rimFresnel, rimFresnel * directDirectional, rimDirectionalMix)), 1.0 - RimLightingArea, RimLightingSoftness);
                float rimIndirect = TooningScale(1.0, saturate(lerp(rimFresnel, rimFresnel * indirectDirectional, rimDirectionalMix)), 1.0 - RimLightingIndirectArea, RimLightingIndirectSoftness);

                rimDirect = RimLightInvert ? 1.0 - rimDirect : rimDirect;
                rimIndirect = RimLightInvert ? 1.0 - rimIndirect : rimIndirect;

                float directWeight = saturate(rimDirect * rimVisibility);
                float indirectWeight = saturate(rimIndirect * rimVisibility * rimIndirectTint.a);
                float3 rimIndirectFinal = rimColor * rimIndirectTint.rgb * (rimLighting + RimLightingEmission);
                float rimCombinedWeight = saturate(directWeight + indirectWeight);
                float3 rimCombinedColor = (rimFinal * directWeight + rimIndirectFinal * indirectWeight) / max(rimCombinedWeight, EPS_COL);

                color.rgb = BlendLayerColor(color.rgb, rimCombinedColor, rimCombinedWeight, RimLightingBlendMode);
            }
            else
            {
                float rimFactor = TooningScale(1.0, rimFresnel, 1.0 - RimLightingArea, RimLightingSoftness);
                rimFactor = RimLightInvert ? 1.0 - rimFactor : rimFactor;
                float rimWeight = saturate(rimFactor * rimVisibility);
                color.rgb = BlendLayerColor(color.rgb, rimFinal, rimWeight, RimLightingBlendMode);
            }
        }

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Emission Layers
        //-------------------------------------------------------------------------------------------------
        // Emission is self-lit color. Fluorescence can bias it toward darker lighting areas.
        float3 inverseLighting = 1.0.xxx - saturate(lightResponse);
        float3 emissionLayer = 0.0.xxx;
        float emissionWeight = 0.0;
        if (EmissionEnabled && EmissionIntensity > EPS_COL)
        {
            float2 emissionBaseUv = GetLayerBaseUv(EmissionUvMode);
            float2 emissionUv = BuildLayerUv(emissionBaseUv, EmissionTiling, EmissionOffset, EmissionScroll, EmissionRotate, EmissionRotation);
            float4 emissionSample = EmissionTexture.Sample(g_sAniso, emissionUv);
            if (EmissionCenterOutEnabled && EmissionMapType == 1)
            {
                emissionSample = EmissionTexture.Sample(g_sAniso, BuildEmissionCenterOutUv(EmissionTiling, EmissionCenterOutFlowSpeed / 1.5, float(EmissionCenterOutInvert)));
            }
            if (EmissionMapType == 2)
            {
                emissionSample = float4(SampleGradientMapTexture(EmissionTexture, lit.rgb), 1.0);
            }
            if (UseEmissionMapAsMaskOnly && EmissionMapType == 1)
            {
                emissionSample.a = dot(emissionSample.rgb, float3(0.299, 0.587, 0.114));
                emissionSample.rgb = lit.rgb;
            }
            if (EmissionMapInvert)
            {
                if (UseEmissionMapAsMaskOnly && EmissionMapType == 1)
                    emissionSample.a = 1.0 - emissionSample.a;
                else
                    emissionSample = float4(1.0.xxx - emissionSample.rgb, 1.0 - emissionSample.a);
            }
            float emissionBlink = EmissionBlinkingEnabled ? ComputeBlinkFactor(EmissionBlinkingMode, EmissionBlinkingStrength, EmissionBlinkingSpeed) : 1.0;
            float3 emissionAdjusted = ApplyColorAdjustments(emissionSample.rgb, EmissionHue, EmissionHueShiftSpeed, EmissionBrightness, EmissionSaturation, EmissionGamma, EmissionHueColorSpace, EmissionHueMode);
            emissionLayer = emissionAdjusted * EmissionIntensity * emissionBlink;
            emissionLayer = lerp(emissionLayer, emissionLayer * inverseLighting, saturate(EmissionFluorescence));
            emissionLayer *= lerp(1.0.xxx, lightResponse, saturate(EmissionLightingMix));
            emissionWeight = saturate(emissionSample.a);
            color.rgb = BlendLayerColor(color.rgb, emissionLayer, emissionWeight, EmissionBlendMode);
        }

        // Optional second emission layer. Compiled out unless Extra Layers is enabled.
        float3 emission2Layer = 0.0.xxx;
        float emission2Weight = 0.0;
        #if S_ENABLED_EXTRA_LAYERS
        if (SecondEmissionEnabled && SecondEmissionIntensity > EPS_COL)
        {
            float2 emission2BaseUv = GetLayerBaseUv(SecondEmissionUvMode);
            float2 emission2ParallaxUv = emission2BaseUv + GetLayerParallaxOffset(SecondEmissionUvMode) * SecondEmissionParallaxStrength;
            float2 emission2Uv = BuildLayerUv(emission2ParallaxUv, SecondEmissionTiling, SecondEmissionOffset, SecondEmissionScroll, SecondEmissionRotate, SecondEmissionRotation);
            float4 emission2Sample = SecondEmissionTexture.Sample(g_sAniso, emission2Uv);
            if (SecondEmissionCenterOutEnabled && SecondEmissionMapType == 1)
            {
                emission2Sample = SecondEmissionTexture.Sample(g_sAniso, BuildEmissionCenterOutUv(SecondEmissionTiling, SecondEmissionCenterOutFlowSpeed, float(SecondEmissionCenterOutInvert)));
            }
            if (SecondEmissionMapType == 2)
            {
                emission2Sample = float4(SampleGradientMapTexture(SecondEmissionTexture, lit.rgb), 1.0);
            }
            if (UseSecondEmissionMapAsMaskOnly && SecondEmissionMapType == 1)
            {
                emission2Sample.a = dot(emission2Sample.rgb, float3(0.299, 0.587, 0.114));
                emission2Sample.rgb = lit.rgb;
            }
            if (SecondEmissionMapInvert)
            {
                if (UseSecondEmissionMapAsMaskOnly && SecondEmissionMapType == 1)
                    emission2Sample.a = 1.0 - emission2Sample.a;
                else
                    emission2Sample = float4(1.0.xxx - emission2Sample.rgb, 1.0 - emission2Sample.a);
            }
            float emission2Blink = SecondEmissionBlinkingEnabled ? ComputeBlinkFactor(SecondEmissionBlinkingMode, SecondEmissionBlinkingStrength, SecondEmissionBlinkingSpeed) : 1.0;
            float3 emission2Adjusted = ApplyColorAdjustments(emission2Sample.rgb, SecondEmissionHue, SecondEmissionHueShiftSpeed, SecondEmissionBrightness, SecondEmissionSaturation, SecondEmissionGamma, SecondEmissionHueColorSpace, SecondEmissionHueMode);
            emission2Layer = emission2Adjusted * SecondEmissionIntensity * emission2Blink;
            emission2Layer = lerp(emission2Layer, emission2Layer * inverseLighting, saturate(SecondEmissionFluorescence));
            emission2Layer *= lerp(1.0.xxx, lightResponse, saturate(SecondEmissionLightingMix));
            emission2Weight = saturate(emission2Sample.a);
            color.rgb = BlendLayerColor(color.rgb, emission2Layer, emission2Weight, SecondEmissionBlendMode);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Glitter
        //-------------------------------------------------------------------------------------------------
        if (!postProcessPixelIsFurShell && GlitterEnabled && GlitterIntensity > EPS_COL)
        {
            float3 glitterLayer = glitterAccumulated * glitterBaseColor * GlitterIntensity;
            glitterLayer = lerp(glitterLayer, glitterLayer * lit.rgb, saturate(GlitterMainColorMix));
            glitterLayer *= lerp(1.0.xxx, max(lightResponse, EPS_COL), saturate(GlitterLightingMix));
            color.rgb += glitterLayer;
        }

        //-------------------------------------------------------------------------------------------------
        // PostProcess: Debug Override
        //-------------------------------------------------------------------------------------------------
        debugResultValid = false;
        debugResultColor = 0.0.xxx;
        // Debug output is chosen last so it can inspect the final lighting/shading state.
        if (LightingDebugging == 1)
        {
            debugResultColor = BuildDebugColor(directSurfaceLighting, GetDebugMaskValue(directSurfaceLighting));
            debugResultValid = true;
        }
        else if (LightingDebugging == 2)
        {
            debugResultColor = BuildDebugColor(debugAmbientLighting, GetDebugMaskValue(debugAmbientLighting));
            debugResultValid = true;
        }
        else if (LightingDebugging == 3)
        {
            debugResultColor = BuildDebugColor(1.0.xxx, debugAttenuation);
            debugResultValid = true;
        }
        else if (LightingDebugging == 4)
        {
            debugResultColor = BuildDebugColor(debugDirectionalColor, debugDirectionalFactor);
            debugResultValid = true;
        }
        else if (ShadingDebugging)
        {
            debugResultColor = max(debugShadingColor, 0.0.xxx);
            debugResultValid = true;
        }

        return float4(color.rgb, alpha);
	}

    //-------------------------------------------------------------------------------------------------
    // Pipeline: Pixel Shader Entry Point
    //-------------------------------------------------------------------------------------------------
 	// Main pixel shader entry point.
 	float4 MainPs( PixelInput i ) : SV_Target0
	{
        // Start from clean material defaults.
        Material m = Material::Init();
        m.Opacity = 1.0;
        bool currentPixelIsOutline = i.isOutline > 0.5;
        bool currentPixelIsFurShell = i.furShell > EPS_COL;
        float3 worldPosition = i.vPositionWithOffsetWs + g_vCameraPositionWs;

        //-------------------------------------------------------------------------------------------------
        // MainPs: Material Seed
        //-------------------------------------------------------------------------------------------------
        // Fill material data needed by Depth(), tools, and our custom lighting helpers.
        m.WorldPosition = worldPosition;
        m.ScreenPosition = i.vPositionSs;
        m.WorldTangentU = i.vTangentUWs;
        m.WorldTangentV = i.vTangentVWs;
        m.TextureCoords = i.vTextureCoords.xy;
        m.LightmapUV = i.vLightmapUV;

        //-------------------------------------------------------------------------------------------------
        // MainPs: Base UV Setup
        //-------------------------------------------------------------------------------------------------
        float2 uv0Coords = i.vTextureCoords.xy;
        float2 uv1CoordsLocal = i.vTextureCoords.zw;
        rawUv0 = uv0Coords;
        rawUv1 = uv1CoordsLocal;
        surfaceUv0 = uv0Coords;
        surfaceUv1 = uv1CoordsLocal;

        //-------------------------------------------------------------------------------------------------
        // MainPs: Parallax UV Offset
        //-------------------------------------------------------------------------------------------------
        // POM happens before texture sampling because it changes the UVs used by color/detail layers.
        #if S_ENABLE_EXPENSIVE_FEATURES && S_SHADING_MODE == 4
        if (PomEnabled && !currentPixelIsOutline)
        {
            float3 pomViewDirectionWs = CalculatePositionToCameraDirWs(worldPosition);
            float3 pomGeometricNormalWs = normalize(float3(i.vNormalWs.x, i.vNormalWs.y, i.vNormalWs.z));
            float3 pomTangentViewDirection = ComputeTangentViewDirection(pomViewDirectionWs, i.vTangentUWs, i.vTangentVWs, pomGeometricNormalWs);
            if (UsePomUv1(uv1CoordsLocal))
            {
                surfaceUv1 = ApplyPomSurfaceUv(uv1CoordsLocal, pomTangentViewDirection);
            }
            else
            {
                surfaceUv0 = ApplyPomSurfaceUv(uv0Coords, pomTangentViewDirection);
            }
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // MainPs: Main Normal Map
        //-------------------------------------------------------------------------------------------------
        float3 mainNormalTs = float3(0.0, 0.0, 1.0);
        if (NormalMapEnabled && NormalIntensity > EPS_COL)
        {
            float2 mainNormalUv = BuildLayerUv(surfaceUv0, NormalTiling, NormalOffset, NormalScroll, NormalRotate, NormalRotation);
            mainNormalTs = DecodeNormal(NormalMapTexture.Sample(g_sAniso, mainNormalUv).rgb);
            mainNormalTs = ApplyNormalStrength(mainNormalTs, NormalIntensity);
        }

        //-------------------------------------------------------------------------------------------------
        // MainPs: Extra Normal Layer
        //-------------------------------------------------------------------------------------------------
        float3 normal2Ts = float3(0.0, 0.0, 1.0);
        #if S_ENABLED_EXTRA_LAYERS
        if (SecondNormalEnabled && SecondNormalIntensity > EPS_COL)
        {
            float2 normal2BaseUv = SelectUvSet(surfaceUv0, surfaceUv1, SecondNormalUvMode);
            float2 normal2Uv = BuildLayerUv(normal2BaseUv, SecondNormalTiling, SecondNormalOffset, SecondNormalScroll, SecondNormalRotate, SecondNormalRotation);
            float2 normal2MaskUv = BuildStaticLayerUv(normal2BaseUv, SecondNormalMaskTiling, SecondNormalMaskOffset, SecondNormalMaskRotation);
            float normal2Mask = SecondNormalMaskTexture.Sample(g_sAniso, normal2MaskUv).r;
            normal2Mask = ApplyInvertMask(normal2Mask, float(SecondNormalMaskInvert));
            normal2Mask = ApplyMaskIntensity(normal2Mask, SecondNormalMaskIntensity);
            normal2Ts = DecodeNormal(SecondNormalMapTexture.Sample(g_sAniso, normal2Uv).rgb);
            normal2Ts = ApplyNormalStrength(normal2Ts, SecondNormalIntensity * normal2Mask);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // MainPs: Fur Shell Normal
        //-------------------------------------------------------------------------------------------------
        float3 combinedNormalTs = BlendTangentNormals(mainNormalTs, normal2Ts);
        #if S_SHADING_MODE == 5
        if (currentPixelIsFurShell)
        {
            // Fur shells get their own normal map. The base mesh keeps the regular normal stack.
            float2 furNormalUv = surfaceUv0 * FurNormalTiling + FurNormalOffset;
            float3 furNormalTs = DecodeFurShadingNormalSample(FurNormalTexture.Sample(g_sAniso, furNormalUv).rgb, FurNormalMapIntensity);
            combinedNormalTs = BlendTangentNormals(combinedNormalTs, furNormalTs);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // MainPs: Final World Normal
        //-------------------------------------------------------------------------------------------------
        m.Normal = TransformNormal(combinedNormalTs, i.vNormalWs, i.vTangentUWs, i.vTangentVWs);

        //-------------------------------------------------------------------------------------------------
        // MainPs: Shared Shading State
        //-------------------------------------------------------------------------------------------------
        // Populate the shared shading state for the lighting passes.
        Init(i, m);
        worldTangentUWs = i.vTangentUWs;
        worldTangentVWs = i.vTangentVWs;

        // Sample ambient once here so both the outline early-return path and the main lighting path can reuse it.
        float3 ambientSampleForPixel = 0.0.xxx;
        #if S_SHADING_MODE == 4
            // Realistic: use native engine directional ambient — respects the actual surface normal.
            ambientSampleForPixel = SampleStableAmbient(worldPosition, m.ScreenPosition, i.vNormalWs);
        #else
            // Toon modes: orientation-independent ambient so shading bands stay consistent.
            // Mode 1 = Fast (Z+/Z-, 2 samples), Mode 2 = Quality (6-axis, default).
            if (IndirectLightingMode == 1)
                ambientSampleForPixel = SampleFastToonAmbient(worldPosition, m.ScreenPosition);
            else
                ambientSampleForPixel = SampleToonAmbient(worldPosition, m.ScreenPosition, i.vNormalWs);
        #endif
        cachedAmbientSample = ApplyShaderLightControls(max(ambientSampleForPixel, float3(EPS_COL, EPS_COL, EPS_COL)));

        //-------------------------------------------------------------------------------------------------
        // MainPs: Backface And Outline Path
        //-------------------------------------------------------------------------------------------------
        // Face normal used by the outline branch.
        float3 ddxPos = ddx(i.vPositionWithOffsetWs);
        float3 ddyPos = ddy(i.vPositionWithOffsetWs);
        float3 flatNormalWs = normalize(cross(ddyPos, ddxPos));
        
        // Keep body lighting stable and reserve the geometric normal for outline checks.
        shadowNormalWs = geometricNormalWs;
        shadowShadeNormalWs = normalize(normalWs);
        
        // Outline lighting uses a separate response so outlines stay readable under strong scene lighting.
        float3 outlineLightResponse = saturate(lighting + indirectLighting);

        // Determine face orientation once. Body culling is handled below in shader code so generated outlines remain stable.
        float faceAlignment = dot(flatNormalWs, geometricNormalWs);
        bool isBackFace = faceAlignment < 0.0;
        isBackFacePixel = isBackFace;

        // Match the two-sided backface path by flipping the lighting normals for back-facing pixels.
        if ( FlipBackfaceNormal > 0 && isBackFace )
        {
            shadowNormalWs = -shadowNormalWs;
            shadowShadeNormalWs = -shadowShadeNormalWs;
        }

        if (isOutline)
        {
            // Keep only silhouette-facing outline pixels.
            if (!isBackFace)
            {
                discard;
            }

            clip(float(OutlineEnabled) - 0.5);

            // Sample outline color and mask in model UV space.
            float2 outlineColorUv = BuildStaticLayerUv(mainUv, OutlineColorTiling, OutlineColorOffset, OutlineColorRotation);
            float2 outlineMaskUv = BuildStaticLayerUv(mainUv, OutlineMaskTiling, OutlineMaskOffset, OutlineMaskRotation);
            float4 outlineSample = OutlineColorTexture.Sample(g_sAniso, outlineColorUv);
            float outlineMask = OutlineMaskTexture.Sample(g_sAniso, outlineMaskUv).r;
            outlineMask = ApplyInvertMask(outlineMask, float(OutlineInvertMask));
            float outlineWeight = saturate(ApplyMaskIntensity(outlineMask, OutlineMaskIntensity) * outlineSample.a);

            // Skip outline pixels that end up with zero coverage.
            clip(outlineWeight - 0.0001);

            // Outline tint is separate from base color tint so line art can be pushed independently.
            float outlineTintAmount = saturate(OutlineTintIntensity * 2.0);
            float3 outlineTintMask = lerp(1.0.xxx, OutlineTint.rgb, outlineTintAmount);
            float3 outlineTintedColor = outlineSample.rgb * outlineTintMask;
            float3 outlineBaseColor = ApplyColorAdjustments( outlineTintedColor, OutlineHue, OutlineHueShiftSpeed, OutlineBrightness, OutlineSaturation, OutlineGamma, OutlineHueColorSpace, OutlineHueMode );

            // The outline can optionally get a special lighting response.
            float3 outlineDarkColor = outlineBaseColor * 0.01;
            float3 outlineColor = outlineBaseColor;
            if ( OutlineMode > 0 )
            {
                float outlineRimFactor = 0.0;
                float3 directionalLightColor = ApplyShaderLightControls(max(g_DirectionalLightColor.rgb, 0.0.xxx));
                float directionalLightStrength = max(directionalLightColor.x, max(directionalLightColor.y, directionalLightColor.z));
                if ( directionalLightStrength > EPS_COL )
                {
                    float3 sunDirectionWs = ResolveOverwriteLightDirection(normalize(-g_DirectionalLightDirection.xyz));
                    float outlineFacing = saturate(dot(normalize(shadowNormalWs), sunDirectionWs));
                    outlineRimFactor = saturate(outlineFacing * directionalLightStrength);
                }

                outlineColor = lerp(outlineBaseColor, HighlightColor.rgb, outlineRimFactor * saturate(HighlightIntensity));
            }
            else if ( OutlineLightingMix > 0 )
            {
                // cachedAmbientSample is valid here (written right after Init(), before the outline branch).
                // The 6-axis ambient re-sample is gone. The light loop below is kept because
                // light.Attenuation varies per-pixel (distance falloff), which is what makes
                // outlines actually respond to local scene lighting.
                float outlineAmbientBrightness = Luminance( max( cachedAmbientSample, EPS_COL ) );

                float outlineDirectBrightness = 0.0;
                int outlineLightCount = Light::Count( m.ScreenPosition );
                for ( int li = 0; li < outlineLightCount; li++ )
                {
                    Light light = Light::From( worldPosition, m.ScreenPosition, li, m.LightmapUV );
                    float3 attenuatedColor = ApplyShaderLightControls(max( light.Color, 0.0.xxx )) * saturate( light.Attenuation );
                    outlineDirectBrightness += Luminance( attenuatedColor );
                }

                // Shape the response so lit areas keep more of the base outline color.
                float outlineTotalBrightness = saturate( ( outlineAmbientBrightness + outlineDirectBrightness ) * 1.25 );
                outlineTotalBrightness = pow( outlineTotalBrightness, 1.15 );
                outlineColor = lerp( outlineDarkColor, outlineBaseColor, outlineTotalBrightness );
            }
            return float4(outlineColor, outlineWeight);
        }
        if (CullingMode == 4)
        {
            clip(-1.0);
        }
        if (CullingMode == 2 && !isBackFace)
        {
            clip(-1.0);
        }
        if (CullingMode == 3 && isBackFace)
        {
            clip(-1.0);
        }

        //-------------------------------------------------------------------------------------------------
        // MainPs: Custom Lighting Pass
        //-------------------------------------------------------------------------------------------------
        // Restore the body shading normal before the main lighting pass.
        m.Normal = normalWs;

        // Start the main lighting pass with the base color and a clean lighting state.
        float3 vLightResult = float3(0,0,0);
        float3 unlitBase = lit.rgb;
        lighting = 0.0.xxx;
        lightIntensity = 0.0;
        shadowLightMap = 0.0;
        shadowLightScore = 0.0;
        shadowLightDirectionWs = 0.0.xxx;
        selfShadowOverrideAmount = 0.0;
        selfShadowLightScore = 0.0;
        hasDirectionalLightInLoop = false;
        reflectionAccumulated = 0.0.xxx;
        toonSpecularSrcColor = 0.0.xxx;
        toonSpecularBlendWeight = 0.0;
        directSurfaceLighting = 0.0.xxx;
        indirectSurfaceLighting = 0.0.xxx;
        realisticDirectionalShade = 1.0;
        #if S_SHADING_MODE != 5
        SubsurfaceScatteringAccumulated = 0.0.xxx;
        SubsurfaceScatteringEmissionAccumulated = 0.0.xxx;
        #endif
        backlightAccumulated = 0.0.xxx;
        backlightEmissionAccumulated = 0.0.xxx;
        glitterAccumulated = 0.0.xxx;
        SecondColorUnlitColor = 0.0.xxx;
        SecondColorUnlitWeight = 0.0;
        debugAttenuation = 0.0;
        debugDirectionalFactor = 0.0;
        debugDirectionalColor = 0.0.xxx;
        debugAmbientLighting = 0.0.xxx;
        debugResultColor = 0.0.xxx;
        debugResultValid = false;

        float4 indirectResult = Indirect(i, m);
        debugAmbientLighting = indirectLighting;

        // Sample all visible direct lights. Direct() also fills shadow/specular feature accumulators.
		int lightCount = Light::Count(m.ScreenPosition);
        if (lightCount == 0)
        {
            vLightResult = 0.0.xxx;
        }
        else
        {
            for (int index = 0; index < lightCount; index++)
            {
                Light light = Light::From(worldPosition, m.ScreenPosition, index, m.LightmapUV);
                vLightResult += Direct(i, m, light).rgb;
            }
        }

        // Directional-light fallback. Some scenes expose the sun globally even when it is not in Light::Count().
        float3 directionalLightColor = ApplyShaderLightControls(max(g_DirectionalLightColor.rgb, 0.0.xxx));
        float directionalLightStrength = max(directionalLightColor.x, max(directionalLightColor.y, directionalLightColor.z));
        // Compute sun direction once and share it across all post-loop sun blocks.
        float3 sharedSunDirectionWs = g_DirectionalLightEnabled ? ResolveOverwriteLightDirection(normalize(-g_DirectionalLightDirection.xyz)) : ResolveOverwriteLightDirection(float3(0.0, 0.0, 1.0));
        float3 visibleDirectionalSourceColor = directionalLightColor;
        float3 visibleDirectionalLightColor = visibleDirectionalSourceColor;
        if (shadowLightScore <= EPS_COL && g_DirectionalLightEnabled && directionalLightStrength > EPS_COL)
        {
            float directionalShadowWrap = saturate(dot(sharedSunDirectionWs, shadowShadeNormalWs) * 0.5 + 0.5);
            float directionalShadowMapValue = directionalShadowWrap * directionalLightStrength;
            shadowLightMap = directionalShadowMapValue;
            shadowLightScore = directionalLightStrength;
            shadowLightDirectionWs = sharedSunDirectionWs;
            debugDirectionalFactor = max(debugDirectionalFactor, directionalShadowWrap * directionalLightStrength);
            debugDirectionalColor = max(debugDirectionalColor, visibleDirectionalLightColor);
        }
        if (g_DirectionalLightEnabled && directionalLightStrength > EPS_COL)
        {
            float sunDebugWrap = saturate(dot(sharedSunDirectionWs, shadowShadeNormalWs) * 0.5 + 0.5);
            debugDirectionalFactor = max(debugDirectionalFactor, sunDebugWrap * directionalLightStrength);
            debugDirectionalColor = max(debugDirectionalColor, visibleDirectionalLightColor);
        }

        #if S_SHADING_MODE != 4
        if (!IndirectLightingEnabled && !hasDirectionalLightInLoop && g_DirectionalLightEnabled && directionalLightStrength > EPS_COL)
        {
            float sunDotNL = dot(sharedSunDirectionWs, shadowNormalWs);
            float lightBrightness = RangeResponse(directionalLightStrength);
            float transitionSoftness = lerp(0.22, 0.06, lightBrightness);
            float currentLightIntensity = saturate(sunDotNL) * lerp(0.25, 1.0, RangeResponse(1.0));
            currentLightIntensity = ComputeToonBlend(currentLightIntensity, transitionSoftness);
            float surfaceBlend = max(currentLightIntensity, ambientToonBlend);
            float3 stylizedDirectLighting = max(visibleDirectionalLightColor, EPS_COL) * DirectLightIntensity;
            float3 sunResultColor = lerp(shade.rgb, lit.rgb, surfaceBlend) * stylizedDirectLighting;
            lighting += stylizedDirectLighting * surfaceBlend;
            directSurfaceLighting += sunResultColor;
            vLightResult += sunResultColor;
        }
        #endif

        #if S_SHADING_MODE == 4
        if (g_DirectionalLightEnabled && directionalLightStrength > EPS_COL)
        {
            realisticDirectionalShade = ComputeRealisticDirectionalShade(reflectionNormalWs, sharedSunDirectionWs);
        }
        #endif

        #if S_SHADING_MODE != 5
            bool allowSunSpecular = g_DirectionalLightEnabled && directionalLightStrength > EPS_COL;
            #if S_SHADING_MODE == 4
                allowSunSpecular = allowSunSpecular && hasDirectionalLightInLoop;
            #endif
            if (IsPbrLightingActive() && SpecularMode > 0 && SunSpecular && allowSunSpecular)
            {
                // Optional sun specular.
                float sunSpecularBaseVisibility = saturate(dot(sharedSunDirectionWs, reflectionNormalWs));
                float sunSpecularLighting = saturate(dot(sharedSunDirectionWs, shadowShadeNormalWs));
                float sunSpecularVisibility = lerp(sunSpecularBaseVisibility, min(sunSpecularBaseVisibility, sunSpecularLighting), saturate(SpecularLightingMix));
                if (sunSpecularVisibility > EPS_COL)
                {
                    float3 sunSpecularLightColor = visibleDirectionalLightColor * sunSpecularVisibility;
                    if (SpecularMode == 1)
                    {
                        AccumulateToonSpecular(sharedSunDirectionWs, sunSpecularLightColor);
                    }
                    else
                    {
                        reflectionAccumulated += ComputeReflectionSpecular(sharedSunDirectionWs, sunSpecularLightColor);
                    }
                }
            }
        #endif
        #if S_SHADING_MODE != 5
        if (!currentPixelIsFurShell && !hasDirectionalLightInLoop && g_DirectionalLightEnabled && directionalLightStrength > EPS_COL)
        {
            float SubsurfaceScatteringWeight = ComputeSubsurfaceScatteringWeight(sharedSunDirectionWs, 1.0);
            SubsurfaceScatteringAccumulated += directionalLightColor * SubsurfaceScatteringTint * SubsurfaceScatteringWeight;
            SubsurfaceScatteringEmissionAccumulated += SubsurfaceScatteringTint * SubsurfaceScatteringWeight;
        }
        #endif
        if (!currentPixelIsFurShell && BacklitEnabled && BacklitIntensity > EPS_COL && directionalLightStrength > EPS_COL)
        {
            float backlightWeight = ComputeBacklightWeight(sharedSunDirectionWs, 1.0);
            backlightAccumulated += visibleDirectionalLightColor * backlitColor * backlightWeight;
            backlightEmissionAccumulated += backlitColor * backlightWeight;
        }
        if (!currentPixelIsFurShell && GlitterEnabled && GlitterIntensity > EPS_COL && directionalLightStrength > EPS_COL)
        {
            glitterAccumulated += ComputeGlitterContribution(sharedSunDirectionWs, visibleDirectionalLightColor, 1.0);
        }
        vLightResult += indirectResult.rgb;

        //-------------------------------------------------------------------------------------------------
        // MainPs: Layered Post Process And Unlit Override
        //-------------------------------------------------------------------------------------------------
        float4 toonResult = PostProcess(i, float4(vLightResult, 1));

        // Unlit replaces the final lit result, but still lets Second Color sit on top when Extra Layers is compiled in.
        if ( Unlit > 0 )
        {
            #if S_ENABLED_EXTRA_LAYERS
            toonResult.rgb = BlendLayerColor(unlitBase, SecondColorUnlitColor, SecondColorUnlitWeight, SecondColorBlendMode);
            #else
            toonResult.rgb = unlitBase;
            #endif
        }

        if (!currentPixelIsFurShell && BackfaceColorIntensity > EPS_COL && isBackFace)
        {
            float3 backfaceColor = ApplyColorAdjustments(BackfaceColor.rgb, BackfaceHue, BackfaceHueShiftSpeed, BackfaceBrightness, BackfaceSaturation, BackfaceGamma, BackfaceHueColorSpace, BackfaceHueMode);
            float backfaceWeight = saturate(BackfaceColorIntensity);
            toonResult.rgb = BlendLayerColor(toonResult.rgb, backfaceColor, backfaceWeight, BackfaceColorBlendMode);
        }

        // Backface emission: additive glow on backface pixels.
        if (!currentPixelIsFurShell && isBackFace && BackfaceEmissionIntensity > EPS_COL)
        {
            toonResult.rgb += BackfaceEmissionColor.rgb * BackfaceEmissionIntensity;
        }

        //-------------------------------------------------------------------------------------------------
        // MainPs: Fur Shell Alpha
        //-------------------------------------------------------------------------------------------------
        #if S_SHADING_MODE == 5
        if (currentPixelIsFurShell)
        {
            // Fur shell alpha is separate from the main material alpha chain.
            // This is what lets base mesh alpha masks and fur alpha masks avoid fighting each other.
            float2 furNoiseUv = surfaceUv0 * FurNoiseTiling + FurNoiseOffset;
            float furNoise = FurNoiseTexture.Sample(g_sAniso, furNoiseUv).r;
            float furAlphaMask = 1.0;
            float furAlphaMaskWeight = 1.0;
            #if S_ALPHA_MODE != 0
            float2 furAlphaUv = surfaceUv0 * FurAlphaMaskTiling + FurAlphaMaskOffset;
            furAlphaMask = FurAlphaMaskTexture.Sample(g_sAniso, furAlphaUv).r;
            furAlphaMaskWeight = saturate(furAlphaMask) * saturate(FurAlphaIntensity);
            #endif
            float furLayer = saturate(i.furLayer);
            float furLayerShift = furLayer;
            float furLayerAbs = abs(furLayerShift);
            float furNoiseCoverage = saturate(furNoise - 0.225);
            float furAlpha = saturate(furNoiseCoverage - furLayerShift * furLayerAbs * furLayerAbs);
            furAlpha *= furAlphaMaskWeight;
            float furVisibilityScale = MapFurSoftnessToLegacyVisibility(FurSoftness) * 3.0;
            if (furVisibilityScale <= EPS_COL)
            {
                clip(-1.0);
            }
            float furCoverage = saturate(furAlpha * furVisibilityScale);
            furAlpha = saturate(furCoverage);

            // Keep fur AO broad and layer-based.
            float furAoStrength = clamp(FurAo, 0.0, 2.0);
            float furAoBaseFactor = lerp(0.72, 1.12, furLayer);
            float furAoFactor = 1.0 + (furAoBaseFactor - 1.0) * furAoStrength;
            toonResult.rgb *= furAoFactor;

            // Add a soft, lighting-aware highlight toward fur tips without adding more shell geometry.
            if (FurRimLightEnabled && FurRimIntensity > EPS_COL)
            {
                float furRimPower = max(FurRimFresnel, EPS_COL);
                float furRimFactor = pow(saturate(1.0 - abs(dot(normalWs, viewRayWs))), furRimPower);
                float3 furRimLighting = lerp(1.0.xxx, max(saturate(lighting + indirectLighting), EPS_COL), saturate(FurRimLightingMix));
                float3 furRimColor = FurRimColor.rgb * FurRimColor.a * furRimLighting;
                float furRimTipWidth = lerp(0.01, 1.0, saturate(FurRimTipArea));
                float furRimTipMask = smoothstep(1.0 - furRimTipWidth, 1.0, furLayer);
                float furRimWeight = saturate(furRimFactor * FurRimIntensity * furRimTipMask);
                toonResult.rgb = BlendLayerColor(toonResult.rgb, furRimColor, furRimWeight, 0);
            }

            // Fur shells own their opacity; the main alpha mask belongs to the base mesh only.
            alpha = saturate(furAlpha);
        }
        #endif

        //-------------------------------------------------------------------------------------------------
        // MainPs: Debug And Final Output
        //-------------------------------------------------------------------------------------------------
        #if !S_MODE_DEPTH
        if (IsAnyDebugModeActive() && debugResultValid)
        {
            toonResult.rgb = debugResultColor;
        }
        #endif

        // Keep material metadata useful for depth/tools, but send final color through BoBiCo's output model.
        m.Albedo = saturate(lit.rgb);
        m.Emission = 0.0.xxx;
        m.Roughness = saturate(reflectionRoughness);
        m.Metalness = saturate(reflectionMetallic);
        m.AmbientOcclusion = 1.0;
        #if S_MODE_DEPTH
        #if S_ALPHA_MODE == 2
            #if S_SHADING_MODE == 5
            if (currentPixelIsFurShell)
            {
                // Fur shells are visual only in Transparent mode; depth-writing them creates chunky holes.
                clip(-1.0);
            }
            clip(alpha - EPS_COL);
            return 1;
            #else
            clip(-1.0);
            return 1;
            #endif
        #endif
        #endif
#if S_ALPHA_MODE == 1
    #if !S_MODE_DEPTH
    if (A2CEnabled && A2CIntensity > 0.0)
    {
        m.Opacity = ApplyAlphaToCoverage(alpha);
        return ShadingModelBoBiCo::Shade(i, m, toonResult);
    }
    #endif
    clip(alpha - AlphaCutoff);
    m.Opacity = 1.0;
        #elif S_ALPHA_MODE == 2
            m.Opacity = alpha;
        #else
            m.Opacity = 1.0;
        #endif

        return ShadingModelBoBiCo::Shade(i, m, toonResult);
	}
