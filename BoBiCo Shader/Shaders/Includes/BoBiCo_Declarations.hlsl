//=========================================================================================================================
// BoBiCo PS declarations.
// Included inside the PS block after common/pixel.hlsl. Keep UI fields and render states here.
//=========================================================================================================================

//=========================================================================================================================
// Shader controls : General Settings
//=========================================================================================================================

    // Culling Mode mapping: 1 = Front/Back, 2 = Back, 3 = Front, 4 = Invisible.
    int CullingMode < UiType(Slider); Range(1, 4); Default(1); UiGroup("General Settings,1/Culling Mode,10/1"); >;

    // Optional light clamp for render scenes with very weak or very hot lights.
    bool LimitLightBrightness < UiType(Checkbox); Default(1); UiGroup("General Settings,1/Light Brightness Limit,15/1"); >;
    float LightMinLimit < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("General Settings,1/Light Brightness Limit,15/2"); >;
    float LightMaxLimit < UiType(Slider); Range(0.0, 4.0); Default1(1.0); UiGroup("General Settings,1/Light Brightness Limit,15/3"); >;

    // Lighting settings stay under General Settings so the top-level group does not jump around.
    bool Unlit < UiType(Checkbox); Default(0); UiGroup("General Settings,1/Lighting Settings,20/1"); >;
    float DirectLightIntensity < UiType(Slider); Range(0.0, 2.0); Default(0.5); UiGroup("General Settings,1/Lighting Settings,20/2"); >;
    float LitIntensity < UiType(Slider); Range(0.0, 2.0); Default(0.5); UiGroup("General Settings,1/Lighting Settings,20/3"); >;
    float GrayscaleLighting < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("General Settings,1/Lighting Settings,20/4"); >;
    float3 OverwriteLightDirection < UiType(Slider); Range3(-180.0, -180.0, -180.0, 180.0, 180.0, 180.0); Default3(0.0, 0.0, 0.0); UiGroup("General Settings,1/Lighting Settings,20/5"); >;

