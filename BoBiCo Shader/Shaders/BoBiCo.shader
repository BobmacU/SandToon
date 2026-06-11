// BoBiCo Shader Credits
// Bobmac - Original shader developer and project lead.
// Zennux - Shader developer, optimizer, and bug fixer.
// Ralph - Shader developer, code cleanup, and geometry-shader feature support.

// Terms of Service
// Licensed under MIT. You may study, use, modify, fork, and include this shader in commercial or non-commercial projects
// as long as the original copyright and license stay included.
// Keep the original copyright notice and license in any copies or substantial parts of the software. 
// This software is provided "as is", without warranty of any kind.
// Thank you for using the shader!

// Contributions
// Feedback, bug reports, and improvements are welcome.

//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
    Description = "BoBiCo Shader";
    Version = 1.0;
}

//=========================================================================================================================
// Features
//=========================================================================================================================
FEATURES
{
    // Features : Rendering Modes, Shading modes and others.
    Feature( F_ALPHA_MODE, 0..2(0="Opaque", 1="Cutoff", 2="Transparent"), "Rendering Modes" );
    Feature( F_SHADING_MODE, 0..5(0="Flat Shading", 1="Multi-layer Shading", 2="TextureRamp Shading", 3="Shademap Shading", 4="Realistic Shading", 5="Fur"), "Shading Modes" );
    Feature( F_ENABLE_EXTRA_LAYERS, 0..1, "Settings" );
    Feature( F_ENABLE_EXPENSIVE_FEATURES, 0..1, "Settings" );
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"
	#define CUSTOM_MATERIAL_INPUTS  // Get rid of any unnecessary input slots.
    #define S_RENDER_BACKFACES 1    // Internal two-sided support for outline shells and shader-side culling.

    // Shared with GS so it can skip outline geometry emission when outlines are off for performance reasons.
    bool OutlineEnabled < UiType(Checkbox); Default(0); UiGroup("Outline,25/Outlines,10/1"); >;

    // Shared outline controls. GS emits the expanded outline shell while PS shades/culls it,
    // so these need to stay in COMMON instead.
	int OutlineMode < UiType( Slider ); Range( 0, 1 ); Default( 0 ); UiGroup( "Outline,25/Outlines Settings,30/1" ); >;
	float OutlineWidth < UiType( Slider ); Range( 0.0, 5.0 ); Default1( 0.1 ); UiGroup( "Outline,25/Outlines Settings,30/2" ); >;
    float OutlineFixWidthByDistance < UiType( Slider ); Range( 0.0, 1.0 ); Default1( 0.0 ); UiGroup( "Outline,25/Outlines Settings,30/4" ); >;
    float OutlineZBias < UiType( Slider ); Range( 0.0, 0.5 ); Default1( 0.0 ); UiGroup( "Outline,25/Outlines Settings,30/5" ); >;
}

//=========================================================================================================================
// Render Modes
// Render modes used by this shader.
// Forward() is the main shading pass.
// Depth() enables shadow casting and the depth prepass.
// ToolsWireframe() and ToolsShadingComplexity() are used by the editor's visualization modes.
//=========================================================================================================================

MODES
{
	Forward();
	Depth();
	ToolsWireframe( "vr_tools_wireframe.shader" );
	ToolsShadingComplexity( "tools_shading_complexity.shader" );
}


//=========================================================================================================================
// Vertex and pixel shader inputs and outputs. 
//=========================================================================================================================
struct VertexInput
{
	#include "common/vertexinput.hlsl"
    uint vertexID : SV_VertexID;
};

struct PixelInput
{
	#include "common/pixelinput.hlsl"
    float furRandomSeed : TEXCOORD8;
    nointerpolation float isOutline : TEXCOORD9;
    float furLengthMask : TEXCOORD10;
    float furLayer : TEXCOORD11;
    float furShell : TEXCOORD12;
};

