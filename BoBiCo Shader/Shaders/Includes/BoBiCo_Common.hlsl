//=========================================================================================================================
// BoBiCo shared runtime state and helper functions.
// Included inside the PS block before the lighting pipeline.
//=========================================================================================================================

    //-------------------------------------------------------------------------------------------------
    // Shared Runtime State
    //-------------------------------------------------------------------------------------------------
    // Small safety values and light-response caps used across the shader.
    // These keep toon bands stable when a map or light returns a near-zero value.
    static const float EPS_COL = 0.00001;
    // Half-Lambert remapping constant (shifts [-1,1] NdotL to [0,1])
    static const float HALF_LAMBERT = 0.5;
    // Hash multiplier used by glitter Voronoi for decorrelated angle randomization
    static const float GLITTER_ANGLE_HASH = 278.436;
    static const float INDIRECT_LIGHT_INTENSITY = 1.0;
    static const float DARK_AREA_LIFT = 0.35;

    // Surface UVs are cached globally because most features need the same displaced/selected UV state.
    static float2 baseUv;
    static float2 uv1Coords;
    static float2 rawUv0;
    static float2 rawUv1;
    static float2 surfaceUv0;
    static float2 surfaceUv1;
    static float2 mainUv;
    static float4 mainTex;
    static float alpha;
    static float3 viewRayWs;
    static float3 geometricNormalWs;
    static float3 normalWs;
    static float3 worldTangentUWs;
    static float3 worldTangentVWs;
    static float3 shadowNormalWs;
    static float3 shadowShadeNormalWs;

    // Core lit/shade colors used by stylized modes and later overlays.
    static float4 lit;
    static float4 shade;

    // Lighting state is accumulated by Direct()/Indirect(), then consumed by PostProcess().
    static float lightIntensity;
    static float shadowLightMap;
    static float shadowLightScore;
    static float3 shadowLightDirectionWs;
    static float selfShadowOverrideAmount;
    static float selfShadowLightScore;
    static bool hasDirectionalLightInLoop;
    static float3 lighting;
    static float3 indirectLighting;
    static float ambientToonBlend;
    static float3 ambientSurfaceColor;
    static bool isOutline;

    // PBR/reflection state is built once and reused by toon specular, env reflections, and Realistic shading mode.
    // Metallic and smoothness resolve into one shared reflection response.
    static float3 reflectionNormalWs;
    static float reflectionSmoothness;
    static float reflectionRoughness;
    static float reflectionMetallic;
    static float3 reflectionSpecularColor;
    static float4 reflectionLayerColor;
    static float reflectionPbrResponse;
    static float toonSpecularMapMask;
    static float3 toonSpecularSrcColor;
    static float toonSpecularBlendWeight;
    static float reflectionAoMask;
    static float reflectionShadowMask;
    static float3 reflectionAccumulated;
    static float3 reflectionEnvmapAccumulated;
    static float3 postProcessSsaoFactor;
    static float3 realisticAoFactor;
    static float3 realisticShadowFactor;
    static float realisticDirectionalShade;
    static float3 directSurfaceLighting;
    static float3 indirectSurfaceLighting;

    // Feature scratch state. These are intentionally shared so Direct() can add light-aware effects
    // without resampling the same masks for every light.
#if S_SHADING_MODE != 5
    static float3 SubsurfaceScatteringNormalWs;
    static float3 SubsurfaceScatteringTint;
    static float  SubsurfaceScatteringMaskWeight;
    static float3 SubsurfaceScatteringAccumulated;
    static float3 SubsurfaceScatteringEmissionAccumulated;
