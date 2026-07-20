# LividiWaterShader 工作约定

## 适用范围

本文件只约束 `Assets/DevCindy/LividiWaterShader/` 及其子目录。这个目录维护 Lividi 的 URP 风格化水体 Shader、材质 Inspector、模板资源和演示场景。

## 支持边界

- 目标环境是 Unity `2022.3.62f3c1`、URP `14.0.12`。Unity位于 `"C:\Program Files\Unity 2022.3.62f3c1\Editor\Unity.exe"`
- 只维护常规非 XR 渲染路径。**Lividi 不计划实现 VR/XR compatibility。**
- `Demo/`、项目 Package 或序列化的 Renderer/RP Asset 中即使出现 VR/XR 选项，也不代表 Lividi 的功能承诺。
- 不要主动加入或维护 stereo instancing、single-pass instanced、multiview、双眼纹理/矩阵、XR 专用屏幕 UV 等兼容代码，也不要为此增加 Shader variant 或测试矩阵。
- GPU Instancing 是普通渲染能力，不等同于 XR；现有 `#pragma multi_compile_instancing` 和实例 ID 处理可以继续维护。
- 不要因为 Lividi 不支持 XR 而删除项目级 XR Package、修改全局 Project Settings，或清理 Demo 资源中的相关序列化字段；这些内容不归本目录的兼容性边界管理。
- 如果任务明确要求 Lividi 支持 VR/XR，应先指出它与本约定冲突，等待范围决策，不要自行实现。

## 当前优先级

- 当前项目优先优化常规平面水面，包括画面质量、性能、稳定性、材质可控性和透明渲染行为。
- 当前项目同等重视架构一致性。空间、表面、深度、光照与前向流程之间应保持清晰职责，优先消除重复计算、未使用接口和仅为假设需求建立的抽象。
- 行星模式是低优先级扩展方向。保留 `_UsePlanetCenterUp`、`_PlanetCenter`、radial-up 等现有接口和明确的扩展边界，但不要让尚未完成的行星需求主导当前平面水面的数据结构或实现复杂度。
- 除非任务明确涉及行星水面，不要主动实现 Triplanar、球面 UV、行星法线映射、行星岸线或额外的行星专用 Shader variant 与测试矩阵。
- 通用架构应允许未来接入行星模式，但不要求提前完成其实现。若可扩展性与当前平面路径的清晰度、性能或可维护性冲突，优先保证平面路径，并留下小而明确的扩展点。

## 目录职责

- `Shader/LividiWaterShader.shader`：ShaderLab 入口，定义材质属性、透明水体 Pass、编译指令和 CustomEditor。
- `Shader/Includes/WaterInput.hlsl`：材质常量、纹理声明以及顶点/片元接口。
- `Shader/Includes/WaterForwardPass.hlsl`：前向顶点与片元主流程。
- `Shader/Includes/WaterDepth.hlsl`：场景深度重建、浅水因子和岸边深度逻辑。
- `Shader/Includes/WaterCommon.hlsl`、`WaterSurface.hlsl`、`WaterLighting.hlsl`：共享数学、表面与光照逻辑；新增通用逻辑优先放到职责对应的 include 中。
- `Editor/LividiWaterShaderGUI.cs`：材质 Inspector，只包含编辑器代码，必须保持在 `Editor/` 下。
- `Template Materials/` 与 `Prefabs/`：可交付的模板资源。Shader 属性变更必须考虑这些资源的兼容性。
- `Demo/`：演示和人工验收内容，不是产品支持范围的来源。除非任务明确涉及 Demo，不要顺手修改场景、LightingData、RP Asset 或演示材质。
- `C:\Users\litho\Downloads\Uber-Stylized-Water-main\Assets\Shaders`：Uber shader 为 本项目的直接学习来源，该 shader 由 shader graph 编写。如果用户要求提供有关 Uber shader 的信息，从这个目录中读取并分析提供。
  - 本项目另一个直接学习来源为 https://ameye.dev/notes/stylized-water-shader/ （后以 Ameye 代指）

## 修改规则

- 保持 Shader 属性、`UnityPerMaterial` CBUFFER 字段、HLSL 使用点和 `LividiWaterShaderGUI` 展示逻辑一致。新增或删除属性时同时检查这四处。
- 保持 SRP Batcher 兼容：逐材质标量与向量放在 `UnityPerMaterial` CBUFFER；纹理和采样器单独声明。
- 不随意重命名已有 Shader 名、属性名或 Pass 名。属性名会被现有 `.mat`、Prefab 和场景序列化引用；确需重命名时必须提供迁移方案。
- 屏幕深度逻辑必须继续正确处理 reversed-Z、无有效场景深度和世界坐标重建。依赖深度纹理的功能要明确 URP Renderer/Camera 必须提供深度纹理。
- `_WorldSpaceDepth`、`_UsePlanetCenterUp` 与 `_PlanetCenter` 属于项目已有的空间约定。修改通用空间接口时保留其清晰的扩展边界，但不要借此主动扩展行星功能。修改深度方向或 radial-up 计算时，优先验证平面水体的 object-up 路径；只有改动实际涉及行星分支时，才要求验证球形世界的 radial-up 路径。
- 不无意改变透明渲染状态：当前为 Transparent Queue、`ZWrite Off`、`Cull Back` 和 alpha blend。改变 Queue、Blend、ZTest、ZWrite、Cull 或 LightMode 属于行为变更，应说明理由并检查排序、深度和阴影影响。
- 现有功能开关主要是材质数值分支，不要未经测量改成 Shader keyword；新增 keyword 时要评估 variant 数量。
- Inspector 对缺失属性应继续容错，以便 Shader 开发期间不因属性暂缺而抛异常。界面分组与实际属性前缀/名称保持同步。
- 不手工改写 `.png`、`.psd`、`.fbx`、`.exr`、`LightingData.asset` 等生成或二进制资源。不要进行与任务无关的批量重导入或序列化刷新。

## 验证要求

- 修改 Shader/HLSL 后，至少确认 Unity 无 Shader 编译错误，并检查目标 URP Renderer 下材质能够正常显示。
- 根据改动优先覆盖平面水面的浅水/深水颜色、世界空间与相机空间深度、交界泡沫、透明排序和 GPU Instancing 相关路径。只有任务或改动直接涉及 `_UsePlanetCenterUp`、`_PlanetCenter` 或 radial-up 计算时，才把 Planet Center Up 纳入必需验证范围。
- 修改深度采样时，用有前景交界物、无有效场景深度以及 reversed-Z 目标进行检查。
- 修改材质属性或 Inspector 后，打开一个模板材质，确认属性值未丢失、多选编辑与 Undo 可用、折叠区显示正确。
- 只对受影响的模板/Prefab/Demo 做人工冒烟测试；不要把 Demo 中偶然启用的设置提升为产品要求。

- 不需要进行 VR/XR 编译、双眼画面或 XR 设备测试；相关失败不属于 Lividi 的兼容性缺陷。

## 交付说明

说明修改影响的渲染路径、材质属性兼容性以及实际完成的 Unity/URP 验证。若无法启动 Unity，应明确列出尚未执行的编辑器或画面验证，不要声称已通过。