//=========================================================================================================================
// Shader controls : Main Color
//=========================================================================================================================

    // Main Color
    CreateInputTexture2D(ColorTexture, Srgb, 8, "None", "_color", "Main Color,3/Main Color,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ColorMap)< Channel(RGBA, Box(ColorTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;

    // UV settings
    float2 MainColorTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Main Color,3/UV Settings,20/1"); >;
    float2 MainColorOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Main Color,3/UV Settings,20/2"); >;
    float MainColorRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Main Color,3/UV Settings,20/3"); >;

    // UV Animation
    float2 MainColorScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("Main Color,3/UV Animation,30/1"); >;
    float MainColorRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Main Color,3/UV Animation,30/2"); >;

//=========================================================================================================================
// Shader controls : Color Adjustment
//=========================================================================================================================

    // Color Adjustment
    bool ColorAdjustEnabled < UiType(Checkbox); Default(0); UiGroup("Color Adjust,4/Color Adjustments,10/1"); >;
    // Default tint and color adjustments. 
    float4 TintColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Color Adjust,4/Color Adjustments,10/2"); >;
    int HueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Color Adjust,4/Color Adjustments,10/3"); >;
    int HueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Color Adjust,4/Color Adjustments,10/4"); >;
    float ColorHue < UiType(Slider); Range(0, 1); Default1(0.0); UiGroup("Color Adjust,4/Color Adjustments,10/5"); >;
    float ColorHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Color Adjust,4/Color Adjustments,10/6"); >;
    float ColorBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/Color Adjustments,10/7"); >;
    float ColorSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/Color Adjustments,10/8"); >;
    float ColorGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/Color Adjustments,10/9"); >;

    // Color Tint Masking. RGBA channels drive adjustment strength: R = Hue, G = Brightness, B = Saturation, A = Gamma.
    CreateInputTexture2D(ColorTintMask, Linear, 8, "None", "_tint", "Color Adjust,4/Masking,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ColorTintMaskTexture)< Channel(RGBA, Box(ColorTintMask), Linear); OutputFormat(BC7); SrgbRead(false); >;
    int TintMaskType < UiType(Slider); Range(1, 3); Default(1); UiGroup("Color Adjust,4/Masking,10/2"); >;
    float ColorTintMaskingIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Color Adjust,4/Masking,10/3"); >;
    float2 ColorTintMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Color Adjust,4/Masking,10/4"); >;
    float2 ColorTintMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Color Adjust,4/Masking,10/5"); >;
    float ColorTintMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Color Adjust,4/Masking,10/6"); >;
    bool ColorTintMaskInvert < UiType(CheckBox); Default(0); UiGroup("Color Adjust,4/Masking,10/7"); >;

    // Second tint branch for Multi Tint Mask Type. Black mask areas select this branch when TintMaskType is 2.
    float4 SecondTintColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Color Adjust,4/2nd Tint,30/1"); >;
    int SecondTintHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Color Adjust,4/2nd Tint,30/2"); >;
    int SecondTintHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Color Adjust,4/2nd Tint,30/3"); >;
    float SecondTintHue < UiType(Slider); Range(0, 1); Default1(0.0); UiGroup("Color Adjust,4/2nd Tint,30/4"); >;
    float SecondTintHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Color Adjust,4/2nd Tint,30/5"); >;
    float SecondTintBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/2nd Tint,30/6"); >;
    float SecondTintSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/2nd Tint,30/7"); >;
    float SecondTintGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Color Adjust,4/2nd Tint,30/8"); >;

    // Gradient map branch.
    CreateInputTexture2D(GradientMap, Srgb, 8, "None", "_gradientmap", "Color Adjust,4/Gradient Map,40/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(GradientMapTexture)< Channel(RGBA, Box(GradientMap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float GradientMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Color Adjust,4/Gradient Map,40/2"); >;

//=========================================================================================================================
// Shader controls : Backface 
//=========================================================================================================================

    // Face-culling settings.
    bool FlipBackfaceNormal < UiType(CheckBox); Default(0); UiGroup("Backface,5/Backface Settings,10/1"); >;
    float4 BackfaceColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Backface,5/Backface Settings,10/2"); >;
    float BackfaceColorIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Backface,5/Backface Settings,10/3"); >;
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int BackfaceColorBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("Backface,5/Backface Settings,10/4"); >;

    // Backface Color Adjustments
    int BackfaceHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Backface,5/Color Adjustments,20/1"); >;
    int BackfaceHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Backface,5/Color Adjustments,20/2"); >;
    float BackfaceHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Backface,5/Color Adjustments,20/3"); >;
    float BackfaceHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Backface,5/Color Adjustments,20/4"); >;
    float BackfaceBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Backface,5/Color Adjustments,20/5"); >;
    float BackfaceSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Backface,5/Color Adjustments,20/6"); >;
    float BackfaceGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Backface,5/Color Adjustments,20/7"); >;

    // Backface Emission
    float4 BackfaceEmissionColor < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("Backface,5/Backface Emission,30/1"); >;
    float BackfaceEmissionIntensity < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Backface,5/Backface Emission,30/2"); >;

//=========================================================================================================================
// Shader controls : Alpha Settings
//=========================================================================================================================

#if S_ALPHA_MODE != 0
    // Alpha Masking
    CreateInputTexture2D(AlphaMask, Linear, 8, "None", "_alpha", "Alpha Settings,6/Alpha Mask,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(AlphaMaskTexture)< Channel(R, Box(AlphaMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
     
    // UV Settings 
    float2 AlphaMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Alpha Settings,6/Alpha Mask,10/3"); >;
    float2 AlphaMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Alpha Settings,6/Alpha Mask,10/4"); >;
    float AlphaMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Alpha Settings,6/Alpha Mask,10/5"); >;
     
    // UV Animation 
    float2 AlphaMaskScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("Alpha Settings,6/Alpha Mask,10/6"); >;
    float AlphaMaskRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Alpha Settings,6/Alpha Mask,10/7"); >;

    bool UseAlphaMask < UiType(Checkbox); Default(0); UiGroup("Alpha Settings,6/Alpha Settings,20/1"); >;
    // Alpha Masking Mode mapping: 1 = Mask/Gate, 2 = Multiply, 3 = Add, 4 = Subtract.
    int AlphaMaskingMode < UiType(Slider); Range(1, 4); Default(1); UiGroup("Alpha Settings,6/Alpha Settings,20/2"); >;
    bool AlphaMaskInvert < UiType(CheckBox); Default1(0.0); UiGroup("Alpha Settings,6/Alpha Mask,10/8"); >;
    float AlphaIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Alpha Settings,6/Alpha Settings,20/4"); >;
    // Alpha Cutoff only show up in "Cutoff" Rendering Mode.
    float AlphaCutoff < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Alpha Settings,6/Alpha Settings,20/5"); >;

    // Dithering Alpha, Best to use with A2C to soften edges. 
    bool DitherAlpha < UiType(Checkbox); Default(0); UiGroup("Alpha Settings,6/Dither Alpha,30/1"); >;
    float DitherAlphaGradient < UiType(Slider); Range(0.0, 1.0); Default1(0.1); UiGroup("Alpha Settings,6/Dither Alpha,30/2"); >;
    float DitherAlphaBias < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Alpha Settings,6/Dither Alpha,30/3"); >;

    // Fresnel Alpha
    bool FresnelAlpha < UiType(Checkbox); Default(0); UiGroup("Alpha Settings,6/Fresnel Alpha,40/1"); >;
    float FresnelAlphaIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Alpha Settings,6/Fresnel Alpha,40/2"); >;
    float FresnelAlphaSharpness < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Alpha Settings,6/Fresnel Alpha,40/3"); >;
    float FresnelAlphaWidth < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Alpha Settings,6/Fresnel Alpha,40/4"); >;
    bool FresnelAlphaInvert < UiType(Checkbox); Default(0); UiGroup("Alpha Settings,6/Fresnel Alpha,40/5"); >;

    #if S_ALPHA_MODE == 1
    // Alpha-to-coverage softens Cutoff edges through MSAA sample coverage. only show up in "Cutoff" Rendering Mode.
    bool A2CEnabled < UiType(Checkbox); Default(0); UiGroup("Alpha Settings,6/Alpha To Coverage,50/1"); >;
    float A2CIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Alpha Settings,6/Alpha To Coverage,50/2"); >;
    #endif
#endif

//=========================================================================================================================
// Shader controls : Second Color
//=========================================================================================================================

#if S_ENABLED_EXTRA_LAYERS
    // Second Color 
    bool SecondColorEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Color,7/2nd Color,10/1"); >;
    CreateInputTexture2D(SecondColor, Srgb, 8, "None", "_2ndcolor", "2nd Color,7/2nd Color,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SecondColorTexture)< Channel(RGBA, Box(SecondColor), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    bool SecondColorUseAlpha < UiType(Checkbox); Default(0); UiGroup("2nd Color,7/2nd Color,10/3"); >;
    int SecondColorAlphaMode < UiType(Slider); Range(0, 4); Default(0); UiGroup("2nd Color,7/2nd Color,10/4"); >;
    float4 SecondColorTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("2nd Color,7/2nd Color,10/5"); >;
    float SecondColorTintIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/2nd Color,10/6"); >;

    // Second Color Masking
    CreateInputTexture2D(SecondColorMask, Linear, 8, "None", "_2ndcolormask", "2nd Color,7/Masking,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SecondColorMaskTexture)< Channel(R, Box(SecondColorMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    bool SecondColorMaskInvert < UiType(Checkbox); Default(0); UiGroup("2nd Color,7/Masking,20/2"); >;
    float SecondColorMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/Masking,20/3"); >;
    float2 SecondColorMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Color,7/Masking,20/4"); >;
    float2 SecondColorMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Color,7/Masking,20/5"); >;
    float SecondColorMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Color,7/Masking,20/6"); >;

    float SecondColorOpacity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/2nd Color Settings,30/1"); >;
    // Controls how the Second color blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int SecondColorBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("2nd Color,7/2nd Color Settings,30/2"); >;
    // Controls how the Second color's alpha affects surface opacity in Translucent mode.
    // Alpha Mode mapping: 0 = None, 1 = Replace (Default), 2 = Multiply, 3 = Add, 4 = Subtract.
    float SecondColorLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("2nd Color,7/2nd Color Settings,30/3"); >;
    float SecondColorEmission < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("2nd Color,7/2nd Color Settings,30/4"); >;
    // Culling Mode mapping: 1 = Front/Back, 2 = Back, 3 = Front, 4 = Invisible.
    int SecondColorCullingMode < UiType(Slider); Range(1, 4); Default(1); UiGroup("2nd Color,7/2nd Color Settings,30/5"); >;

    // Decal settings for the second color layer.
    bool SecondColorUseAsDecal < UiType(Checkbox); Default(0); UiGroup("2nd Color,7/Decal Settings,40/1"); >;

    // Mirror Mode mapping: 0 = Normal, 1 = Flip, 2 = Left only, 3 = Right only, 4 = Flip Right only.
    int SecondColorMirrorMode < UiType(Slider); Range(0, 4); Default(0); UiGroup("2nd Color,7/Decal Settings,40/3"); >;
    // Copy Mode mapping: 0 = Normal, 1 = Symmetry, 2 = Flip.
    int SecondColorCopyMode < UiType(Slider); Range(0, 2); Default(0); UiGroup("2nd Color,7/Decal Settings,40/4"); >;
    float2 SecondColorPosition < UiType(Slider); Range2(-20.0, -20.0, 20.0, 20.0); Default2(0.0, 0.0); UiGroup("2nd Color,7/Decal Settings,40/5"); >;
    float2 SecondColorScale < UiType(Slider); Range2(0.00, 0.00, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Color,7/Decal Settings,40/6"); >;
    float SecondColorRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Color,7/Decal Settings,40/7"); >;
    float2 SecondColorScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("2nd Color,7/Decal Settings,40/8"); >;
    float SecondColorRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/Decal Settings,40/9"); >;

    // UV settings for normal Second Color layering. Decal mode keeps using the dedicated Decal Settings above.
    float2 SecondColorTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Color,7/UV Settings,50/1"); >;
    float2 SecondColorOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Color,7/UV Settings,50/2"); >;
    float SecondColorUvRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Color,7/UV Settings,50/3"); >;

    // UV animation for normal Second Color layering.
    float2 SecondColorUvScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("2nd Color,7/UV Animation,55/1"); >;
    float SecondColorUvRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/UV Animation,55/2"); >;

    // Second Color Adjustments
    int SecondColorHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Color,7/Color Adjustments,60/1"); >;
    int SecondColorHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Color,7/Color Adjustments,60/2"); >;
    float SecondColorHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Color,7/Color Adjustments,60/3"); >;
    float SecondColorHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("2nd Color,7/Color Adjustments,60/4"); >;
    float SecondColorBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Color,7/Color Adjustments,60/5"); >;
    float SecondColorSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Color,7/Color Adjustments,60/6"); >;
    float SecondColorGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Color,7/Color Adjustments,60/7"); >;
#endif

//=========================================================================================================================
// Shader controls : Normal Map
//=========================================================================================================================

    // Normal Map 
	CreateInputTexture2D( NormalMap, Linear, 8, "NormalizeNormals", "_normal", "Normal Map,8/Normal Map,10/2", DefaultFile( "BoBiCo Shader/Textures/Normals/FlatNormal.png" ));
	CreateTexture2D(NormalMapTexture)< Channel( RGB, Box( NormalMap ), linear ); OutputFormat( BC7 ); SrgbRead( false ); >;
    bool NormalMapEnabled < UiType(Checkbox); Default(0); UiGroup("Normal Map,8/Normal Map,10/1"); >;
    float NormalIntensity < UiType(Slider); Range(0.0, 10.0); Default1(1.0); UiGroup("Normal Map,8/Normal Map,10/3"); >;

    // Normal Map UV Settings
    float2 NormalTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Normal Map,8/UV Settings,20/1"); >;
    float2 NormalOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Normal Map,8/UV Settings,20/2"); >;
    float NormalRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Normal Map,8/UV Settings,20/3"); >;

    // UV Animation
    float2 NormalScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("Normal Map,8/UV Animation,30/1"); >;
    float NormalRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Normal Map,8/UV Animation,30/2"); >;

//=========================================================================================================================
// Shader controls : Second Normal Map
//=========================================================================================================================

#if S_ENABLED_EXTRA_LAYERS
    // Second Normal Map
    bool SecondNormalEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Normal Map,9/2nd Normal Map,10/1"); >;
    CreateInputTexture2D( SecondNormalMap, Linear, 8, "NormalizeNormals", "_2ndnormal", "2nd Normal Map,9/2nd Normal Map,10/2", DefaultFile( "BoBiCo Shader/Textures/Normals/FlatNormal.png" ));
    CreateTexture2D(SecondNormalMapTexture)< Channel( RGB, Box( SecondNormalMap ), linear ); OutputFormat( BC7 ); SrgbRead( false ); >;
    float SecondNormalIntensity < UiType(Slider); Range(0.0, 10.0); Default1(0.0); UiGroup("2nd Normal Map,9/2nd Normal Map,10/3"); >;

    // Second Normal Map Masking
    CreateInputTexture2D(SecondNormalMask, Linear, 8, "None", "_2ndnormalmask", "2nd Normal Map,9/Masking,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SecondNormalMaskTexture)< Channel(R, Box(SecondNormalMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    bool SecondNormalMaskInvert < UiType(Checkbox); Range(0, 1); Default(0); UiGroup("2nd Normal Map,9/Masking,20/2"); >;
    float SecondNormalMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Normal Map,9/Masking,20/3"); >;

    // Second Normal Map Masking UV Settings
    float2 SecondNormalMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Normal Map,9/Masking,20/4"); >;
    float2 SecondNormalMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Normal Map,9/Masking,20/5"); >;
    float SecondNormalMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Normal Map,9/Masking,20/6"); >;

    // UV Settings
    int SecondNormalUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("2nd Normal Map,9/UV Settings,30/1"); >;
    float2 SecondNormalTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Normal Map,9/UV Settings,30/2"); >;
    float2 SecondNormalOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Normal Map,9/UV Settings,30/3"); >;
    float SecondNormalRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Normal Map,9/UV Settings,30/4"); >;
    
    // UV Animation
    float2 SecondNormalScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("2nd Normal Map,9/UV Animation,40/1"); >;
    float SecondNormalRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("2nd Normal Map,9/UV Animation,40/2"); >;
#endif

#if S_SHADING_MODE == 5
//=========================================================================================================================
// Shader controls : Fur
//=========================================================================================================================

    // Fur Normal Map
    CreateInputTexture2D(FurNormalMap, Linear, 8, "NormalizeNormals", "_furnormal", "Fur Shading,10/Fur Normal Map,20/1", DefaultFile( "BoBiCo Shader/Textures/Normals/FlatNormal.png"));
    Texture2D FurNormalTexture < Channel(RGB, Box(FurNormalMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float2 FurNormalTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Fur Shading,10/Fur Normal Map,20/2"); >;
    float2 FurNormalOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Fur Shading,10/Fur Normal Map,20/3"); >;

    // Fur Noise Map
    CreateInputTexture2D(FurNoiseMap, Linear, 8, "None", "_furnoise", "Fur Shading,10/Fur Noise Map,30/1", DefaultFile( "BoBiCo Shader/Textures/Fur Noise/lil_noise_fur_2.png" ));
    CreateTexture2D(FurNoiseTexture)< Channel(R, Box(FurNoiseMap), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 FurNoiseTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(10.0, 10.0); UiGroup("Fur Shading,10/Fur Noise Map,30/2"); >;
    float2 FurNoiseOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Fur Shading,10/Fur Noise Map,30/3"); >;

    #if S_ALPHA_MODE != 0
    // Fur Alpha Map only matters when the material alpha path is active.
    CreateInputTexture2D(FurAlphaMask, Linear, 8, "None", "_furalpha", "Fur Shading,10/Fur Alpha Map,40/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(FurAlphaMaskTexture)< Channel(R, Box(FurAlphaMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float FurAlphaIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Fur Shading,10/Fur Alpha Map,40/2"); >;
    float2 FurAlphaMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Fur Shading,10/Fur Alpha Map,40/3"); >;
    float2 FurAlphaMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Fur Shading,10/Fur Alpha Map,40/4"); >;
    #endif

    // Fur settings.
    float FurNormalMapIntensity < UiType(Slider); Range(-5.0, 5.0); Default1(1.0); UiGroup("Fur Shading,10/Fur Settings,50/2"); >;
    int FurLayerCounts < UiType(Slider); Range(0, 3); Default(2); UiGroup("Fur Shading,10/Fur Settings,50/1"); >;
    float FurSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Fur Shading,10/Fur Settings,50/7"); >;
    float FurAo < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Fur Shading,10/Fur Settings,50/8"); >;

    // Fur Rim Lighting
    bool FurRimLightEnabled < UiType(Checkbox); Default(1); UiGroup("Fur Shading,10/Fur Rim Lighting,70/1"); >;
    float4 FurRimColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Fur Shading,10/Fur Rim Lighting,70/2"); >;
    float FurRimIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.85); UiGroup("Fur Shading,10/Fur Rim Lighting,70/3"); >;
    float FurRimTipArea < UiType(Slider); Range(0.01, 1.0); Default1(1.0); UiGroup("Fur Shading,10/Fur Rim Lighting,70/4"); >;
    float FurRimFresnel < UiType(Slider); Range(0.0, 5.0); Default1(0.10); UiGroup("Fur Shading,10/Fur Rim Lighting,70/5"); >;
    float FurRimLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.25); UiGroup("Fur Shading,10/Fur Rim Lighting,70/6"); >;
#endif

// Only allow "Multi-layer" shading in "Fur" mode. Because almost every VRC models use "Multi-layer" and won't need others.
// There is another reason due to texture binding limit.
#if S_SHADING_MODE == 1 || S_SHADING_MODE == 5
//=========================================================================================================================
// Shader controls : Multi-layer Shading
//=========================================================================================================================

    // Shadow Map
    CreateInputTexture2D(ShadowMap, Linear, 8, "None", "_shadowmap", "Multi-Layer Shading,11/Shadow Map,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ShadowMapTexture)< Channel(RGBA, Box(ShadowMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float2 ShadowMapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Multi-Layer Shading,11/Shadow Map,10/2"); >;
    float2 ShadowMapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Multi-Layer Shading,11/Shadow Map,10/3"); >;
    float ShadowMapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/Shadow Map,10/4"); >;

    // Shadow map settings.
    int ShadowMapType < UiType(Slider); Range(0, 2); Default(0); UiGroup("Multi-Layer Shading,11/Shadow Map Settings,20/1"); >;
    float ShadowMapIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/Shadow Map Settings,20/2"); >;
    bool ShadowMapInvert < UiType(Checkbox); Range(0, 1); Default(0); UiGroup("Multi-Layer Shading,11/Shadow Map Settings,20/3"); >;

    // Flat shadow map settings.
    float FlatShadowMapArea < UiType(Slider); Range(-2.0, 2.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/Flat Shadow Map Settings,30/1"); >;
    float FlatShadowMapSoftness < UiType(Slider); Range(0.001, 2.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/Flat Shadow Map Settings,30/2"); >;

    // SDF map settings.
    float SDFMapBlendYDirection < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/SDF Map Settings,40/1"); >;

    // Shadow shading settings.
    // First shadow layer settings.
    float4 ShadowColor < UiType(Color); Default4(0.7, 0.75, 0.85, 1.0); UiGroup("Multi-Layer Shading,11/1st Shadow Layer,50/1"); >;
    float ShadowIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/1st Shadow Layer,50/2"); >;
    float ShadowArea < UiType(Slider); Range(0.0, 1.0); Default1(0.75); UiGroup("Multi-Layer Shading,11/1st Shadow Layer,50/3"); >;
    float ShadowSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Multi-Layer Shading,11/1st Shadow Layer,50/4"); >;
    float ShadowNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/1st Shadow Layer,50/5"); >;

    // Second shadow layer settings.
    float4 SecondShadowColor < UiType(Color); Default4(0.55, 0.60, 0.70, 1.0); UiGroup("Multi-Layer Shading,11/2nd Shadow Layer,60/1"); >;
    float SecondShadowIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/2nd Shadow Layer,60/2"); >;
    float SecondShadowArea < UiType(Slider); Range(0.0, 1.0); Default1(0.55); UiGroup("Multi-Layer Shading,11/2nd Shadow Layer,60/3"); >;
    float SecondShadowSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.45); UiGroup("Multi-Layer Shading,11/2nd Shadow Layer,60/4"); >;
    float SecondShadowNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/2nd Shadow Layer,60/5"); >;

    // Third shadow layer settings.
    float4 ThirdShadowColor < UiType(Color); Default4(0.40, 0.45, 0.55, 1.0); UiGroup("Multi-Layer Shading,11/3rd Shadow Layer,70/1"); >;
    float ThirdShadowIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/3rd Shadow Layer,70/2"); >;
    float ThirdShadowArea < UiType(Slider); Range(0.0, 1.0); Default1(0.35); UiGroup("Multi-Layer Shading,11/3rd Shadow Layer,70/3"); >;
    float ThirdShadowSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.40); UiGroup("Multi-Layer Shading,11/3rd Shadow Layer,70/4"); >;
    float ThirdShadowNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Multi-Layer Shading,11/3rd Shadow Layer,70/5"); >;

    // Shadow edge settings.
    float4 ShadowEdgeColor < UiType(Color); Default4(1.0, 0.1, 0.0, 1.0); UiGroup("Multi-Layer Shading,11/Shadow Edge,80/1"); >;
    float ShadowEdgeRange < UiType(Slider); Range(0.0, 1.0); Default1(0.00); UiGroup("Multi-Layer Shading,11/Shadow Edge,80/2"); >;

    // Shadow blur mask settings.
    CreateInputTexture2D(ShadowBlurMask, Linear, 8, "None", "_shadowblurmask", "Multi-Layer Shading,11/Blur Mask,90/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ShadowBlurMaskTexture)< Channel(RGBA, Box(ShadowBlurMask), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float ShadowBlurMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/Blur Mask,90/2"); >;

    // Shadow Ao mask settings.
    CreateInputTexture2D(ShadowAoMask, Linear, 8, "None", "_shadowaomask", "Multi-Layer Shading,11/Ao Mask,100/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ShadowAoMaskTexture)< Channel(RGBA, Box(ShadowAoMask), Linear); OutputFormat(BC7); SrgbRead(false); >;
    bool UseShadowAoMask < UiType(Checkbox); Default(0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/3"); >;
    bool ShadowAoMaskInvert < UiType(Checkbox); Default(0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/4"); >;
    bool ShadowAoMaskIgnoreBorderProperties < UiType(Checkbox); Default(0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/5"); >;
    float ShadowAoMask1Min < UiType(Slider); Range(-0.01, 1.01); Default1(0.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/6"); >;
    float ShadowAoMask1Max < UiType(Slider); Range(-0.01, 1.01); Default1(1.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/7"); >;
    float ShadowAoMask2Min < UiType(Slider); Range(-0.01, 1.01); Default1(0.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/8"); >;
    float ShadowAoMask2Max < UiType(Slider); Range(-0.01, 1.01); Default1(1.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/9"); >;
    float ShadowAoMask3Min < UiType(Slider); Range(-0.01, 1.01); Default1(0.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/10"); >;
    float ShadowAoMask3Max < UiType(Slider); Range(-0.01, 1.01); Default1(1.0); UiGroup("Multi-Layer Shading,11/Ao Mask,100/11"); >;

    // Blending settings for the shadow layers.
    float ShadowEnvironmentStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/Shadow Settings,110/1"); >;
    float ShadowContrast < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Multi-Layer Shading,11/Shadow Settings,110/2"); >;
#endif

#if S_SHADING_MODE == 4
//=========================================================================================================================
// Shader controls : Realistic Shading
//=========================================================================================================================

    float4 ShadingTint < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("Realistic Shading,11/Realistic Shading,10/1"); >;
    float4 ShadingLightSideTint < UiType(Color); Default4(0.843, 0.843, 0.843, 1.0); UiGroup("Realistic Shading,11/Realistic Shading,10/2"); >;
    float ShadingArea < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Realistic Shading,11/Realistic Shading,10/3"); >;

// Only allow self shadowing in other rendering modes except "Transparent".
#if S_ALPHA_MODE != 2
    bool SelfShadowingEnabled < UiType(Checkbox); Default(1); UiGroup("Realistic Shading,11/Realistic Shading,10/4"); >;
    float SelfShadowingIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Realistic Shading,11/Realistic Shading,10/5"); >;
#endif
#endif

#if S_SHADING_MODE != 4
//=========================================================================================================================
// Shader controls : Wrap Shade
//=========================================================================================================================

    // Wrap Shade controls.
    bool WrapShadeEnabled < UiType(Checkbox); Default(0); UiGroup("Wrap Shading,12/Wrap Shade,120/1"); >;
    float WrapShadeIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Wrap Shading,12/Wrap Shade,120/2"); >;
    float4 WrapShadeColor < UiType(Color); Default4(0.34, 0.34, 0.34, 0.34); UiGroup("Wrap Shading,12/Wrap Shade,120/3"); >;
    float4 WrapLightSideColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Wrap Shading,12/Wrap Shade,120/4"); >;
    float WrapShadeArea < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Wrap Shading,12/Wrap Shade,120/5"); >;
    float WrapShadeSoftness < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Wrap Shading,12/Wrap Shade,120/6"); >;
    float WrapShadeFresnel < UiType(Slider); Range(0.01, 10.0); Default1(1.0); UiGroup("Wrap Shading,12/Wrap Shade,120/7"); >;

    // Wrap Shade Masking settings.
    CreateInputTexture2D(WrapShadeMask, Linear, 8, "None", "_wrapshademask", "Wrap Shading,12/Wrap Shade Masking,130/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(WrapShadeMaskTexture)< Channel(R, Box(WrapShadeMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 WrapShadeMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Wrap Shading,12/Wrap Shade Masking,130/2"); >;
    float2 WrapShadeMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Wrap Shading,12/Wrap Shade Masking,130/3"); >;
    float WrapShadeMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Wrap Shading,12/Wrap Shade Masking,130/4"); >;
    bool WrapShadeInvertMask < UiType(Checkbox); Range(0, 1); Default(0); UiGroup("Wrap Shading,12/Wrap Shade Masking,130/5"); >;
    float WrapShadeMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Wrap Shading,12/Wrap Shade Masking,130/6"); >;

    // Wrap Shade settings.
    float WrapNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Wrap Shading,12/Wrap Shade Settings,140/1"); >;
    float WrapEnvironmentStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Wrap Shading,12/Wrap Shade Settings,140/2"); >;

#endif

#if S_SHADING_MODE == 2
//=========================================================================================================================
// Shader controls : Texture Ramp
//=========================================================================================================================

    CreateInputTexture2D(TextureRamp, Srgb, 8, "None", "_ramp", "TextureRamp Shading,10/Texture Ramp,10/1", DefaultFile( "BoBiCo Shader/Textures/Ramps/Default_SR.png" ));
    CreateTexture2D(TextureRampTexture)< Channel(RGBA, Box(TextureRamp), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float RampIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("TextureRamp Shading,10/Texture Ramp,10/2"); >;
    float RampOffset < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("TextureRamp Shading,10/Texture Ramp,10/3"); >;
    float4 RampTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("TextureRamp Shading,10/Texture Ramp,10/4"); >;

#if S_ENABLED_EXTRA_LAYERS
    CreateInputTexture2D(SecondTextureRamp, Srgb, 8, "None", "_2ndramp", "TextureRamp Shading,10/2nd Texture Ramp,20/1", DefaultFile( "BoBiCo Shader/Textures/Ramps/Default_SR.png" ));
    CreateTexture2D(SecondTextureRampTexture)< Channel(RGBA, Box(SecondTextureRamp), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float SecondTextureRampIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("TextureRamp Shading,10/2nd Texture Ramp,20/2"); >;
    float SecondTextureRampOffset < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("TextureRamp Shading,10/2nd Texture Ramp,20/3"); >;
    float4 SecondTextureRampTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("TextureRamp Shading,10/2nd Texture Ramp,20/4"); >;
#endif

    // TextureRamp shadow tint
    float4 ShadowTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("TextureRamp Shading,10/Shadow Tint,30/1"); >;
    float ShadowTintIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("TextureRamp Shading,10/Shadow Tint,30/2"); >;

    int RampUVMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("TextureRamp Shading,10/Ramp Settings,40/1"); >;
    bool RampInvert < UiType(Checkbox); Default(0); UiGroup("TextureRamp Shading,10/Ramp Settings,40/2"); >;
    bool RampVertical < UiType(Checkbox); Default(0); UiGroup("TextureRamp Shading,10/Ramp Settings,40/3"); >;
#endif

#if S_SHADING_MODE == 3
//=========================================================================================================================
// Shader controls : Shademap Shading
//=========================================================================================================================

    // 1st Shademap
    CreateInputTexture2D(Shademap, Srgb, 8, "None", "_1stshademap", "Shademap Shading,11/1st Shademap,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ShademapTexture)< Channel(RGBA, Box(Shademap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 ShademapTint < UiType(Color); Default4(0.7, 0.75, 0.85, 1.0); UiGroup("Shademap Shading,11/1st Shademap,10/2"); >;
    bool UseMainColorAs1stShademap < UiType(Checkbox); Default(0); UiGroup("Shademap Shading,11/1st Shademap,10/3"); >;
    float ShademapIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Shademap Shading,11/1st Shademap,10/4"); >;
    float ShademapArea < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Shademap Shading,11/1st Shademap,10/5"); >;
    float ShademapSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.25); UiGroup("Shademap Shading,11/1st Shademap,10/6"); >;

#if S_ENABLED_EXTRA_LAYERS
    // Second Shademap
    CreateInputTexture2D(SecondShademap, Srgb, 8, "None", "_2ndshademap", "Shademap Shading,11/2nd Shademap,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SecondShademapTexture)< Channel(RGBA, Box(SecondShademap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float4 SecondShademapTint < UiType(Color); Default4(0.55, 0.60, 0.70, 1.0); UiGroup("Shademap Shading,11/2nd Shademap,20/2"); >;
    bool Use1stAsSecondShademap < UiType(Checkbox); Default(0); UiGroup("Shademap Shading,11/2nd Shademap,20/3"); >;
    float SecondShademapIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Shademap Shading,11/2nd Shademap,20/4"); >;
    float SecondShademapArea < UiType(Slider); Range(0.0, 1.0); Default1(0.75); UiGroup("Shademap Shading,11/2nd Shademap,20/5"); >;
    float SecondShademapSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.25); UiGroup("Shademap Shading,11/2nd Shademap,20/6"); >;
#endif

    // Blending settings.
    // Shadow Blend Mode: 0 = Replace, 1 = Multiply
    int ShademapBlendMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Shademap Shading,11/Shademap Settings,30/1"); >;
    int ShademapUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Shademap Shading,11/Shademap Settings,30/2"); >;
    float ShademapContrast < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Shademap Shading,11/Shademap Settings,30/3"); >;
#endif

//=========================================================================================================================
// Shader controls : Emission
//=========================================================================================================================

    // Emission layer settings.
    bool EmissionEnabled < UiType(Checkbox); Default(0); UiGroup("Emission,13/Emission,10/1"); >;
    CreateInputTexture2D(EmissionMap, Srgb, 8, "None", "_emission", "Emission,13/Emission,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/No_eff.png" ));
	CreateTexture2D(EmissionTexture)< Channel(RGBA, Box(EmissionMap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    bool UseEmissionMapAsMaskOnly < UiType(Checkbox); Default(0); UiGroup("Emission,13/Emission,10/3"); >;
    int EmissionMapType < UiType(Slider); Range(1, 2); Default(1); UiGroup("Emission,13/Emission,10/4"); >;
    bool EmissionMapInvert < UiType(Checkbox); Default(0); UiGroup("Emission,13/Emission,10/5"); >;
    float EmissionIntensity < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Emission,13/Emission,10/6"); >;
    float EmissionLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Emission,13/Emission,10/7"); >;
    // Controls how the emission blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int EmissionBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("Emission,13/Emission,10/8"); >;
    float EmissionFluorescence < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Emission,13/Emission,10/10"); >;

    // Blinking settings for the emission layer.
    bool EmissionBlinkingEnabled < UiType(Checkbox); Default(0); UiGroup("Emission,13/Blinking,30/1"); >;
    float EmissionBlinkingStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Emission,13/Blinking,30/2"); >;
    int EmissionBlinkingMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Emission,13/Blinking,30/3"); >;
    float EmissionBlinkingSpeed < UiType(Slider); Range(0.0, 10.0); Default1(1.0); UiGroup("Emission,13/Blinking,30/4"); >;

    // Center Out emission sampling. From Poiyomi.
    bool EmissionCenterOutEnabled < UiType(Checkbox); Default(0); UiGroup("Emission,13/Center Out,35/1"); >;
    float EmissionCenterOutFlowSpeed < UiType(Slider); Range(0.0, 2.0); Default1(0.25); UiGroup("Emission,13/Center Out,35/2"); >;
    bool EmissionCenterOutInvert < UiType(Checkbox); Default(0); UiGroup("Emission,13/Center Out,35/3"); >;

    // UV settings for the emission layer.
    int EmissionUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Emission,13/UV settings,40/1"); >;
    float2 EmissionTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Emission,13/UV settings,40/2"); >;
    float2 EmissionOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Emission,13/UV settings,40/3"); >;
    float EmissionRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Emission,13/UV settings,40/4"); >;

    // UV animation settings for the emission layer.
    float2 EmissionScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("Emission,13/UV animation,50/1"); >;
    float EmissionRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Emission,13/UV animation,50/2"); >;

    // Color adjustments for the emission layer.
    int EmissionHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Emission,13/Color adjustments,60/1"); >;
    int EmissionHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Emission,13/Color adjustments,60/2"); >;
    float EmissionHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Emission,13/Color adjustments,60/3"); >;
    float EmissionHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Emission,13/Color adjustments,60/4"); >;
    float EmissionBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Emission,13/Color adjustments,60/5"); >;
    float EmissionSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Emission,13/Color adjustments,60/6"); >;
    float EmissionGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Emission,13/Color adjustments,60/7"); >;

//=========================================================================================================================
// Shader controls : Second Emission
//=========================================================================================================================

#if S_ENABLED_EXTRA_LAYERS
    // Secondary Emission settings.
    bool SecondEmissionEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/2nd Emission,10/1"); >;
    CreateInputTexture2D(SecondEmissionMap, Srgb, 8, "None", "_2ndemission", "2nd Emission,14/2nd Emission,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/No_eff.png" ));
    CreateTexture2D(SecondEmissionTexture)< Channel(RGBA, Box(SecondEmissionMap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    bool UseSecondEmissionMapAsMaskOnly < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/2nd Emission,10/3"); >;
    int SecondEmissionMapType < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Emission,14/2nd Emission,10/4"); >;
    bool SecondEmissionMapInvert < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/2nd Emission,10/5"); >;
    float SecondEmissionIntensity < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("2nd Emission,14/2nd Emission,10/6"); >;
    float SecondEmissionLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Emission,14/2nd Emission,10/7"); >;
    // Controls how the emission blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int SecondEmissionBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("2nd Emission,14/2nd Emission,10/8"); >;
    float SecondEmissionParallaxStrength < UiType(Slider); Range(-2.0, 2.0); Default1(0.0); UiGroup("2nd Emission,14/2nd Emission,10/9"); >;
    float SecondEmissionFluorescence < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Emission,14/2nd Emission,10/10"); >;

    // Blinking settings for the secondary emission layer.
    bool SecondEmissionBlinkingEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/Blinking,30/1"); >;
    float SecondEmissionBlinkingStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Emission,14/Blinking,30/2"); >;
    int SecondEmissionBlinkingMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("2nd Emission,14/Blinking,30/3"); >;
    float SecondEmissionBlinkingSpeed < UiType(Slider); Range(0.0, 10.0); Default1(1.0); UiGroup("2nd Emission,14/Blinking,30/4"); >;

    // Center Out second emission sampling.
    bool SecondEmissionCenterOutEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/Center Out,35/1"); >;
    float SecondEmissionCenterOutFlowSpeed < UiType(Slider); Range(0.0, 2.0); Default1(0.25); UiGroup("2nd Emission,14/Center Out,35/2"); >;
    bool SecondEmissionCenterOutInvert < UiType(Checkbox); Default(0); UiGroup("2nd Emission,14/Center Out,35/3"); >;

    // UV settings for the secondary emission layer.
    int SecondEmissionUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("2nd Emission,14/UV settings,40/1"); >;
    float2 SecondEmissionTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Emission,14/UV settings,40/2"); >;
    float2 SecondEmissionOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Emission,14/UV settings,40/3"); >;
    float SecondEmissionRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Emission,14/UV settings,40/4"); >;

    // UV animation settings for the secondary emission layer.
    float2 SecondEmissionScroll < UiType(Slider); Range2(-5.0, -5.0, 5.0, 5.0); Default2(0.0, 0.0); UiGroup("2nd Emission,14/UV animation,50/1"); >;
    float SecondEmissionRotate < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("2nd Emission,14/UV animation,50/2"); >;

    // Color adjustments for the secondary emission layer.
    int SecondEmissionHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Emission,14/Color adjustments,60/1"); >;
    int SecondEmissionHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Emission,14/Color adjustments,60/2"); >;
    float SecondEmissionHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Emission,14/Color adjustments,60/3"); >;
    float SecondEmissionHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("2nd Emission,14/Color adjustments,60/4"); >;
    float SecondEmissionBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Emission,14/Color adjustments,60/5"); >;
    float SecondEmissionSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Emission,14/Color adjustments,60/6"); >;
    float SecondEmissionGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Emission,14/Color adjustments,60/7"); >;
#endif

//=========================================================================================================================
// Shader controls : Subsurface Scattering
//=========================================================================================================================

#if S_SHADING_MODE != 5
    // Subsurface Scattering 
    bool SubsurfaceScatteringEnabled < UiType(Checkbox); Default(0); UiGroup("Subsurface Scattering,15/Subsurface Scattering,10/1"); >;
    float4 SubsurfaceScatteringColor < UiType(Color); Default4(1.0, 0.65, 0.55, 1.0); UiGroup("Subsurface Scattering,15/Subsurface Scattering,10/2"); >;
    CreateInputTexture2D(SubsurfaceScatteringMap, Srgb, 8, "None", "_SubsurfaceScattering", "Subsurface Scattering,15/Subsurface Scattering,10/3", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SubsurfaceScatteringTexture)< Channel(RGBA, Box(SubsurfaceScatteringMap), Srgb); OutputFormat(BC7); SrgbRead(true); >;

    float SubsurfaceScatteringIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Subsurface Scattering,15/Subsurface Scattering Settings,10/4"); >;
    float SubsurfaceScatteringEmission < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Subsurface Scattering,15/Subsurface Scattering Settings,10/5"); >;
    float SubsurfaceScatteringThickness < UiType(Slider); Range(0.0, 1.0); Default1(0.35); UiGroup("Subsurface Scattering,15/Subsurface Scattering Settings,10/6"); >;
    float SubsurfaceScatteringSpread < UiType(Slider); Range(0.0, 1.0); Default1(0.45); UiGroup("Subsurface Scattering,15/Subsurface Scattering Settings,10/7"); >;
    float SubsurfaceScatteringMainColorMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Subsurface Scattering,15/Subsurface Scattering Settings,10/9"); >;
#endif

//=========================================================================================================================
// Shader controls : Backlit
//=========================================================================================================================

    // Backlit
    bool BacklitEnabled < UiType(Checkbox); Default(0); UiGroup("Backlit,16/Backlit,10/1"); >;

    // Backlit Masking settings.
    CreateInputTexture2D(BacklitMask, Linear, 8, "None", "_backlitmask", "Backlit,16/Backlit,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(BacklitMaskTexture)< Channel(R, Box(BacklitMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    bool BacklitMaskInvert < UiType(Checkbox); Default(0); UiGroup("Backlit,16/Backlit,10/3"); >;
    float BacklitMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Backlit,16/Backlit,10/4"); >;
    float2 BacklitMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Backlit,16/Backlit,10/5"); >;
    float2 BacklitMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Backlit,16/Backlit,10/6"); >;
    float BacklitMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Backlit,16/Backlit,10/7"); >;

    // Backlit settings.
    float4 BacklitColor < UiType(Color); Default4(0.85, 0.8, 0.7, 1.0); UiGroup("Backlit,16/Backlit Settings,20/1"); >;
    float BacklitIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Backlit,16/Backlit Settings,20/2"); >;
    float BacklitEmission < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Backlit,16/Backlit Settings,20/3"); >;
    float BacklitArea < UiType(Slider); Range(0.0, 1.0); Default1(0.35); UiGroup("Backlit,16/Backlit Settings,20/4"); >;
    float BacklitSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.05); UiGroup("Backlit,16/Backlit Settings,20/5"); >;
    float BacklitDirectivity < UiType(Slider); Range(0.1, 32.0); Default1(8.0); UiGroup("Backlit,16/Backlit Settings,20/6"); >;
    float BacklitViewDirectionStrength < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Backlit,16/Backlit Settings,20/7"); >;
    float BacklitNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Backlit,16/Backlit Settings,20/8"); >;

//=========================================================================================================================
// Shader controls : Rim Lighting
//=========================================================================================================================

    // Rim Lighting
    bool RimLightingEnabled < UiType(Checkbox); Default(0); UiGroup("Rim Lighting,17/Rim Lighting,10/1"); >;
    // Rim Lighting masking settings.
    CreateInputTexture2D(RimLightingMask, Linear, 8, "None", "_rimmask", "Rim Lighting,17/Rim Lighting,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(RimLightingMaskTexture)< Channel(R, Box(RimLightingMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    bool RimLightingInvertMask < UiType(Checkbox); Range(0, 1); Default(0); UiGroup("Rim Lighting,17/Rim Lighting,10/2"); >;
    float RimLightingMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Rim Lighting,17/Rim Lighting,10/3"); >;
    float2 RimLightingMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Rim Lighting,17/Rim Lighting,10/4"); >;
    float2 RimLightingMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Rim Lighting,17/Rim Lighting,10/5"); >;
    float RimLightingMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Lighting,10/6"); >;

    // Rim Lighting Controls
    float4 RimLightingColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/2"); >;
    float RimLightingIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/3"); >;
    float RimLightingEmission < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/4"); >;
    float RimLightingArea < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/5"); >;
    float RimLightingSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.65); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/6"); >;
    float RimLightingFresnelPower < UiType(Slider); Range(0.01, 50.0); Default1(3.5); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/7"); >;
    bool RimLightInvert < UiType(Checkbox); Default(0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/8"); >;

    // Controls how the rim lighting blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int RimLightingBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/9"); >;
    // When enabled, rim lighting avoids transparent areas in Translucent mode.
    bool RimLightingUseAlpha < UiType(CheckBox); Default(0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/10"); >;
    float RimLightingMainColorMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/11"); >;
    float RimLightingNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/12"); >;
    bool RimLightingShadowMask < UiType(Checkbox); Default1(1.0); UiGroup("Rim Lighting,17/Rim Lighting Settings,20/13"); >;

    // Rim light directional settings.
    float RimLightingDirectionalStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/1"); >;
    float RimLightingDirectionalWidth < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/2"); >;
    float4 RimLightingIndirectTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/3"); >;
    float RimLightingIndirectWidth < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/4"); >;
    float RimLightingIndirectArea < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/5"); >;
    float RimLightingIndirectSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Rim Lighting,17/Rim Light Direction Settings,30/6"); >;

//=========================================================================================================================
// Shader controls : Glitter
//=========================================================================================================================

    // Glitter
    bool GlitterEnabled < UiType(Checkbox); Default(0); UiGroup("Glitter,18/Glitter,10/1"); >;

    // Glitter masking settings.
    CreateInputTexture2D(GlitterMask, Linear, 8, "None", "_glittermask", "Glitter,18/Glitter,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(GlitterMaskTexture)< Channel(R, Box(GlitterMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float GlitterMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter,10/3"); >;
    float2 GlitterMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Glitter,18/Glitter,10/4"); >;
    float2 GlitterMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Glitter,18/Glitter,10/5"); >;
    float GlitterMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Glitter,18/Glitter,10/6"); >;

    // Glitter shape Settings.
    int GlitterShape < UiType(Slider); Range(0, 3); Default(0); UiGroup("Glitter,18/Shape Settings,20/1"); >;
    bool GlitterCustomShape < UiType(Checkbox); Default(0); UiGroup("Glitter,18/Shape Settings,20/2"); >;
    CreateInputTexture2D(GlitterShapeTexture, Linear, 8, "None", "_glittershape", "Glitter,18/Shape Settings,20/3", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(GlitterCustomShapeTexture)< Channel(RGBA, Box(GlitterShapeTexture), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float2 GlitterCustomShapeTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Glitter,18/Shape Settings,20/4"); >;
    float2 GlitterCustomShapeOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Glitter,18/Shape Settings,20/5"); >;
    float GlitterCustomShapeRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Glitter,18/Shape Settings,20/6"); >;

    // Glitter effect settings.
    float4 GlitterColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Glitter,18/Glitter Settings,30/1"); >;
    float GlitterIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Settings,30/2"); >;
    int GlitterUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Glitter,18/Glitter Settings,30/3"); >;
    float GlitterLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Settings,30/4"); >;
    float GlitterMainColorMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Settings,30/5"); >;
    float GlitterNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Glitter,18/Glitter Settings,30/6"); >;

    // Glitter settings.
    float GlitterSize < UiType(Slider); Range(0.01, 1.0); Default1(0.4); UiGroup("Glitter,18/Glitter Properties,40/1"); >;
    float GlitterDensity < UiType(Slider); Range(0.0, 2.0); Default1(0.1); UiGroup("Glitter,18/Glitter Properties,40/2"); >;
    float GlitterSensitivity < UiType(Slider); Range(0.0, 5.0); Default1(2.5); UiGroup("Glitter,18/Glitter Properties,40/3"); >;
    float GlitterBlinkSpeed < UiType(Slider); Range(0.0, 2.0); Default1(0.25); UiGroup("Glitter,18/Glitter Properties,40/4"); >;
    float GlitterRandomizeSize < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Properties,40/5"); >;
    float GlitterRandomizeRotation < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Properties,40/6"); >;
    float GlitterRandomizeSpeed < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Properties,40/7"); >;
    float GlitterRandomizeColor < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Glitter Properties,40/8"); >;

    // Glitter color adjustments.
    int GlitterHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Glitter,18/Color Adjustments,50/1"); >;
    int GlitterHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Glitter,18/Color Adjustments,50/2"); >;
    float GlitterHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Glitter,18/Color Adjustments,50/3"); >;
    float GlitterHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Glitter,18/Color Adjustments,50/4"); >;
    float GlitterBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Glitter,18/Color Adjustments,50/5"); >;
    float GlitterSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Glitter,18/Color Adjustments,50/6"); >;
    float GlitterGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Glitter,18/Color Adjustments,50/7"); >;
    float GlitterContrast < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Glitter,18/Color Adjustments,50/7"); >;

//=========================================================================================================================
// Shader controls : Matcap
//=========================================================================================================================

    // Matcap Controls
    bool MatcapEnabled < UiType(Checkbox); Default(0); UiGroup("Matcap,19/Matcap,10/1"); >;
    CreateInputTexture2D(Matcap, Srgb, 8, "None", "_matcap", "Matcap,19/Matcap,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/No_eff.png" ));
    CreateTexture2D(MatCapTexture)< Channel(RGBA, Box(Matcap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float MatcapIntensity < UiType(Slider); Range(0.0,5.0); Default(0.0); UiGroup("Matcap,19/Matcap,10/3"); >;
    float4 MatcapTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Matcap,19/Matcap,10/4"); >;
    float MatcapTintIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Matcap,10/5"); >;

    // Matcap Masking settings.
    CreateInputTexture2D(MatCapMaskTexture, Linear, 8, "None", "_matcapmask", "Matcap,19/Masking,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(MatCapMask)< Channel(R, Box(MatCapMaskTexture), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    bool MatcapInvertMask < UiType(Checkbox); Range(0, 1); Default(0); UiGroup("Matcap,19/Masking,20/2"); >;
    float MatcapMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Matcap,19/Masking,20/3"); >;
    float2 MatcapMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Matcap,19/Masking,20/4"); >;
    float2 MatcapMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Matcap,19/Masking,20/5"); >;
    float MatcapMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Matcap,19/Masking,20/6"); >;

    // Matcap Settings
    float MatcapSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Matcap Settings,30/1"); >;
    float MatcapLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Matcap Settings,30/2"); >;
    float MatcapMainColorMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Matcap Settings,30/3"); >;
    float MatcapNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Matcap Settings,30/4"); >;
    bool MatcapShadowMask < UiType(Checkbox); Default(1); UiGroup("Matcap,19/Matcap Settings,30/5"); >;
    // Controls how the matcap blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int MatcapBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("Matcap,19/Matcap Settings,30/6"); >;

    // Matcap UV settings
    int MatcapUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Matcap,19/UV Settings,40/1"); >;
    float2 MatcapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Matcap,19/UV Settings,40/2"); >;
    float2 MatcapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Matcap,19/UV Settings,40/3"); >;
    float MatcapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Matcap,19/UV Settings,40/4"); >;

    // Matcap color adjustments
    int MatcapHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Matcap,19/Color Adjustments,50/1"); >;
    int MatcapHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Matcap,19/Color Adjustments,50/2"); >;
    float MatcapHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Matcap,19/Color Adjustments,50/3"); >;
    float MatcapHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Matcap,19/Color Adjustments,50/4"); >;
    float MatcapBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Matcap,19/Color Adjustments,50/5"); >;
    float MatcapSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Matcap,19/Color Adjustments,50/6"); >;
    float MatcapGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Matcap,19/Color Adjustments,50/7"); >;

//=========================================================================================================================
// Shader controls : Second Matcap
//=========================================================================================================================

#if S_ENABLED_EXTRA_LAYERS
    // Second Matcap main settings.
    bool SecondMatcapEnabled < UiType(Checkbox); Default(0); UiGroup("2nd Matcap,20/Matcap 2nd,10/1"); >;
    CreateInputTexture2D(SecondMatcap, Srgb, 8, "None", "_2ndmatcap", "2nd Matcap,20/Matcap 2nd,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/No_eff.png" ));
    CreateTexture2D(SecondMatcapTexture)< Channel(RGBA, Box(SecondMatcap), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float SecondMatcapIntensity < UiType(Slider); Range(0.0,5.0); Default(0.0); UiGroup("2nd Matcap,20/Matcap 2nd,10/3"); >;
    float4 SecondMatcapTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("2nd Matcap,20/Matcap 2nd,10/4"); >;
    float SecondMatcapTintIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Matcap 2nd,10/5"); >;

    // Second Matcap masking settings.
    CreateInputTexture2D(SecondMatcapMask, Linear, 8, "None", "_2ndmatcapmask", "2nd Matcap,20/Masking,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(SecondMatcapMaskTexture)< Channel(R, Box(SecondMatcapMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float SecondMatcapMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("2nd Matcap,20/Masking,20/2"); >;
    int SecondMatcapInvertMask < UiType(Slider); Range(0, 1); Default(0); UiGroup("2nd Matcap,20/Masking,20/3"); >;
    float2 SecondMatcapMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Matcap,20/Masking,20/4"); >;
    float2 SecondMatcapMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Matcap,20/Masking,20/5"); >;
    float SecondMatcapMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Matcap,20/Masking,20/6"); >;

    // Second Matcap settings.
    float SecondMatcapSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Matcap Settings,30/1"); >;
    float SecondMatcapLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Matcap Settings,30/2"); >;
    float SecondMatcapMainColorMix < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Matcap Settings,30/3"); >;
    float SecondMatcapNormalMapStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Matcap Settings,30/4"); >;
    bool SecondMatcapShadowMask < UiType(Checkbox); Default(1); UiGroup("2nd Matcap,20/Matcap Settings,30/5"); >;
    // Controls how the second matcap blends with the base color.
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply, 4 = Darken, 5 = Lighten, 6 = Subtract, 7 = Overlay.
    int SecondMatcapBlendMode < UiType(Slider); Range(0, 7); Default(0); UiGroup("2nd Matcap,20/Matcap Settings,30/6"); >;

    // Second Matcap UV settings.
    int SecondMatcapUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("2nd Matcap,20/UV Settings,40/1"); >;
    float2 SecondMatcapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("2nd Matcap,20/UV Settings,40/2"); >;
    float2 SecondMatcapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("2nd Matcap,20/UV Settings,40/3"); >;
    float SecondMatcapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("2nd Matcap,20/UV Settings,40/4"); >;

    // Second Matcap color adjustments.
    int SecondMatcapHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Matcap,20/Color Adjustments,50/1"); >;
    int SecondMatcapHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("2nd Matcap,20/Color Adjustments,50/2"); >;
    float SecondMatcapHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("2nd Matcap,20/Color Adjustments,50/3"); >;
    float SecondMatcapHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("2nd Matcap,20/Color Adjustments,50/4"); >;
    float SecondMatcapBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Matcap,20/Color Adjustments,50/5"); >;
    float SecondMatcapSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Matcap,20/Color Adjustments,50/6"); >;
    float SecondMatcapGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("2nd Matcap,20/Color Adjustments,50/7"); >;
#endif

//=========================================================================================================================
// Shader controls : Physically-Based Rendering
//=========================================================================================================================

// Only allow "Physically-Based Rendering" in every modes except "Fur".
#if S_SHADING_MODE != 5
    // PBR Main settings.
    bool PbrEnabled < UiType(Checkbox); Default(0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/1"); >;
    bool SunSpecular < UiType(Checkbox); Default(1); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/2"); >;
    bool EnvmapReflections < UiType(Checkbox); Default(1); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/3"); >;
    int SpecularMode < UiType(Slider); Range(0, 2); Default(0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/4"); >;
    float PbrNormalStrength < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/5"); >;
    float SpecularGsaa < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/6"); >;
    // Blend Mode mapping: 0 = Add, 1 = Screen, 2 = Replace, 3 = Multiply.
    int SpecularBlendMode < UiType(Slider); Range(0, 3); Default(0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/7"); >;
    float SpecularLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Physically-Based Rendering,21/Physically-Based Rendering,10/8"); >;

    // Packed PBR Map. R = Metallic, G = Smoothness, B = AO, A = Shadow map.
    // But, can be controlled which channel does what with the channel control settings too.
    CreateInputTexture2D(PBRMap, Linear, 8, "None", "_MRAO", "Physically-Based Rendering,21/PBR Map,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(PBRMapTexture)< Channel(RGBA, Box(PBRMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float2 PBRMapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Physically-Based Rendering,21/PBR Map,20/2"); >;
    float2 PBRMapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Physically-Based Rendering,21/PBR Map,20/3"); >;
    float PBRMapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/PBR Map,20/4"); >;

    // PBR Map channel control. Allows users to remap which channel in the mask texture controls which PBR property, for flexibility.
    // Channel mapping: 0 = R, 1 = G, 2 = B, 3 = A.
    int PBRMetallicChannel < UiType(Slider); Range(0, 3); Default(0); UiGroup("Physically-Based Rendering,21/PBR Map Channel Control,30/1"); >;
    int PBRSmoothnessChannel < UiType(Slider); Range(0, 3); Default(1); UiGroup("Physically-Based Rendering,21/PBR Map Channel Control,30/2"); >;
    int PBRAOChannel < UiType(Slider); Range(0, 3); Default(2); UiGroup("Physically-Based Rendering,21/PBR Map Channel Control,30/3"); >;
    int PBRShadowMapChannel < UiType(Slider); Range(0, 3); Default(3); UiGroup("Physically-Based Rendering,21/PBR Map Channel Control,30/4"); >;

    // PBR Settings.
    float Metallic < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/PBR Settings,50/1"); >;
    float Smoothness < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Physically-Based Rendering,21/PBR Settings,50/2"); >;
    float AmbientOcclusion < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/PBR Settings,50/3"); >;
    float DetailShadowing < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/PBR Settings,50/4"); >;
    float FresnelStrength < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Physically-Based Rendering,21/PBR Settings,50/5"); >;
    float4 ReflectionTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Physically-Based Rendering,21/PBR Settings,50/6"); >;
    float4 SpecularTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Physically-Based Rendering,21/PBR Settings,50/7"); >;

// Only show up in "Realistic" shading mode.
#if S_SHADING_MODE == 4
    // Realistic-only AO. (Indirect)
    CreateInputTexture2D(AoMap, Linear, 8, "None", "_aomap", "Physically-Based Rendering,21/Ao Map Settings,80/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(AoMapTexture)< Channel(RGBA, Box(AoMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float AoIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Ao Map Settings,80/2"); >;
    float2 AoMapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Physically-Based Rendering,21/Ao Map Settings,80/3"); >;
    float2 AoMapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Physically-Based Rendering,21/Ao Map Settings,80/4"); >;
    float AoMapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Ao Map Settings,80/5"); >;

    // Multi-channel Ao map, where each channel can be used for different types of ambient occlusion for more control and flexibility. 
    bool UseMultiChannelAo < UiType(Checkbox); Default(0); UiGroup("Physically-Based Rendering,21/Multi Channel Ao,90/1"); >;
    float AoRIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Ao,90/2"); >;
    float AoGIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Ao,90/3"); >;
    float AoBIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Ao,90/4"); >;
    float AoAIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Ao,90/5"); >;

    // Realistic-only Shadow Map. (Direct)
    CreateInputTexture2D(ShadowMap, Linear, 8, "None", "_shadowmap", "Physically-Based Rendering,21/Shadow Map Settings,100/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(ShadowMapTexture)< Channel(RGBA, Box(ShadowMap), Linear); OutputFormat(BC7); SrgbRead(false); >;
    float ShadowMapIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Shadow Map Settings,100/2"); >;
    float2 ShadowMapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Physically-Based Rendering,21/Shadow Map Settings,100/3"); >;
    float2 ShadowMapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Physically-Based Rendering,21/Shadow Map Settings,100/4"); >;
    float ShadowMapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Shadow Map Settings,100/5"); >;

    // Realistic-only shadow map, where each channel can be used for different types of ambient occlusion for more control and flexibility too.
    bool UseMultiChannelShadowMap < UiType(Checkbox); Default(0); UiGroup("Physically-Based Rendering,21/Multi Channel Shadow Map,110/1"); >;
    float ShadowMapRIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Shadow Map,110/2"); >;
    float ShadowMapGIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Shadow Map,110/3"); >;
    float ShadowMapBIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Shadow Map,110/4"); >;
    float ShadowMapAIntensity < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Physically-Based Rendering,21/Multi Channel Shadow Map,110/5"); >;
#endif

    // Toon specular settings
    float ToonSpecularArea < UiType(Slider); Range(0.0, 1.0); Default1(0.5); UiGroup("Physically-Based Rendering,21/Toon Specular Settings,60/1"); >;
    float ToonSpecularSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.25); UiGroup("Physically-Based Rendering,21/Toon Specular Settings,60/2"); >;
#endif

//=========================================================================================================================
// Shader controls : Parallax Occlusion Mapping
//=========================================================================================================================

// POM is Realistic-only and only show up when "Expensive Features" are enabled.
#if S_ENABLE_EXPENSIVE_FEATURES && S_SHADING_MODE == 4
    // Parallax Occlusion
    bool PomEnabled < UiType(Checkbox); Default(0); UiGroup("Parallax Occlusion,22/Heightmap,10/1"); >;
    CreateInputTexture2D(Heightmap, Linear, 8, "None", "_heightmap", "Parallax Occlusion,22/Heightmap,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(HeightmapTexture)< Channel(R, Box(Heightmap), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 HeightmapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Parallax Occlusion,22/Heightmap,10/3"); >;
    float2 HeightmapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Parallax Occlusion,22/Heightmap,10/4"); >;
    float HeightmapRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Parallax Occlusion,22/Heightmap,10/5"); >;

    // POM settings.
    int PomUvMode < UiType(Slider); Range(0, 1); Default(0); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/2"); >;
    float PomHeightStrength < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/3"); >;
    float PomOffset < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/4"); >;
    int PomSteps < UiType(Slider); Range(0, 128); Default(32); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/5"); >;
    int PomSearchSteps < UiType(Slider); Range(1, 16); Default(8); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/6"); >;
    float PomHeightBias < UiType(Slider); Range(-1.0, 1.0); Default1(0.0); UiGroup("Parallax Occlusion,22/Heightmap Settings,20/7"); >;
#endif

//=========================================================================================================================
// Shader controls : Cubemap
//=========================================================================================================================

// Cubemap is available in all non-Fur modes.
#if S_SHADING_MODE != 5
    bool CubemapEnabled < UiType(Checkbox); Default(0); UiGroup("Cubemap,23/Cubemap,10/1"); >;
    CreateInputTextureCube( Cubemap, Srgb, 8, "None", "_cube", "Cubemap,23/Cubemap,10/2", DefaultFile( "BoBiCo Shader/Textures/Cubemaps/FallbackReflection.exr" ));
    TextureCube CubemapTexture < Channel( RGB, Box( Cubemap ), Srgb ); OutputFormat( BC7 ); SrgbRead( true ); >;
    float4 CubemapTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Cubemap,23/Cubemap,10/3"); >;
    bool UseAsPbrFallback < UiType(Checkbox); Default(0); UiGroup("Cubemap,23/Cubemap,10/4"); >;
    bool ForcePbrReflection < UiType(Checkbox); Default(0); UiGroup("Cubemap,23/Cubemap,10/5"); >;

    // Cubemap UV settings.
    int CubemapUvMode < UiType(Slider); Range(0, 1); Default(1); UiGroup("Cubemap,23/Cubemap UV Settings,20/1"); >;
    float3 CubemapRotation < Default3(0.0, 0.0, 0.0); UiGroup("Cubemap,23/Cubemap UV Settings,20/2"); >;
    float3 CubemapOffset < Default3(0.0, 0.0, 0.0); UiGroup("Cubemap,23/Cubemap UV Settings,20/3"); >;
    CreateInputTexture2D(CubemapMask, Linear, 8, "None", "_cubemapmask", "Cubemap,23/Cubemap UV Settings,20/4", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(CubemapMaskTexture)< Channel(R, Box(CubemapMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 CubemapMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Cubemap,23/Cubemap UV Settings,20/5"); >;
    float2 CubemapMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Cubemap,23/Cubemap UV Settings,20/6"); >;
    float CubemapMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Cubemap,23/Cubemap UV Settings,20/7"); >;

    // Cubemap settings.
    float CubemapIntensity < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Cubemap,23/Cubemap Settings,30/1"); >;
    int CubemapBlendMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Cubemap,23/Cubemap Settings,30/2"); >;
    float CubemapSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Cubemap,23/Cubemap Settings,30/3"); >;
    float CubemapLightingMix < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Cubemap,23/Cubemap Settings,30/4"); >;
#endif

//=========================================================================================================================
// Shader controls : SSAO
//=========================================================================================================================

// Only allow SSAO when Expensive features are enabled. We sample the scene SSAO pass when it exists from the scene's post process.
#if S_ENABLE_EXPENSIVE_FEATURES
    bool SSAOEnabled < UiType(Checkbox); Default(0); UiGroup("SSAO,24/SSAO,10/1"); >;
    float SSAOIntensity < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("SSAO,24/SSAO,10/2"); >;
    float SSAOContrast < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("SSAO,24/SSAO,10/3"); >;
    bool SSAONormalMapEnabled < UiType(Checkbox); Default(1); UiGroup("SSAO,24/SSAO,10/4"); >;

    float4 SSAOColor < UiType(Color); Default4(0.0, 0.0, 0.0, 1.0); UiGroup("SSAO,24/SSAO Tint,20/1"); >;
    int SSAOBlendMode < UiType(Slider); Range(0, 2); Default(2); UiGroup("SSAO,24/SSAO Tint,20/2"); >;
#endif

//=========================================================================================================================
// Shader controls : Self Shadow
//=========================================================================================================================

// Only allow self shadowing in other shading modes and rendering modes except "Realistic" and "Transparent".
// Realistic mode uses its own controls in "Realistic Shading" category and "Transparent" don't cast shadows.
#if S_SHADING_MODE != 4 && S_ALPHA_MODE != 2
    bool SelfShadowEnabled < UiType(Checkbox); Default(0); UiGroup("Self Shadow,25/Self Shadow,10/1"); >;
    float SelfShadowIntensity < UiType(Slider); Range(0.01, 1.0); Default1(1.0); UiGroup("Self Shadow,25/Self Shadow,10/2"); >;
#endif

//=========================================================================================================================
// Shader controls : Outlines
//=========================================================================================================================

    // Outline main settings
    CreateInputTexture2D(OutlineColor, Srgb, 8, "None", "_outlinecolor", "Outline,25/Outlines,10/2", DefaultFile( "BoBiCo Shader/Textures/Masks/No_eff.png" ));
    CreateTexture2D(OutlineColorTexture)< Channel(RGBA, Box(OutlineColor), Srgb); OutputFormat(BC7); SrgbRead(true); >;
    float2 OutlineColorTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Outline,25/Outlines,10/3"); >;
    float2 OutlineColorOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Outline,25/Outlines,10/4"); >;
    float OutlineColorRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Outline,25/Outlines,10/5"); >;

    // Outline masking settings.
    CreateInputTexture2D(OutlineMask, Linear, 8, "None", "_outlinemask", "Outline,25/Masking,20/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(OutlineMaskTexture)< Channel(R, Box(OutlineMask), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 OutlineMaskTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Outline,25/Masking,20/2"); >;
    float2 OutlineMaskOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Outline,25/Masking,20/3"); >;
    float OutlineMaskRotation < UiType(Slider); Range(-180.0, 180.0); Default1(0.0); UiGroup("Outline,25/Masking,20/4"); >;
    bool OutlineInvertMask < UiType(Checkbox); Default(0); UiGroup("Outline,25/Masking,20/5"); >;
    float OutlineMaskIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Outline,25/Masking,20/6"); >;

    // Outline settings.
    bool OutlineLightingMix < UiType(Checkbox); Default(1); UiGroup( "Outline,25/Outlines Settings,30/3" ); >;

    // Outline tinting settings.
    float4 OutlineTint < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Outline,25/Tinting,40/1"); >;
    float OutlineTintIntensity < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Outline,25/Tinting,40/2"); >;

    // Outline highlight settings.
    float4 HighlightColor < UiType(Color); Default4(1.0, 1.0, 1.0, 1.0); UiGroup("Outline,25/Highlight,50/1"); >;
    float HighlightIntensity < UiType(Slider); Range(0.0, 1.0); Default1(1.0); UiGroup("Outline,25/Highlight,50/2"); >;

    // Outline color adjustments.
    int OutlineHueColorSpace < UiType(Slider); Range(1, 2); Default(1); UiGroup("Outline,25/Color Adjustments,60/1"); >;
    int OutlineHueMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Outline,25/Color Adjustments,60/2"); >;
    float OutlineHue < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Outline,25/Color Adjustments,60/3"); >;
    float OutlineHueShiftSpeed < UiType(Slider); Range(0.0, 5.0); Default1(0.0); UiGroup("Outline,25/Color Adjustments,60/4"); >;
    float OutlineBrightness < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Outline,25/Color Adjustments,60/5"); >;
    float OutlineSaturation < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Outline,25/Color Adjustments,60/6"); >;
    float OutlineGamma < UiType(Slider); Range(0.0, 2.0); Default1(1.0); UiGroup("Outline,25/Color Adjustments,60/7"); >;

//=========================================================================================================================
// Shader controls : Indirect Lighting
//=========================================================================================================================

    bool IndirectLightingEnabled < UiType(Checkbox); Default(1); UiGroup("Indirect Lighting,26/Indirect Lighting,10/1"); >;
#if S_SHADING_MODE != 4
    int IndirectLightingMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Indirect Lighting,26/Indirect Lighting,10/2"); >;
#endif
    // Blend Mode mapping: 1 = Replace, 2 = Multiply.
    int IndirectBlendMode < UiType(Slider); Range(1, 2); Default(1); UiGroup("Indirect Lighting,26/Indirect Lighting,10/3"); >;
    float IndirectBoost < UiType(Slider); Range(0.0, 2.0); Default1(0.0); UiGroup("Indirect Lighting,26/Indirect Lighting,10/4"); >;
    float IndirectSoftness < UiType(Slider); Range(0.0, 1.0); Default1(0.0); UiGroup("Indirect Lighting,26/Indirect Lighting,10/5"); >;

//=========================================================================================================================
// Shader controls : Depth Settings
//=========================================================================================================================

    // Depth Settings. 
    int ZClip < UiType(Slider); Range(0, 1); Default(1); UiGroup("Depth Settings,27/Depth Settings,10/1"); >;
    int ZWrite < UiType(Slider); Range(0, 1); Default(1); UiGroup("Depth Settings,27/Depth Settings,10/2"); >;
    // s&box uses reverse-Z, So, 6 = GREATER_EQUAL is default. Not LESS_EQUAL.
    // ZTest Mapping : 0 = NEVER, 1 = LESS, 2 = EQUAL, 3 = LESS_EQUAL, 4 = GREATER, 5 = NOT_EQUAL, 6 = GREATER_EQUAL, 7 = ALWAYS
    int ZTest < UiType(Slider); Range(0, 7); Default(6); UiGroup("Depth Settings,27/Depth Settings,10/3"); >;

//=========================================================================================================================
// Shader controls : Debugging
//=========================================================================================================================

    // Debugging settings are authoring-only views for checking BoBiCo's resolved lighting/shading paths.
    // LightingDebugging mapping: 0 = Off, 1 = Direct lighting, 2 = Indirect/bounced lighting, 3 = Light attenuation, 4 = Directional/sun light.
    // Debug views are intended for authoring and should be disabled in shipped materials.
    int LightingDebugging < UiType(Slider); Range(0, 4); Default(0); UiGroup("Debugging,29/Debugging,10/1"); >;
    bool ShadingDebugging < UiType(Checkbox); Default(0); UiGroup("Debugging,29/Debugging,10/2"); >;

//=========================================================================================================================
// Render states controlled by user settings.
//=========================================================================================================================

    RenderState(DepthClipEnable, ZClip > 0);
    RenderState(DepthWriteEnable, ZWrite > 0);
    RenderState(DepthFunc, ZTest);
    #if S_ALPHA_MODE == 1
    #if S_MODE_DEPTH
    RenderState(AlphaTestEnable, true);
    RenderState(AlphaToCoverageEnable, false);
    #else
    RenderState(AlphaTestEnable, A2CEnabled && A2CIntensity > 0.0 ? false : true);
    RenderState(AlphaToCoverageEnable, A2CEnabled && A2CIntensity > 0.0);
    #endif
    #endif