#endif
    static float3 backlitNormalWs;
    static float3 backlitColor;
    static float backlitMaskWeight;
    static float3 backlightAccumulated;
    static float3 backlightEmissionAccumulated;
    static float2 glitterUv;
    static float3 glitterBaseColor;
    static float3 glitterNormalWs;
    static float glitterMaskWeight;
    static float3 glitterAccumulated;

    // Glitter Voronoi cache: light-independent results computed once in Init() and
    // reused by every ComputeGlitterContribution() call in the per-light loop.
    static float3 glitterCachedCameraDir;  
    static float  glitterCachedSparkleBase; 
    static float  glitterCachedShapeMask;
    static float3 glitterCachedShapeColor;
    static float3 glitterCachedRandomColor;
    static bool   glitterCacheValid;       
    static float3 SecondColorUnlitColor;
    static float SecondColorUnlitWeight;
    static bool isBackFacePixel;

    // Cached ambient sample. MainPs computes it once, then Indirect() and the outline path reuse it.
    // Used to avoid multiple sampling.
    static float3 cachedAmbientSample;

    // Debug output is resolved at the end of PostProcess(), after the real shading has been built.
    static float debugAttenuation;
    static float debugDirectionalFactor;
    static float3 debugDirectionalColor;
    static float3 debugAmbientLighting;
    static float3 debugResultColor;
    static bool debugResultValid;

    //-------------------------------------------------------------------------------------------------
    // Color Adjustment Helpers
    //-------------------------------------------------------------------------------------------------
    // Shared hue/gamma path used by main color, Second color, emission, glitter, and similar layers.
    float LinearChannelToSrgb(float value)
    {
        value = max(value, 0.0);
        return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
    }

    float SrgbChannelToLinear(float value)
    {
        value = saturate(value);
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
    }

    float3 LinearToSrgb(float3 color)
    {
        return float3(
            LinearChannelToSrgb(color.r),
            LinearChannelToSrgb(color.g),
            LinearChannelToSrgb(color.b)
        );
    }

    float3 SrgbToLinear(float3 color)
    {
        return float3(
            SrgbChannelToLinear(color.r),
            SrgbChannelToLinear(color.g),
            SrgbChannelToLinear(color.b)
        );
    }

    float SignedCbrt(float value)
    {
        return sign(value) * pow(abs(value), 1.0 / 3.0);
    }

    float3 LinearSrgbToOklab(float3 color)
    {
        float l = 0.4122214708 * color.x + 0.5363325363 * color.y + 0.0514459929 * color.z;
        float m = 0.2119034982 * color.x + 0.6806995451 * color.y + 0.1073969566 * color.z;
        float s = 0.0883024619 * color.x + 0.2817188376 * color.y + 0.6299787005 * color.z;

        float l_ = SignedCbrt(l);
        float m_ = SignedCbrt(m);
        float s_ = SignedCbrt(s);

        return float3(
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        );
    }

    float3 OklabToLinearSrgb(float3 color)
    {
        float l_ = color.x + 0.3963377774 * color.y + 0.2158037573 * color.z;
        float m_ = color.x - 0.1055613458 * color.y - 0.0638541728 * color.z;
        float s_ = color.x - 0.0894841775 * color.y - 1.2914855480 * color.z;

        float l = l_ * l_ * l_;
        float m = m_ * m_ * m_;
        float s = s_ * s_ * s_;

        return float3(
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        );
    }

    // HSV hue rotation is fast and familiar. It is kept as "Normal Hue" for users who want direct hue-wheel behavior.
    float3 ApplyNormalHueShift(float3 color, float hue, float selectOrShift)
    {
        float3 hsv = RgbToHsv(saturate(color));
        hsv.x = frac(hsv.x * selectOrShift + hue);
        return HsvToRgb(hsv);
    }

    // OkLab hue rotation preserves perceived brightness better than HSV, especially on saturated anime/toon colors.
    // Near-gray colors have almost no chroma, so they early-out to avoid unstable hue angles.
    float3 ApplyOklabHueShift(float3 color, float hue, float selectOrShift)
    {
        float3 oklab = LinearSrgbToOklab(color);
        float chroma = length(oklab.yz);
        if (chroma <= 1e-5)
        {
            return color;
        }

        oklab.y = selectOrShift > 0.5 ? oklab.y : chroma;
        oklab.z = selectOrShift > 0.5 ? oklab.z : 0.0;
        float angle = atan2(oklab.z, oklab.y) + hue * 6.28318530718;
        oklab.y = cos(angle) * chroma;
        oklab.z = sin(angle) * chroma;
        return max(OklabToLinearSrgb(oklab), 0.0.xxx);
    }

    float GetAnimatedHue(float hue, float hueShiftSpeed)
    {
        // Hue is stored as a 0..1 full-circle value. Speed 1.0 completes one full loop in 20 seconds.
        return frac(hue + g_flTime * max(hueShiftSpeed, 0.0) * 0.05);
    }

    // Hue color-space mapping: 1 = OkLab, 2 = Normal HSV hue.
    // Each color-adjusting feature passes its own mode so artists can mix perceptual and traditional hue shifts.
    // Hue behavior mapping: 1 = Shift, 2 = Select. Select targets the chosen hue and lets the mask blend toward it.
    float3 ApplyHueShift(float3 color, float hue, float hueShiftSpeed, int hueColorSpace, int hueMode)
    {
        bool hueModeIsShift = hueMode <= 1;
        bool hueColorSpaceIsOklab = hueColorSpace <= 1;
        float animatedHue = GetAnimatedHue(hue, hueShiftSpeed);

        if (hueModeIsShift && abs(animatedHue) <= EPS_COL)
        {
            return color;
        }

        float selectOrShift = hueModeIsShift ? 1.0 : 0.0;
        return hueColorSpaceIsOklab ? ApplyOklabHueShift(color, animatedHue, selectOrShift) : ApplyNormalHueShift(color, animatedHue, selectOrShift);
    }

    // Color Adjust's Gradient Map uses its own 1D RGB remap texture, while Color Tint Mask stays free for spatial/multi-channel masks.
    // Source values are converted to sRGB for artist-authored ramps, then converted back to linear lighting space.
    float3 ApplyGradientMapColor(float3 color, float strength)
    {
        if (strength <= EPS_COL)
        {
            return color;
        }

        float3 srgbColor = LinearToSrgb(saturate(color));
        float3 gradMapped = float3(
            GradientMapTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.r, 0.5), 0).r,
            GradientMapTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.g, 0.5), 0).g,
            GradientMapTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.b, 0.5), 0).b
        );
        gradMapped = SrgbToLinear(saturate(gradMapped));
        return lerp(color, gradMapped, saturate(strength));
    }

    // Generic 1D gradient sampler used by emission gradient-map mode without allocating another texture slot.
    float3 SampleGradientMapTexture(Texture2D gradientTexture, float3 color)
    {
        float3 srgbColor = LinearToSrgb(saturate(color));
        float3 gradMapped = float3(
            gradientTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.r, 0.5), 0).r,
            gradientTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.g, 0.5), 0).g,
            gradientTexture.SampleLevel(g_sBilinearClamp, float2(srgbColor.b, 0.5), 0).b
        );
        return SrgbToLinear(saturate(gradMapped));
    }

    float2 BuildEmissionCenterOutUv(float2 tiling, float flowSpeed, float invertCenterOut)
    {
        float viewNormalDot = saturate(abs(dot(normalize(normalWs), normalize(viewRayWs))));
        float centerOutCoord = 0.5 + viewNormalDot * 0.5;
        centerOutCoord = lerp(centerOutCoord, 1.0 - centerOutCoord, saturate(invertCenterOut));
        float flow = g_flTime * flowSpeed;
        return centerOutCoord.xx * tiling + float2(flow, flow);
    }

    float3 ApplyTintBranch(float3 baseColor, float4 tintColor)
    {
        return lerp(baseColor, baseColor * tintColor.rgb, saturate(tintColor.a));
    }

    // Shared color adjustment order intentionally stays stable:
    // hue first, brightness scale, saturation around luminance, then gamma response.
    // Mask channel convention: R = Hue, G = Brightness, B = Saturation, A = Gamma.
    float3 ApplyColorAdjustmentsMasked(float3 color, float hue, float hueShiftSpeed, float brightness, float saturation, float gamma, int hueColorSpace, int hueMode, float4 adjustMask)
    {
        adjustMask = saturate(adjustMask);
        bool hueModeIsShift = hueMode <= 1;
        float hueAmount = hueModeIsShift ? hue * adjustMask.r : hue;
        float3 hueTarget = ApplyHueShift(color, hueAmount, hueShiftSpeed, hueColorSpace, hueMode);
        float3 hueShifted = hueModeIsShift ? hueTarget : lerp(color, hueTarget, adjustMask.r);

        float brightnessValue = lerp(1.0, brightness, adjustMask.g);
        float saturationValue = lerp(1.0, saturation, adjustMask.b);
        float gammaValue = lerp(1.0, gamma, adjustMask.a);

        float3 brightened = max(hueShifted * brightnessValue, 0.0.xxx);
        float luminance = dot(brightened, float3(0.299, 0.587, 0.114));
        float3 saturated = lerp(luminance.xxx, brightened, saturationValue);
        return pow(saturate(saturated), max(gammaValue, EPS_COL).xxx);
    }

    float3 ApplyColorAdjustments(float3 color, float hue, float hueShiftSpeed, float brightness, float saturation, float gamma, int hueColorSpace, int hueMode)
    {
        return ApplyColorAdjustmentsMasked(color, hue, hueShiftSpeed, brightness, saturation, gamma, hueColorSpace, hueMode, 1.0.xxxx);
    }

    //-------------------------------------------------------------------------------------------------
    // Alpha Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_ALPHA_MODE != 0
    // Optional external alpha mask for materials whose base texture does not carry useful alpha.
    // If the texture already has alpha, the shader can use that directly without the mask.
    float ApplyAlphaMask(float baseAlpha, float maskAlpha, float intensity)
    {
        maskAlpha = saturate(maskAlpha);
        float t = saturate(intensity);
        // AlphaMasking Mode mapping: 1 = Mask/Gate, 2 = Multiply, 3 = Add, 4 = Subtract.
        // The default gate mode never turns texture alpha opaque when the mask is white.
        if (AlphaMaskingMode == 1) return saturate(lerp(baseAlpha, min(baseAlpha, maskAlpha), t));
        if (AlphaMaskingMode == 2) return saturate(baseAlpha * lerp(1.0, maskAlpha, t));
        if (AlphaMaskingMode == 3) return saturate(baseAlpha + maskAlpha * t);
        return saturate(baseAlpha - maskAlpha * t);
    }

    float Dither8x8Bayer(float2 screenPosition)
    {
        // Cheap ordered dither. It is stable in screen space, which is what we want for alpha cut/fade.
        int2 p = int2(floor(screenPosition)) & int2(7, 7);
        int x = p.x;
        int y = p.y;
        int threshold =
            ((x & 1) << 5) | ((y & 1) << 4) |
            ((x & 2) << 2) | ((y & 2) << 1) |
            ((x & 4) >> 1) | ((y & 4) >> 2);
        return (float(threshold) + 0.5) / 64.0;
    }

    float ApplyFresnelAlpha(float baseAlpha)
    {
        // Fresnel alpha trims the silhouette first, then the normal alpha chain handles masks/dither.
        if (!FresnelAlpha)
        {
            return baseAlpha;
        }

        float viewNormalDot = saturate(abs(dot(normalize(viewRayWs), normalize(normalWs))));
        float edge0 = min(FresnelAlphaSharpness, FresnelAlphaWidth);
        float edge1 = max(FresnelAlphaWidth, edge0 + EPS_COL);
        float fresnelAlpha = saturate(1.0 - smoothstep(edge0, edge1, viewNormalDot));
        fresnelAlpha = abs(lerp(1.0, fresnelAlpha, saturate(FresnelAlphaIntensity)));
        fresnelAlpha = FresnelAlphaInvert ? 1.0 - fresnelAlpha : fresnelAlpha;
        return saturate(baseAlpha * fresnelAlpha);
    }

    float ApplyDitherAlpha(float baseAlpha, float2 screenPosition)
    {
        // Dither alpha keeps Cutoff/Transparent edges from turning into one hard threshold.
        if (!DitherAlpha)
        {
            return baseAlpha;
        }

        float dither = Dither8x8Bayer(screenPosition) - saturate(DitherAlphaBias);
        return saturate(baseAlpha - (dither * (1.0 - baseAlpha) * saturate(DitherAlphaGradient)));
    }

    float ResolveFinalAlpha(float baseAlpha, float2 screenPosition)
    {
        // Final alpha order is deliberate: shape the alpha first, then dither the result.
        baseAlpha = ApplyFresnelAlpha(baseAlpha);
        return ApplyDitherAlpha(baseAlpha, screenPosition);
    }

    #if S_ALPHA_MODE == 1
    float ApplyAlphaToCoverage(float baseAlpha)
    {
        float hardCutoffAlpha = baseAlpha >= AlphaCutoff ? 1.0 : 0.0;
        float coverageAlpha = saturate(baseAlpha);

        return saturate(lerp(hardCutoffAlpha, coverageAlpha, saturate(A2CIntensity)));
    }
    #endif
    #endif

    //-------------------------------------------------------------------------------------------------
    // Debug Helpers
    //-------------------------------------------------------------------------------------------------
    // Debug views : lighting and shading only.
    bool IsAnyDebugModeActive()
    {
        return LightingDebugging > 0 || ShadingDebugging;
    }

    float GetDebugMaskValue(float3 color)
    {
        // Use the brightest channel as the "where is this active?" mask for colored debug output.
        return saturate(max(color.r, max(color.g, color.b)));
    }

    float3 BuildDebugColor(float3 color, float maskValue)
    {
        // Black means no contribution. Colored output keeps light/source hue intact for easier diagnosis.
        float mask = saturate(maskValue);
        return max(color, 0.0.xxx) * mask;
    }

    //-------------------------------------------------------------------------------------------------
    // UV And Mask Helpers
    //-------------------------------------------------------------------------------------------------
    // Rotate UVs around their center point. Most texture controls use this same convention.
    float2 RotateUv(float2 uv, float angleDegrees)
    {
        float angle = radians(angleDegrees);
        float s = sin(angle);
        float c = cos(angle);
        float2 centered = uv - 0.5.xx;
        float2 rotated = float2(centered.x * c - centered.y * s, centered.x * s + centered.y * c);
        return rotated + 0.5.xx;
    }

    // Animated UV path used by textures with tiling/offset/scroll/rotate controls.
    float2 BuildLayerUv(float2 baseLayerUv, float2 tiling, float2 offset, float2 scroll, float rotateSpeed, float rotationDegrees)
    {
        float2 uv = baseLayerUv;
        uv = uv * tiling + offset;
        uv += g_flTime * scroll;
        return RotateUv(uv, rotationDegrees + g_flTime * rotateSpeed * 180.0);
    }

    // Static UV path for masks and maps that should not animate over time.
    float2 BuildStaticLayerUv(float2 baseLayerUv, float2 tiling, float2 offset, float rotationDegrees)
    {
        float2 uv = baseLayerUv * tiling + offset;
        return RotateUv(uv, rotationDegrees);
    }

    float ApplyInvertMask(float maskValue, float invertMask)
    {
        // Shared invert rule for scalar masks. Keeps all "Invert Mask" toggles behaving the same.
        return lerp(maskValue, 1.0 - maskValue, saturate(invertMask));
    }

    float4 ApplyInvertMask4(float4 maskValue, float invertMask)
    {
        // Multi-channel masks use the same invert rule per channel.
        return lerp(maskValue, 1.0.xxxx - maskValue, saturate(invertMask));
    }

    float ApplyMaskIntensity(float maskValue, float intensity)
    {
        // Intensity 0 means neutral white mask; intensity 1 means full texture mask.
        return lerp(1.0, maskValue, saturate(intensity));
    }

    float4 ApplyMaskIntensity4(float4 maskValue, float intensity)
    {
        // Multi-channel adjustment masks follow the same neutral-white rule per channel.
        return lerp(1.0.xxxx, maskValue, saturate(intensity));
    }

    //-------------------------------------------------------------------------------------------------
    // Second Color Decal Helpers
    //-------------------------------------------------------------------------------------------------
    // These helpers let Second Color act like a decal without needing a separate decal pass.
    // The visibility mask trims copied/mirrored UV regions before blending.
    float2 ApplyDecalCopyMode(float2 uv, float2 sourceUv, int copyMode)
    {
        if (copyMode == 1)
        {
            uv.x = abs(uv.x - 0.5) + 0.5;
        }
        else if (copyMode == 2 && sourceUv.x < 0.5)
        {
            uv.x = 1.0 - uv.x;
        }

        return uv;
    }

    // Mirror modes.
    float2 ApplyDecalMirrorMode(float2 uv, float2 sourceUv, int mirrorMode, out float visibilityMask)
    {
        visibilityMask = 1.0;
        if (mirrorMode == 1)
        {
            uv.x = 1.0 - uv.x;
        }
        else if (mirrorMode == 2)
        {
            visibilityMask = step(0.5, sourceUv.x);
        }
        else if (mirrorMode == 3)
        {
            visibilityMask = step(sourceUv.x, 0.5);
        }
        else if (mirrorMode == 4)
        {
            visibilityMask = step(sourceUv.x, 0.5);
            uv.x = 1.0 - uv.x;
        }

        return uv;
    }