//=========================================================================================================================
// Vertex Shader : basic vertex processing and passing data to the geometry shader.
//=========================================================================================================================
VS
{
	#include "common/vertex.hlsl"
    StaticCombo(S_SHADING_MODE, F_SHADING_MODE, Sys(ALL));

    // Process the Fur Map in VS instead of GS to avoid per-tris load.
    #if S_SHADING_MODE == 5
    SamplerState g_sFurVertexSampler < Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
    CreateInputTexture2D(FurMap, Linear, 8, "None", "_furlength", "Fur Shading,10/Fur Map,10/1", DefaultFile( "BoBiCo Shader/Textures/Masks/Full_eff.png" ));
    CreateTexture2D(FurMapTexture)< Channel(R, Box(FurMap), Linear); OutputFormat(ATI1N); SrgbRead(false); >;
    float2 FurMapTiling < UiType(Slider); Range2(0.01, 0.01, 20.0, 20.0); Default2(1.0, 1.0); UiGroup("Fur Shading,10/Fur Map,10/2"); >;
    float2 FurMapOffset < UiType(Slider); Range2(-2.0, -2.0, 2.0, 2.0); Default2(0.0, 0.0); UiGroup("Fur Shading,10/Fur Map,10/3"); >;
    #endif

    // Process the vertex as usual, then set up some extra data for fur and outline generation in the geometry shader.
	PixelInput MainVs( VertexInput i )
	{
		PixelInput o = ProcessVertex( i );
        o.isOutline = 0.0;
        o.furRandomSeed = (float)i.vertexID;
        o.furLengthMask = 1.0;
        o.furLayer = -2.0;
        o.furShell = 0.0;
        #if S_SHADING_MODE == 5
        float2 furMapUv = i.vTexCoord.xy * FurMapTiling + FurMapOffset;
        o.furLengthMask = FurMapTexture.SampleLevel(g_sFurVertexSampler, furMapUv, 0).r;
        #endif
		return o;
	}
}

//=========================================================================================================================
// Geometry Shader: emits fur shells and inverted-hull outline geometry.
//=========================================================================================================================
GS
{
    #include "common/vertex.hlsl"
    StaticCombo(S_SHADING_MODE, F_SHADING_MODE, Sys(ALL));
    StaticCombo(S_ALPHA_MODE, F_ALPHA_MODE, Sys(ALL));

    // Include Fur & Outlines GS shaders
    #include "Includes/BoBiCo_GS.hlsl"
}

//=========================================================================================================================
// Pixel Shader: Main shading logic, including all the features and settings defined in the shader.
//=========================================================================================================================
PS
{
    // Static combos for rendering modes and expensive feature groups.
    StaticCombo(S_ALPHA_MODE, F_ALPHA_MODE, Sys(ALL));
    StaticCombo(S_SHADING_MODE, F_SHADING_MODE, Sys(ALL));
    StaticCombo(S_ENABLE_EXPENSIVE_FEATURES, F_ENABLE_EXPENSIVE_FEATURES, Sys(ALL));
    StaticCombo(S_ENABLED_EXTRA_LAYERS, F_ENABLE_EXTRA_LAYERS, Sys(ALL));
    // Keep hardware culling disabled. So, mesh faces and generated outline shells can be handled deliberately in PS.
    RenderState(CullMode, NONE);
    BoolAttribute(renderbackfaces, true);
    RenderState(DepthEnable, true);

    // Render mode handling.
    #if S_MODE_DEPTH
        RenderState(BlendEnable, false);
        #if S_ALPHA_MODE == 1
            RenderState(AlphaTestEnable, true);
        #else
            RenderState(AlphaTestEnable, false);
        #endif
        RenderState(DepthWriteEnable, true);
    #else
        #if S_ALPHA_MODE == 2
            BoolAttribute(translucent, true);
            RenderState(BlendEnable, true);
            RenderState(SrcBlend, SRC_ALPHA);
            RenderState(DstBlend, INV_SRC_ALPHA);
            #if S_SHADING_MODE == 5
                RenderState(AlphaToCoverageEnable, true);
            #endif
            RenderState(DepthWriteEnable, false);
        #elif S_ALPHA_MODE == 1
            RenderState(BlendEnable, false);
            RenderState(AlphaTestEnable, true);
            RenderState(DepthWriteEnable, true);
        #else
            RenderState(BlendEnable, false);
            RenderState(DepthWriteEnable, true);
        #endif
    #endif
	
    // Include shared shader codes
    #include "vr_environment_map.fxc"
    #include "common/pixel.hlsl"
    
    // Include main cores of the shader.
    #include "Includes/BoBiCo_Declarations.hlsl"
    #include "Includes/BoBiCo_Common.hlsl"
    #include "Includes/BoBiCo_Main.hlsl"
}

// BoBiCo Shader 1.0 ends.
// Finished after 2 months.