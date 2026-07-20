# BoBiCo Shader

<img width="1542" height="760" alt="showcase" src="https://github.com/user-attachments/assets/496f01fb-a4cc-42e7-a019-efccaea2a60f" />
</p>

<p align="center">
  <strong>Flat Shading • Toon Shading • Realistic Shading • PBR • Ambient Lighting • Light Probes & DDGI • Advanced Masking • And much more!</strong>
</p>

<p align="center">
  <a href="https://github.com/BoBiCo-Lab/BoBiCo-Shaders/releases/latest">📦 <strong>Latest Release</strong></a>
  •
  <a href="https://bobico-shader-docs.vercel.app/">📘 <strong>Documentation</strong></a>
  •
  <a href="https://sbox.game/bobicolab/bobicoshader">🟦 <strong>S&box Workshop</strong></a>
  •
  <a href="https://discord.gg/4NaJHNVTDa">💬 <strong>Discord</strong></a>
</p>

---

## 📖 Introduction

**BoBiCo Shader** is a feature-rich shader for the **S&box** game engine, inspired by popular shaders such as **LilToon** and **Poiyomi** while introducing its own optimized and flexible rendering systems.

Designed to be both easy to use and highly customizable, it supports a wide range of artistic styles, from stylized toon rendering to realistic PBR workflows, all while keeping performance in mind.

---

## ✨ Feature Highlights

- Multiple Shading Styles : BoBiCo Shader comes with **six built-in shading modes**: **Flat**, **Multilayer**, **Texture Ramp**, **Shade Map**, **Realistic**, and **Fur**.
Every shading mode also supports **Wrap Shading**, allowing you to easily achieve different lighting styles without switching to another shader.

- 🪟 Flexible Rendering Modes : Supports **Opaque**, **Cutout**, and **Transparent** rendering pipelines, alongside advanced transparency techniques such as **Dither Alpha**, **Alpha-to-Coverage**, and **Fresnel Alpha**.
The shader intelligently reuses existing alpha channels whenever possible, reducing the need for dedicated masking textures.

- 💡 Full Lighting Support : Designed to integrate seamlessly with the S&box lighting pipeline, supporting **Direct Lighting**, **Indirect Lighting**, **Light Probes**, and **DDGI**. Lighting transitions adapt naturally to the environment while preserving the intended visual style.

- 🎛️ Extensive Material Customization : Build highly customizable materials using **dual main color layers**, built-in **decal tools**, **normal maps**, **emission**, **matcaps**, and a large collection of color adjustment controls.
Whether you're creating stylized or realistic materials, the shader provides plenty of flexibility without becoming difficult to use.

- ✨ Stylized Effects : Enhance your visuals with built-in features including **MatCaps**, **Inverted Hull Outlines**, **Glitter Effects**, and several additional NPR-oriented rendering options.

- ⚙️ Physically Based Rendering : Every shading mode except **Fur** supports a complete **PBR workflow**, including advanced material parameters and flexible multi-channel controls for fine-tuning surface appearance.

- 🚀 Advanced Features : BoBiCo Shader also includes support for **Screen Space Ambient Occlusion (SSAO)**, **Parallax Occlusion Mapping**, **Self Shadowing**, **Subsurface Scattering**, **Fur Rendering**, and many other advanced rendering techniques.

## 📄 License

This project is licensed under the **MIT License**.

You are free to:

* Use the shader in personal or commercial projects
* Modify and extend the source code
* Fork and redistribute the project

The only requirement is that the original copyright notice and license are included in any copies or substantial portions of the software.

The software is provided **"as is"**, without warranty of any kind.

> Additional resources and important files for developers interested in building their own shaders on top of BoBiCo Shader will be released in the future.

## 🤝 Contributing

Contributions are always welcome.

If you'd like to improve the shader by fixing bugs or adding meaningful new features, feel free to submit a pull request.

When reporting issues, please include:

* A clear description of the problem
* Steps to reproduce
* Screenshots or videos when possible
* Relevant logs or additional information

Providing detailed reports makes troubleshooting significantly easier and helps improve the project faster.

---