#if S_ENABLED_EXTRA_LAYERS
    float2 BuildSecondColorDecalUv(float2 baseLayerUv, out float visibilityMask)
    {
        visibilityMask = 1.0;

        float2 uv = baseLayerUv;

        if (SecondColorUseAsDecal)
        {
            uv = ApplyDecalCopyMode(uv, baseLayerUv, SecondColorCopyMode);
            float2 decalScale = max(SecondColorScale, 0.0001.xx);
            uv = (uv - 0.5.xx) * decalScale + 0.5.xx + SecondColorPosition;
            uv += g_flTime * SecondColorScroll;
            uv = ApplyDecalMirrorMode(uv, baseLayerUv, SecondColorMirrorMode, visibilityMask);
            uv = RotateUv(uv, SecondColorRotation + g_flTime * SecondColorRotate * 180.0);

            // Decal mode is intentionally clipped to 0..1 so mirrored/copy modes do not wrap around the mesh.
            visibilityMask *= step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
        }
        else
        {
            uv = uv * SecondColorTiling + SecondColorOffset;
            uv += g_flTime * SecondColorUvScroll;
            uv = RotateUv(uv, SecondColorUvRotation + g_flTime * SecondColorUvRotate * 180.0);
        }

        return uv;
    }
#endif

    //-------------------------------------------------------------------------------------------------
    // Parallax Occlusion Mapping Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_ENABLE_EXPENSIVE_FEATURES && S_SHADING_MODE == 4
    // POM works in tangent space, so view direction is projected onto the surface TBN once here.
    float3 ComputeTangentViewDirection(float3 viewDirectionWs, float3 tangentUWs, float3 tangentVWs, float3 shadingNormalWs)
    {
        float3 tangentViewDirection;
        tangentViewDirection.x = dot(viewDirectionWs, normalize(tangentUWs));
        tangentViewDirection.y = dot(viewDirectionWs, normalize(tangentVWs));
        tangentViewDirection.z = dot(viewDirectionWs, normalize(shadingNormalWs));
        return tangentViewDirection;
    }

    float SamplePomHeightValue(float2 surfaceLayerUv, float2 heightDx, float2 heightDy)
    {
        // Height Bias shifts the sampled height response. Offset is handled later as the reference plane.
        float2 heightUv = BuildStaticLayerUv(surfaceLayerUv, HeightmapTiling, HeightmapOffset, HeightmapRotation);
        float heightSample = HeightmapTexture.SampleGrad(g_sAniso, heightUv, heightDx, heightDy).r;
        return saturate(heightSample + PomHeightBias);
    }

    bool UsePomUv1(float2 rawUv1)
    {
        // Some imported meshes leave UV1 at zero. In that case, fall back to UV0 instead of breaking the material.
        if (!PomEnabled || PomUvMode != 1)
        {
            return false;
        }

        float uv1Extent = max(abs(rawUv1.x), abs(rawUv1.y));
        return uv1Extent > EPS_COL;
    }

    int ResolvePomMinSteps(int maxSteps)
    {
        // Just like how Poiyomi did: full steps at grazing angles, quarter steps when facing the camera.
        // Free performance.
        return max((int)(maxSteps * 0.25 + 0.5), 1);
    }

    float2 ApplyPomSurfaceUv(float2 rawSurfaceUv, float3 tangentViewDirection)
    {
        // Real POM raymarch. Walk forward through the height field, then binary-refine the hit.
        if (!PomEnabled)
        {
            return rawSurfaceUv;
        }

        int maxSteps = clamp(PomSteps, 0, 128);
        if (maxSteps <= 0)
        {
            return rawSurfaceUv;
        }

        float pomMaskWeight = saturate(PomHeightStrength);
        if (pomMaskWeight <= EPS_COL)
        {
            return rawSurfaceUv;
        }

        float tangentViewZ = max(abs(tangentViewDirection.z), 0.0001);
        float viewAlignment = saturate(abs(tangentViewDirection.z));
        int minSteps = ResolvePomMinSteps(maxSteps);
        int numSteps = max((int)(lerp((float)maxSteps, (float)minSteps, viewAlignment) + 0.5), 1);
        if (numSteps <= 0)
        {
            return rawSurfaceUv;
        }
        float2 heightUv = BuildStaticLayerUv(rawSurfaceUv, HeightmapTiling, HeightmapOffset, HeightmapRotation);
        float2 heightDx = ddx(heightUv);
        float2 heightDy = ddy(heightUv);
        float heightStrength = saturate(PomHeightStrength * 0.5);
        if (heightStrength <= EPS_COL)
        {
            return rawSurfaceUv;
        }

        // Keep 1.0 at the practical full mask response and reserve 2.0 as the overdrive range.
        // So, no more overblown results than what a pure white mask would give, but artists can still push beyond that if they want.
        float poiHeightStrength = heightStrength * 0.4247461;
        float2 plane = poiHeightStrength * (tangentViewDirection.xy / tangentViewZ);
        float2 baseSurfaceUv = rawSurfaceUv + PomOffset * plane;
        float layerHeight = 1.0 / max((float)numSteps, 1.0);
        float2 deltaUv = -plane * layerHeight;
        float2 currentUvOffset = deltaUv;
        float currentRayHeight = 1.0 - layerHeight;
        float currentHeight = 0.0;
        float previousHeight = 0.0;
        float2 previousUv = 0.0.xx;
        float previousRayHeight = 1.0;

        [loop]
        for (int stepIndex = 0; stepIndex < 128; ++stepIndex)
        {
            if (stepIndex >= numSteps)
            {
                break;
            }

            currentHeight = SamplePomHeightValue(baseSurfaceUv + currentUvOffset, heightDx, heightDy);
            if (currentHeight > currentRayHeight)
            {
                break;
            }

            previousUv = currentUvOffset;
            previousHeight = currentHeight;
            previousRayHeight = currentRayHeight;
            currentUvOffset += deltaUv;
            currentRayHeight -= layerHeight;
        }

        float2 lowerUv = currentUvOffset;
        float2 upperUv = previousUv;
        float lowerHeight = currentHeight;
        float upperHeight = previousHeight;
        float lowerRayHeight = currentRayHeight;
        float upperRayHeight = previousRayHeight;
        int refineSteps = clamp(PomSearchSteps, 1, 16);

        [loop]
        for (int refineIndex = 0; refineIndex < 16; ++refineIndex)
        {
            if (refineIndex >= refineSteps)
            {
                break;
            }

            float2 midUv = (lowerUv + upperUv) * 0.5;
            float midRayHeight = (lowerRayHeight + upperRayHeight) * 0.5;
            float midHeight = SamplePomHeightValue(baseSurfaceUv + midUv, heightDx, heightDy);

            if (midHeight > midRayHeight)
            {
                lowerUv = midUv;
                lowerHeight = midHeight;
                lowerRayHeight = midRayHeight;
            }
            else
            {
                upperUv = midUv;
                upperHeight = midHeight;
                upperRayHeight = midRayHeight;
            }
        }

        float denominator = (upperHeight - upperRayHeight) - (lowerHeight - lowerRayHeight);
        float intersectionWeight = abs(denominator) <= EPS_COL ? 0.5 : saturate((upperHeight - upperRayHeight) / denominator);
        float2 finalOffset = lerp(upperUv, lowerUv, intersectionWeight);
        return baseSurfaceUv + finalOffset;
    }

    #endif

    //-------------------------------------------------------------------------------------------------
    // Shared Lighting And Shading Helpers
    //-------------------------------------------------------------------------------------------------
    float RangeResponse(float value)
    {
        // Soft compression for light magnitudes. It keeps very bright maps/lights from blowing out toon logic.
        value = max(value, 0.0);
        return value / (1.0 + value);
    }

    float3 ApplyShaderLightControls(float3 lightColor)
    {
        lightColor = max(lightColor, 0.0.xxx);
        float grayscaleLight = dot(lightColor, float3(0.299, 0.587, 0.114));
        lightColor = lerp(lightColor, grayscaleLight.xxx, saturate(GrayscaleLighting));

        if (LimitLightBrightness)
        {
            float lightPeak = max(lightColor.x, max(lightColor.y, lightColor.z));
            if (lightPeak > EPS_COL)
            {
                float maxLimit = max(LightMaxLimit, 0.0);
                float minLimit = min(saturate(LightMinLimit), maxLimit);
                float limitedPeak = clamp(lightPeak, minLimit, maxLimit);
                lightColor *= limitedPeak / lightPeak;
            }
        }

        return lightColor;
    }

    float3 ResolveOverwriteLightDirection(float3 defaultDirectionWs)
    {
        float overrideLengthSq = dot(OverwriteLightDirection, OverwriteLightDirection);
        if (overrideLengthSq <= EPS_COL)
        {
            return defaultDirectionWs;
        }

        float3 overrideDirectionWs = normalize(OverwriteLightDirection);
        float overrideAmount = saturate(sqrt(overrideLengthSq) / 180.0);
        return normalize(lerp(defaultDirectionWs, overrideDirectionWs, overrideAmount));
    }

    float ApplyShadowShadingMask(float shadowPresence, float blendAmount)
    {
        // Converts existing shadow presence into a feature visibility mask.
        // Used by matcap/rim/etc. when artists want effects hidden in shadowed areas.
        return lerp(1.0, 1.0 - saturate(shadowPresence), saturate(blendAmount));
    }

    float Remap01Range(float value, float minimum, float maximum)
    {
        // Small remap helper for packed AO/shadow channels with artist-controlled min/max.
        return saturate((value - minimum) / max(maximum - minimum, EPS_COL));
    }

    // Sample ambient lighting the same as engine. This can be used for a stable ambient term that matches the engine's GI sampling. 
    // But, don't look good with toon shading and only used for "Realistic" shading mode.
    float3 SampleStableAmbient(float3 worldPosition, float4 screenPosition, float3 shadingNormalWs)
    {
        return max(AmbientLight::From(worldPosition, screenPosition, shadingNormalWs), 0.0.xxx);
    }

    // Fast: two antipodal Z samples. Z+ is up in S&Box world space.
    // Cancels L1 on the Z axis — cheapest stable toon ambient.
    float3 SampleFastToonAmbient(float3 worldPosition, float4 screenPosition)
    {
        float3 axisZ  = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, 0.0,  1.0)), 0.0.xxx);
        float3 axisNZ = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, 0.0, -1.0)), 0.0.xxx);
        return (axisZ + axisNZ) * 0.5;
    }

    // Sample six directions of ambient lighting and average them together. This is a approximation of the GI sampling for toon shading.
    float3 SampleToonAmbient(float3 worldPosition, float4 screenPosition, float3 shadingNormalWs)
    {
        float3 axisX = max(AmbientLight::From(worldPosition, screenPosition, float3(1.0, 0.0, 0.0)), 0.0.xxx);
        float3 axisNX = max(AmbientLight::From(worldPosition, screenPosition, float3(-1.0, 0.0, 0.0)), 0.0.xxx);
        float3 axisY = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, 1.0, 0.0)), 0.0.xxx);
        float3 axisNY = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, -1.0, 0.0)), 0.0.xxx);
        float3 axisZ = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, 0.0, 1.0)), 0.0.xxx);
        float3 axisNZ = max(AmbientLight::From(worldPosition, screenPosition, float3(0.0, 0.0, -1.0)), 0.0.xxx);
        return (axisX + axisNX + axisY + axisNY + axisZ + axisNZ) / 6.0;
    }


    // Smooth the transition around the middle so toon bands do not look harsh.
    float ComputeToonBlend(float lightMetric, float transitionSoftness)
    {
        float shapedMetric = saturate(lightMetric);
        float center = 0.5;
        return smoothstep(center - transitionSoftness, center + transitionSoftness, shapedMetric);
    }

    // Boost low-light ambient values so dark areas still blend cleanly instead of dropping to mud.
    float ComputeAmbientLift(float ambientMetric)
    {
        float boostedAmbient = saturate(ambientMetric * lerp(1.45, 2.35, DARK_AREA_LIFT));
        return 1.0 - pow(1.0 - boostedAmbient, 1.6);
    }

    // Centered contrast curve used by shadow layers.
    float3 ApplyShadowContrast(float3 color, float contrast)
    {
        return saturate((color - 0.5.xxx) * contrast + 0.5.xxx);
    }

    // Kept as a tiny hook for future shade shaping. Returning unchanged is intentional for now.
    float4 BuildInternalShade(float4 baseColor)
    {
        return baseColor;
    }

    //-------------------------------------------------------------------------------------------------
    // UV Selection Helpers
    //-------------------------------------------------------------------------------------------------
    // Use UV1 only when the mesh actually has a valid second UV set.
    // Fall back to UV0 so meshes without UV1 still render correctly.
    float2 SelectUvSet(float2 uv0, float2 uv1, int uvMode)
    {
        if (uvMode == 1)
        {
            float uv1Extent = max(abs(uv1.x), abs(uv1.y));
            if (uv1Extent > EPS_COL)
            {
                return uv1;
            }
        }

        return uv0;
    }

    // Runtime UV selector. Current UI exposes UV0/UV1 only.
    float2 GetLayerBaseUv(int uvMode)
    {
        return SelectUvSet(baseUv, uv1Coords, uvMode);
    }

    float2 GetLayerRawUv(int uvMode)
    {
        return SelectUvSet(rawUv0, rawUv1, uvMode);
    }

    float2 GetLayerParallaxOffset(int uvMode)
    {
        return GetLayerBaseUv(uvMode) - GetLayerRawUv(uvMode);
    }

    //-------------------------------------------------------------------------------------------------
    // Normal Map Helpers
    //-------------------------------------------------------------------------------------------------
    // Scale a tangent-space normal without changing its direction.
    float3 ApplyNormalStrength(float3 tangentNormal, float strength)
    {
        // Rebuild Z after scaling XY. This gives >1 intensity a real stronger normal response.
        strength = max(strength, 0.0);
        float3 strengthened = tangentNormal;
        strengthened.xy *= strength;
        float xyLenSq = dot(strengthened.xy, strengthened.xy);
        strengthened.z = sqrt(saturate(1.0 - min(xyLenSq, 1.0)));
        return normalize(float3(strengthened.xy, max(strengthened.z, EPS_COL)));
    }

    float MapFurNormalIntensityToStrength(float intensity)
    {
        // Match the GS steering scale so fur strand normals and shell direction stay in sync.
        return intensity * 0.8;
    }

    float MapFurSoftnessToLegacyVisibility(float softness)
    {
        // New 0..1 UI range covers the same old 0..2 softness range. 0.25 still matches the old default look.
        float softnessClamped = clamp(softness * 2.0, 0.0, 2.0);
        if (softnessClamped <= 0.5)
        {
            return lerp(0.5, 1.0, softnessClamped / 0.5);
        }

        return lerp(1.0, 2.0, (softnessClamped - 0.5) / 1.5);
    }

    float3 DecodeFurShadingNormalSample(float3 packedNormal, float strength)
    {
        float3 tangentNormal = packedNormal * 2.0 - 1.0.xxx;
        strength = MapFurNormalIntensityToStrength(strength);
        tangentNormal.xy *= strength;
        float xyLenSq = dot(tangentNormal.xy, tangentNormal.xy);
        tangentNormal.z = sqrt(saturate(1.0 - min(xyLenSq, 1.0)));
        return normalize(float3(tangentNormal.xy, max(tangentNormal.z, EPS_COL)));
    }

    // Combine the base and Second normal map in tangent space without bouncing through world space.
    float3 BlendTangentNormals(float3 baseNormalTs, float3 detailNormalTs)
    {
        return normalize(float3(baseNormalTs.xy + detailNormalTs.xy, max(baseNormalTs.z * detailNormalTs.z, EPS_COL)));
    }

    //-------------------------------------------------------------------------------------------------
    // Emission Helpers
    //-------------------------------------------------------------------------------------------------
    // Blink helper for emission layers.
    // Supports sine wave blinking and on/off blinking, both with adjustable speed and strength. 
    float ComputeBlinkFactor(int blinkMode, float blinkStrength, float blinkSpeed)
    {
        // blinkMode 0 is smooth pulse, 1 is hard on/off. Strength blends back to constant emission.
        float speed = max(blinkSpeed, EPS_COL);
        float sinValue = sin(g_flTime * speed * 6.2831853);
        float normalBlink = 0.5 + 0.5 * sinValue;
        float constantBlink = step(0.0, sinValue);
        float blinkValue = blinkMode == 1 ? constantBlink : normalBlink;
        return lerp(1.0, blinkValue, saturate(blinkStrength));
    }

    //-------------------------------------------------------------------------------------------------
    // Light Response Helpers
    //-------------------------------------------------------------------------------------------------
    // Compress bright peaks without flattening the whole response.
    float ComputeRealisticDirectionalShade(float3 normalWs, float3 lightDirectionWs)
    {
        // Realistic still gets a tiny half-lambert shape so white sun light does not erase form.
        float ndl = dot(normalize(normalWs), normalize(lightDirectionWs));
        float halfLambert = saturate(ndl * 0.5 + 0.5);
        return lerp(0.35, 1.0, halfLambert);
    }

    #if S_SHADING_MODE == 4
        float ComputeRealisticDirectResponse(float rawLambert)
        {
            float areaOffset = 0.5 - ShadingArea;
            return saturate(rawLambert + areaOffset);
        }

        float3 ApplyRealisticDirectControls(float3 directLight, float directResponse)
        {
            float3 shadeSideTint = lerp(1.0.xxx, max(ShadingTint.rgb, 0.0.xxx), saturate(ShadingTint.a));
            float3 lightSideTint = lerp(1.0.xxx, max(ShadingLightSideTint.rgb, 0.0.xxx), saturate(ShadingLightSideTint.a));
            float3 realisticTint = lerp(shadeSideTint, lightSideTint, saturate(directResponse));
            return directLight * realisticTint;
        }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Glitter Helpers
    //-------------------------------------------------------------------------------------------------
    float GlitterHueToShift(float value)
    {
        // GlitterHue is now 0..1 (full circle), same as all other hue sliders. No conversion needed.
        return value;
    }

    float3 ApplyContrast(float3 color, float contrast)
    {
        return saturate((color - 0.5.xxx) * contrast + 0.5.xxx);
    }

    float3 ApplyGlitterColorAdjustments(float3 color)
    {
        // Glitter has its own color controls so it can stay independent from the base material.
        float3 adjusted = ApplyColorAdjustments(color, GlitterHueToShift(GlitterHue), GlitterHueShiftSpeed, GlitterBrightness, GlitterSaturation, GlitterGamma, GlitterHueColorSpace, GlitterHueMode);
        return ApplyContrast(adjusted, GlitterContrast);
    }

    float GlitterDensityToScale()
    {
        // Density maps to a grid scale. Clamp to 1 so a zero-ish density does not break the Voronoi cell math.
        return max(GlitterDensity * 256.0, 1.0);
    }

    float GlitterSensitivityToValue()
    {
        // Keep sensitivity above zero so highlight threshold math stays well-defined.
        return max(GlitterSensitivity * 0.25, EPS_COL);
    }

    float GlitterBlinkSpeedToValue()
    {
        return GlitterBlinkSpeed * 0.25;
    }

    float3 GlitterHash23(float2 p)
    {
        // Tiny deterministic hash used for per-cell glitter shape/rotation/randomness.
        float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
        p3 += dot(p3, p3.yzx + 33.33);
        return frac((p3.xxy + p3.yzz) * p3.zyx);
    }

    void GlitterVoronoi(float2 pos, out float2 nearestPoint, out float3 nearestRandom, out float nearestDistance)
    {
        // Search the current cell and neighbors, then use the nearest random point as the glitter flake.
        float2 cell = floor(pos);
        float2 cellUv = frac(pos);
        nearestDistance = 99999.0;
        nearestPoint = 0.0.xx;
        nearestRandom = 0.0.xxx;

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                float2 offset = float2(x, y);
                float3 randomValue = GlitterHash23(cell + offset);
                float2 pointOffset = offset + randomValue.xy - cellUv;
                float distanceToPoint = length(pointOffset);
                if (distanceToPoint < nearestDistance)
                {
                    nearestDistance = distanceToPoint;
                    nearestPoint = pointOffset;
                    nearestRandom = randomValue;
                }
            }
        }
    }

    float GlitterPolygonMask(float2 p, float sides)
    {
        // Built-in polygon flakes. 
        float angle = atan2(p.y, p.x) + 3.14159265;
        float sector = 6.2831853 / sides;
        float radial = cos(floor(0.5 + angle / sector) * sector - angle) * length(p);
        float aa = max(fwidth(radial), EPS_COL);
        return saturate((1.0 - radial) / aa);
    }

    float GlitterStarMask(float2 p)
    {
        // Star shape is a simple radial pulse over the polygon mask.
        float angle = atan2(p.y, p.x);
        float radius = length(p);
        float spike = pow(abs(cos(angle * 5.0)), 1.6);
        float targetRadius = lerp(0.38, 1.0, spike);
        float aa = max(fwidth(radius), EPS_COL);
        return saturate((targetRadius - radius) / aa);
    }

    float ComputeBuiltInGlitterShape(float2 localUv, int shape)
    {
        // Shape IDs match the material UI. The custom texture path is blended in later.
        float2 p = localUv * 2.0 - 1.0;

        if (shape == 1)
        {
            float squareDistance = max(abs(p.x), abs(p.y));
            float aa = max(fwidth(squareDistance), EPS_COL);
            return saturate((1.0 - squareDistance) / aa);
        }

        if (shape == 2)
        {
            return GlitterStarMask(p);
        }

        if (shape == 3)
        {
            return GlitterPolygonMask(p, 3.0);
        }

        float circleDistance = length(p);
        float aa = max(fwidth(circleDistance), EPS_COL);
        return saturate((1.0 - circleDistance) / aa);
    }

    // Returns RGB color + A mask. Custom shape RGB is preserved so texture flakes can carry color.
    float4 ComputeGlitterShapeMask(float2 localUv, float randomAngleDegrees)
    {
        float2 builtInUv = RotateUv(localUv, randomAngleDegrees);
        float builtInShape = ComputeBuiltInGlitterShape(builtInUv, GlitterShape);

        float2 customUv = localUv;
        customUv = customUv * GlitterCustomShapeTiling + GlitterCustomShapeOffset;
        customUv = RotateUv(customUv, GlitterCustomShapeRotation + randomAngleDegrees);
        float customInside = step(0.0, customUv.x) * step(customUv.x, 1.0) * step(0.0, customUv.y) * step(customUv.y, 1.0);
        // Sample full RGBA. RGB carries custom flake color; luminance is used as coverage.
        float4 customSample = GlitterCustomShapeTexture.Sample(g_sAniso, customUv);
        // Use luminance of RGB as the mask weight so the shape still clips correctly.
        float customAlpha = Luminance(customSample.rgb) * customInside;
        float3 customColor = customSample.rgb * customInside;

        float blendFactor = float(GlitterCustomShape);
        float shapeMask = saturate(lerp(builtInShape, customAlpha, blendFactor));
        // Built-in shapes are white; custom shapes carry their texture color.
        float3 shapeColor = lerp(1.0.xxx, customColor, blendFactor);

        return float4(shapeColor, shapeMask);
    }

    float3 ComputeGlitterContribution(float3 lightDirectionWs, float3 lightColor, float lightVisibility)
    {
        // All light-independent work (Voronoi, sparkle, shape) was pre-computed in Init().
        // This function only does the per-light half-vector and nh calculation.
        if (!GlitterEnabled || GlitterIntensity <= EPS_COL || !glitterCacheValid)
        {
            return 0.0.xxx;
        }

        // lightDirectionWs is already normalized from Light::From(); no inner normalize needed.
        float3 halfDirection = normalize(glitterCachedCameraDir + lightDirectionWs);
        float nh = saturate(dot(glitterNormalWs, halfDirection));
        float sparkle = saturate(glitterCachedSparkleBase * nh) * saturate(lightVisibility);

        return lightColor * glitterCachedRandomColor * glitterCachedShapeColor
               * glitterCachedShapeMask * sparkle * glitterMaskWeight;
    }

    //-------------------------------------------------------------------------------------------------
    // PBR, Realistic, And Reflection Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_SHADING_MODE != 5
    float3 ComputeReflectionFresnel(float3 specularColor, float lightHalfDot)
    {
        // Fresnel boost shared by toon specular and realistic reflections.
        float fresnelTerm = pow(1.0 - saturate(lightHalfDot), 5.0);
        float fresnelWeight = saturate(FresnelStrength);
        float3 fresnelTarget = specularColor + lerp(specularColor, 1.0.xxx, fresnelWeight) * fresnelWeight;
        return lerp(specularColor, fresnelTarget, fresnelTerm);
    }

    float3 SampleReflectionEnvMap(float3 worldPosition, float4 screenPosition, float3 worldNormal, float roughness)
    {
        // Thin wrapper so envmap sampling stays in one place.
        return EnvMap::From(worldPosition, screenPosition, worldNormal, roughness.xx);
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Self Shadow Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_SHADING_MODE != 4 && S_ALPHA_MODE != 2
    bool IsSelfShadowRuntimeActive()
    {
        return SelfShadowEnabled && SelfShadowIntensity > EPS_COL;
    }
    #else
    bool IsSelfShadowRuntimeActive() { return false; }
    #endif

    //-------------------------------------------------------------------------------------------------
    // SSAO Helpers
    //-------------------------------------------------------------------------------------------------
    // Only when S_ENABLE_EXPENSIVE_FEATURES is enabled, since SSAO sampling can be costly and is not needed by most materials.
    // S&box provides this as GTAO through the scene post-process path. If no scene SSAO exists, this returns neutral.
    #if S_ENABLE_EXPENSIVE_FEATURES
    float3 BlendSsaoLayerColor(float3 baseColor, float3 layerColor, float layerWeight, int blendMode)
    {
        float w = saturate(layerWeight);
        float3 target = lerp(baseColor, layerColor, w);
        // 0 = Add/subtractive AO, 1 = Screen/soft AO, 2 = Replace.
        if (blendMode == 0)
        {
            return saturate(baseColor - (1.0.xxx - layerColor) * saturate(w * 1.5));
        }

        if (blendMode == 1)
        {
            return saturate(baseColor - (1.0.xxx - target) * 0.65);
        }

        return saturate(target);
    }

    float3 ComputePostProcessSsao(float4 screenPosition)
    {
        // Material-side support for the scene SSAO pass. If the scene has no SSAO, this returns neutral.
        if (!SSAOEnabled || SSAOIntensity <= EPS_COL)
        {
            return 1.0.xxx;
        }

        float3 ssaoLayerColor = saturate(SSAOColor.rgb);

        float3 ssaoNormalWs = normalize(lerp(geometricNormalWs, normalWs, saturate(SSAONormalMapEnabled)));
        float ssaoSample = saturate(ScreenSpaceAmbientOcclusion::Sample(screenPosition));
        float ssaoBaseIntensity = saturate(SSAOIntensity);
        float ssaoBoost = saturate((SSAOIntensity - 1.0) * 0.25);
        float ssaoVisibility = lerp(1.0, ssaoSample, ssaoBaseIntensity);
        float ssaoOcclusion = saturate(1.0 - ssaoVisibility);
        ssaoOcclusion *= lerp(1.0, 1.75, ssaoBoost);
        float contrastExponent = exp2(1.0 - saturate(SSAOContrast * 0.5) * 2.0);
        ssaoOcclusion = ssaoOcclusion > EPS_COL ? pow(ssaoOcclusion, contrastExponent) : 0.0;

        float viewNormalFacing = saturate(abs(dot(ssaoNormalWs, normalize(viewRayWs))));
        ssaoOcclusion *= viewNormalFacing;
        float ssaoWeight = saturate(ssaoOcclusion * SSAOColor.a);
        return BlendSsaoLayerColor(1.0.xxx, ssaoLayerColor, ssaoWeight, SSAOBlendMode);
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Shared Replace/Add/Multiply Blend Helper
    //-------------------------------------------------------------------------------------------------
    float3 BlendReplaceAddMultiply(float3 baseColor, float3 layerColor, float layerWeight, int blendMode)
    {
        // Compact blend set used by features with only Replace/Add/Multiply UI.
        float w = saturate(layerWeight);
        if (blendMode == 1)
        {
            return baseColor + layerColor * w;
        }

        if (blendMode == 2)
        {
            return baseColor * lerp(1.0.xxx, layerColor, w);
        }

        return lerp(baseColor, layerColor, w);
    }

    float3 BlendIndirectLighting(float3 baseColor, float3 indirectColor, int blendMode)
    {
        if (blendMode == 1)
        {
            return indirectColor;
        }

        if (blendMode == 2)
        {
            return baseColor * indirectColor;
        }

        return baseColor;
    }

    #if S_SHADING_MODE != 5
    //-------------------------------------------------------------------------------------------------
    // Cubemap Helpers
    //-------------------------------------------------------------------------------------------------
    float3 RotateCubemapDirectionX(float3 direction, float degrees)
    {
        float angle = degrees * 0.01745329252;
        float sine;
        float cosine;
        sincos(angle, sine, cosine);
        return float3(direction.x, direction.y * cosine - direction.z * sine, direction.y * sine + direction.z * cosine);
    }

    float3 RotateCubemapDirectionY(float3 direction, float degrees)
    {
        float angle = degrees * 0.01745329252;
        float sine;
        float cosine;
        sincos(angle, sine, cosine);
        return float3(direction.x * cosine + direction.z * sine, direction.y, -direction.x * sine + direction.z * cosine);
    }

    float3 RotateCubemapDirectionZ(float3 direction, float degrees)
    {
        float angle = degrees * 0.01745329252;
        float sine;
        float cosine;
        sincos(angle, sine, cosine);
        return float3(direction.x * cosine - direction.y * sine, direction.x * sine + direction.y * cosine, direction.z);
    }

    float3 BuildCubemapDirection()
    {
        // View direction is skybox-style; reflection direction follows the PBR/envmap normal.
        float3 viewDirection = normalize(viewRayWs);
        float3 cubemapDirection = CubemapUvMode == 0 ? -viewDirection : reflect(-viewDirection, reflectionNormalWs);
        cubemapDirection = RotateCubemapDirectionX(cubemapDirection, CubemapRotation.x);
        cubemapDirection = RotateCubemapDirectionY(cubemapDirection, CubemapRotation.y);
        cubemapDirection = RotateCubemapDirectionZ(cubemapDirection, CubemapRotation.z);
        cubemapDirection = RotateCubemapDirectionX(cubemapDirection, CubemapOffset.x);
        cubemapDirection = RotateCubemapDirectionY(cubemapDirection, CubemapOffset.y);
        cubemapDirection = RotateCubemapDirectionZ(cubemapDirection, CubemapOffset.z);
        return normalize(cubemapDirection);
    }

    float ComputeCubemapMip()
    {
        // Cubemap softness is intentionally a mild mip bias, not a full blur pass.
        return saturate(CubemapSoftness) * 3.5;
    }

    float3 SampleCubemapReflectionFallback()
    {
        // PBR fallback/force reuses the specified cubemap from "Cubemap" when there's no cubemap nearby.
        return CubemapTexture.SampleLevel(g_sAniso, BuildCubemapDirection(), ComputeCubemapMip()).rgb;
    }

    float3 BlendCubemapColor(float3 baseColor, float3 cubemapColor, float cubemapWeight)
    {
        // Cubemap UI order is Replace/Add/Multiply.
        return BlendReplaceAddMultiply(baseColor, cubemapColor, cubemapWeight, CubemapBlendMode);
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // PBR Mask And Specular Blend Helpers
    //-------------------------------------------------------------------------------------------------
    float3 BuildReflectionBlendColor(float3 reflectionColor, int blendMode)
    {
        // Multiply specular needs a neutral 1.0 base so highlights do not darken the material.
        if (blendMode == 3)
        {
            return 1.0.xxx + reflectionColor;
        }

        return reflectionColor;
    }

    // Toon specular blend: srcA is the specular shape mask, not a forced full-strength overlay.
    float3 ToonSpecularBlendColor(float3 dstCol, float3 srcCol, float srcA, int blendMode)
    {
        float3 blendAlpha = saturate(srcA).xxx;
        float3 ad = dstCol + srcCol;
        float3 mu = dstCol * srcCol;
        float3 outCol = dstCol;

        // 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply
        if (blendMode == 0)
        {
            outCol = ad;
        }
        else if (blendMode == 1)
        {
            outCol = max(ad - mu, dstCol);
        }
        else if (blendMode == 2)
        {
            outCol = srcCol;
        }
        else
        {
            outCol = mu;
        }

        return lerp(dstCol, outCol, blendAlpha);
    }

    float GetPackedMaskChannel(float4 maskValue, int channel)
    {
        // PBR mask channel selectors use 0=R, 1=G, 2=B, 3=A.
        if (channel == 1) return maskValue.g;
        if (channel == 2) return maskValue.b;
        if (channel == 3) return maskValue.a;
        return maskValue.r;
    }

    float3 BlendSpecularColor(float3 baseColor, float3 layerColor, int blendMode, float blendWeight)
    {
        float w = saturate(blendWeight);
        float3 targetBlend;

        if (blendMode == 0)
        {
            targetBlend = min(baseColor + layerColor, 1.0.xxx);
        }
        else if (blendMode == 1)
        {
            targetBlend = 1.0.xxx - (1.0.xxx - saturate(baseColor)) * (1.0.xxx - saturate(layerColor));
        }
        else if (blendMode == 2)
        {
            targetBlend = layerColor;
        }
        else
        {
            targetBlend = baseColor * layerColor;
        }

        return lerp(baseColor, targetBlend, w);
    }

    #if S_SHADING_MODE == 2
    //-------------------------------------------------------------------------------------------------
    // TextureRamp Helpers
    //-------------------------------------------------------------------------------------------------
    float ComputeRampLight(float offset)
    {
        // Offset shifts the ramp lookup without wrapping. The invert button only flips read direction from left-right to right-left.
        float rampLight = saturate(shadowLightMap + offset);
        rampLight = saturate(rampLight);
        return RampInvert ? 1.0 - rampLight : rampLight;
    }

    float2 FitRampUvToTexelCenters(Texture2D rampTexture, float2 uv)
    {
        // Clamp into texel centers, so 1D ramps and huge 2D ramps do not bleed boundary colors.
        uint rampWidth;
        uint rampHeight;
        rampTexture.GetDimensions(rampWidth, rampHeight);

        float2 rampSize = max(float2((float)rampWidth, (float)rampHeight), 1.0.xx);
        float2 rampPadding = 0.5.xx / rampSize;
        float2 fittedUv = lerp(rampPadding, 1.0.xx - rampPadding, saturate(uv));

        if (rampWidth <= 1)
        {
            fittedUv.x = 0.5;
        }

        if (rampHeight <= 1)
        {
            fittedUv.y = 0.5;
        }

        return fittedUv;
    }

    float3 SampleRampTexture(Texture2D rampTexture, float rampLight, float rampSampleV)
    {
        // Poi-style ramp handling: 1D strips read as gradients, while larger 2D textures can act as ramp sheets.
        uint rampWidth;
        uint rampHeight;
        rampTexture.GetDimensions(rampWidth, rampHeight);

        float2 rampUv;
        if (RampUVMode > 0)
        {
            rampUv = RampVertical ? float2(rampSampleV, 1.0 - rampLight) : float2(rampLight, rampSampleV);
        }
        else if (RampVertical)
        {
            rampUv = rampWidth <= 4 ? float2(0.5, 1.0 - rampLight) : (1.0 - rampLight).xx;
        }
        else
        {
            rampUv = rampHeight <= 4 ? float2(rampLight, 0.5) : rampLight.xx;
        }

        return rampTexture.SampleLevel(g_sBilinearClamp, FitRampUvToTexelCenters(rampTexture, rampUv), 0.0).rgb;
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Toon Anti-Aliasing Helpers
    //-------------------------------------------------------------------------------------------------
    // Geometric specular anti-aliasing.
    void GSAA(inout float roughness, float3 N, float strength)
    {
        // Normal derivatives widen very sharp highlights so they shimmer less on dense normal maps.
        float3 dx = abs(ddx(N));
        float3 dy = abs(ddy(N));
        float dxy = max(dot(dx, dx), dot(dy, dy));
        float roughnessGSAA = dxy / (dxy * 5.0 + 0.002) * strength;
        roughness = max(roughness, roughnessGSAA);
    }

    void GSAAForSmoothness(inout float smoothness, float3 N, float strength)
    {
        // Smoothness is artist-facing, but the underlying specular math wants roughness.
        float roughness = 0.0;
        GSAA(roughness, N, strength);
        smoothness = min(smoothness, saturate(1.0 - roughness));
    }

    float TooningScale(float aaScale, float value, float border, float blur);
    float TooningScale(float value, float border, float blur);
    float BorderScale(float aaScale, float value, float border, float blur);
    float BorderScale(float aaScale, float value, float border, float blur, float borderRange);

    bool IsRealisticShadingMode()
    {
        // Small compile-time helper used by reflection helpers that need Realistic-specific behavior.
        #if S_SHADING_MODE == 4
            return true;
        #else
            return false;
        #endif
    }

    bool IsPbrLightingActive()
    {
        // Realistic exposes PBR directly. Stylized modes also want a visible reflection/specular path.
        #if S_SHADING_MODE == 4
            return PbrEnabled;
        #elif S_SHADING_MODE != 5
            bool cubemapPbrReflection = CubemapEnabled && (ForcePbrReflection || UseAsPbrFallback);
            return PbrEnabled && (SpecularMode > 0 || EnvmapReflections || cubemapPbrReflection);
        #else
            return false;
        #endif
    }

    //-------------------------------------------------------------------------------------------------
    // Direct Specular Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_SHADING_MODE != 5
    float ComputeToonSpecularShape(float3 lightDirectionWs)
    {
        if (SpecularMode != 1 || !IsPbrLightingActive())
        {
            return 0.0;
        }

        float3 N = reflectionNormalWs;
        float3 V = normalize(viewRayWs);
        float3 L = normalize(lightDirectionWs);
        float3 H = normalize(V + L);

        float nh = saturate(dot(N, H));
        if (nh <= EPS_COL)
        {
            return 0.0;
        }

        // Shape from Smoothness slider only; PBR map is a separate black/white presence mask.
        float toonPerceptualRoughness = 1.0 - saturate(Smoothness);
        float toonRoughness = toonPerceptualRoughness * toonPerceptualRoughness;
        toonRoughness = max(toonRoughness, 1e-4);

        float specularPower = pow(nh, 1.0 / toonRoughness);
        return TooningScale(1.0, specularPower, ToonSpecularArea, ToonSpecularSoftness) * toonSpecularMapMask;
    }

    void AccumulateToonSpecular(float3 lightDirectionWs, float3 lightColor)
    {
        float shape = ComputeToonSpecularShape(lightDirectionWs);
        if (shape <= EPS_COL)
        {
            return;
        }

        // Light * Tint in src color, Shape * Tint alpha drives blend strength. Just how LilToon did it.
        toonSpecularSrcColor += lightColor * SpecularTint.rgb;
        toonSpecularBlendWeight = max(toonSpecularBlendWeight, shape * SpecularTint.a);
    }

    // GGX direct specular — uses the shared PBR reflection state.
    float3 ComputeReflectionSpecular(float3 lightDirectionWs, float3 lightColor)
    {
        if (!IsPbrLightingActive() || SpecularMode <= 1)
        {
            return 0.0.xxx;
        }

        if (reflectionPbrResponse <= EPS_COL)
        {
            return 0.0.xxx;
        }

        float3 N = reflectionNormalWs;
        float3 V = normalize(viewRayWs);
        float3 L = normalize(lightDirectionWs);
        float3 H = normalize(V + L);
        float nh = saturate(dot(N, H));

        if (nh <= EPS_COL)
        {
            return 0.0.xxx;
        }

        float nv = saturate(dot(N, V));
        float nl = saturate(dot(N, L));
        float lh = saturate(dot(L, H));
        if (nv <= EPS_COL || nl <= EPS_COL)
        {
            return 0.0.xxx;
        }

        float roughness2 = max(reflectionRoughness, 0.002);
        float lambdaV = nl * (nv * (1.0 - roughness2) + roughness2);
        float lambdaL = nv * (nl * (1.0 - roughness2) + roughness2);

        float r2 = roughness2 * roughness2;
        float d = (nh * r2 - nh) * nh + 1.0;
        float ggx = r2 / (d * d + 1e-7f);
        float sjggx = 0.5 / (lambdaV + lambdaL + 1e-5f);
        float specularTerm = sjggx * ggx * nl;

        float3 fresnel = ComputeReflectionFresnel(reflectionSpecularColor, lh);
        return lightColor * reflectionLayerColor.rgb * fresnel * (specularTerm * reflectionLayerColor.a);
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // SubsurfaceScattering Helpers
    //-------------------------------------------------------------------------------------------------
    #if S_SHADING_MODE != 5
    float ComputeSubsurfaceScatteringWeight(float3 lightDirectionWs, float attenuation)
    {
        if (!SubsurfaceScatteringEnabled || SubsurfaceScatteringIntensity <= EPS_COL || SubsurfaceScatteringMaskWeight <= EPS_COL)
        {
            return 0.0;
        }

        // Poiyomi-style transmission, with a surface-edge gate so the glow stays attached to the mesh silhouette.
        float3 V = normalize(viewRayWs);
        float3 sssLightDirectionWs = normalize(lightDirectionWs + SubsurfaceScatteringNormalWs);
        float spreadExponent = lerp(10.0, 1.0, sqrt(saturate(SubsurfaceScatteringSpread)));
        float transmission = pow(saturate(dot(V, -sssLightDirectionWs)), max(spreadExponent, EPS_COL));
        float edgeWeight = sqrt(saturate(1.0 - abs(dot(V, SubsurfaceScatteringNormalWs))));
        float thicknessWeight = saturate(SubsurfaceScatteringMaskWeight - (1.0 - saturate(SubsurfaceScatteringThickness)));
        return transmission * edgeWeight * thicknessWeight * saturate(attenuation) * sqrt(saturate(SubsurfaceScatteringIntensity));
    }
    #endif

    //-------------------------------------------------------------------------------------------------
    // Backlit Helpers
    //-------------------------------------------------------------------------------------------------
    // Backlit follows light-through-form shape and stays additive.
    float ComputeBacklightWeight(float3 lightDirectionWs, float attenuation)
    {
        // Sampled once in Init(), then evaluated here per light so it reacts to direct light direction too.
        if (!BacklitEnabled || BacklitIntensity <= EPS_COL || backlitMaskWeight <= EPS_COL)
        {
            return 0.0;
        }

        float3 V = normalize(viewRayWs);
        float3 L = normalize(lightDirectionWs);
        float hl = dot(V, L);
        float backlightFactor = pow(saturate(-hl * 0.5 + 0.5), max(BacklitDirectivity, EPS_COL));

        float3 backlightSlider = normalize(-V * BacklitViewDirectionStrength + L);
        float backlightLN = dot(backlightSlider, backlitNormalWs) * 0.5 + 0.5;
        backlightLN *= saturate(attenuation);
        backlightLN = TooningScale(1.0, backlightLN, BacklitArea, BacklitSoftness);

        return saturate(backlightFactor * backlightLN) * backlitMaskWeight;
    }
    //-------------------------------------------------------------------------------------------------
    // Toon Band And Border Helpers
    //-------------------------------------------------------------------------------------------------
    // Anti-aliasing helpers for smooth toon band transitions and shadow borders.
    // Anti-aliased threshold helper for shadow bands.
    float TooningScale(float aaScale, float value, float border, float blur)
    {
        float borderMin = saturate(border - blur * 0.5);
        float borderMax = saturate(border + blur * 0.5);
        return saturate((value - borderMin) / max(borderMax - borderMin, EPS_COL));
    }

    // Same helper with the default AA strength.
    float TooningScale(float value, float border, float blur)
    {
        // Match lilToon's default AA strength.
        return TooningScale(1.0, value, border, blur);
    }

    // Anti-aliased threshold helper for border masks.
    float BorderScale(float aaScale, float value, float border, float blur)
    {
        float borderMin = saturate(border - blur * 0.5);
        float borderMax = saturate(border + blur * 0.5);
        float range = max(borderMax - borderMin, EPS_COL);
        return saturate((value - borderMin) / range);
    }

    // Anti-aliased threshold helper with an extra border range for edge tints.
    float BorderScale(float aaScale, float value, float border, float blur, float borderRange)
    {
        float borderMin = saturate(border - blur * 0.5 - borderRange);
        float borderMax = saturate(border + blur * 0.5);
        float range = max(borderMax - borderMin, EPS_COL);
        return saturate((value - borderMin) / range);
    }

    //-------------------------------------------------------------------------------------------------
    // Layer Blend Helpers
    //-------------------------------------------------------------------------------------------------
    // Standard blend modes for layered color textures.
    // These are used by Second Color, Matcap, Rim, Emission, and similar overlays.
    float3 BlendLayerLinearDodge(float3 baseColor, float3 layerColor)
    {
        return min(baseColor + layerColor, 1.0.xxx);
    }

    float3 BlendLayerScreen(float3 baseColor, float3 layerColor)
    {
        return 1.0.xxx - (1.0.xxx - baseColor) * (1.0.xxx - layerColor);
    }

    float BlendLayerOverlayChannel(float baseValue, float layerValue)
    {
        return baseValue < 0.5 ? (2.0 * baseValue * layerValue) : (1.0 - 2.0 * (1.0 - baseValue) * (1.0 - layerValue));
    }

    float3 BlendLayerOverlay(float3 baseColor, float3 layerColor)
    {
        return float3(
            BlendLayerOverlayChannel(baseColor.r, layerColor.r),
            BlendLayerOverlayChannel(baseColor.g, layerColor.g),
            BlendLayerOverlayChannel(baseColor.b, layerColor.b)
        );
    }

    float3 BlendLayerColor(float3 baseColor, float3 layerColor, float layerWeight, int blendMode)
    {
        float w = saturate(layerWeight);
        // Order: Add, Screen, Replace, Multiply, Darken, Lighten, Subtract, Overlay.
        float3 t;
        [flatten]
        if      (blendMode == 0) t = BlendLayerLinearDodge(baseColor, layerColor);
        else if (blendMode == 1) t = BlendLayerScreen(baseColor, layerColor);
        else if (blendMode == 2) t = layerColor;
        else if (blendMode == 3) t = baseColor * layerColor;
        else if (blendMode == 4) t = min(baseColor, layerColor);
        else if (blendMode == 5) t = max(baseColor, layerColor);
        else if (blendMode == 6) t = max(baseColor - layerColor, 0.0.xxx);
        else t = BlendLayerOverlay(baseColor, layerColor);
        return lerp(baseColor, t, w);
    }

    // Shademap/multi-layer shadows use this smaller blend set to avoid the extended overlay modes.
    float3 BlendShadowColor(float3 baseColor, float3 layerColor, float layerWeight, int blendMode)
    {
        float3 targetBlend = layerColor;
        if (blendMode == 1)
        {
            targetBlend = baseColor * layerColor;
        }

        return lerp(baseColor, targetBlend, saturate(layerWeight));
    }

    //-------------------------------------------------------------------------------------------------
    // Matcap Helpers
    //-------------------------------------------------------------------------------------------------
    // Build matcap UVs from the current view direction and surface normal.
    // This is camera-relative, not mesh-UV based.
    float2 CalcMatcapUv(float3 shadingNormalWs, float3 shadingViewDirWs)
    {
        float3 worldCameraUp = normalize(g_vCameraUpDirWs);
        float3 worldViewUp = normalize(worldCameraUp - shadingViewDirWs * dot(shadingViewDirWs, worldCameraUp));
        float3 worldViewRight = normalize(cross(shadingViewDirWs, worldViewUp));
        float2 matcapUv = float2(dot(worldViewRight, shadingNormalWs), dot(worldViewUp, shadingNormalWs)) * 0.5 + 0.5;
        return saturate(matcapUv);
    }

    float3 ApplyMatcapTintColor(float3 matcapColor, float4 tintColor, float tintIntensity)
    {
        // Tinting is multiplicative so white tint stays neutral and colored tint behaves correctly.
        return matcapColor * lerp(1.0.xxx, tintColor.rgb, saturate(tintIntensity));
    }

