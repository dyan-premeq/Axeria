using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public sealed class LividiWaterShaderGUI : ShaderGUI
{
    private const string SessionKeyPrefix = "LividiWaterShaderGUI.";
    private const string SurfaceFoldoutKey = SessionKeyPrefix + "Surface";
    private const string UncategorizedFoldoutKey = SessionKeyPrefix + "Uncategorized";
    private const string AdvancedFoldoutKey = SessionKeyPrefix + "Advanced";

    private static readonly GUIContent SurfaceHeader = new GUIContent("基础水面");
    private static readonly GUIContent UncategorizedHeader = new GUIContent("其他 / 未分类属性");
    private static readonly GUIContent AdvancedHeader = new GUIContent("高级设置");

    // Adding a feature section should only require one entry here. Properties are
    // discovered in Shader declaration order through their naming prefixes.
    private static readonly SectionDefinition[] FeatureSections =
    {
        new SectionDefinition(
            "SurfaceNormal",
            "水面法线",
            true,
            null,
            null,
            "_WaterSurfaceNormal",
            "_WaterNormal"),
        new SectionDefinition(
            "WaterSpecular",
            "风格化高光",
            true,
            null,
            null,
            "_WaterSpecular"),
        new SectionDefinition(
            "SurfaceDistortion",
            "表面扰动",
            true,
            null,
            null,
            "_SurfaceDistortion"),
        new SectionDefinition(
            "SurfaceFoam",
            "表面白沫",
            false,
            "_UseSurfaceFoam",
            "启用表面白沫",
            "_SurfaceFoam",
            "_SurfFoam",
            "_Enable_SurfaceFoam"),
        new SectionDefinition(
            "IntersectionFoam",
            "相交白沫",
            true,
            "_UseIntersecFoam",
            "启用相交白沫",
            "_Intersec",
            "_InterSec",
            "_Enable_Intersection"),
        new SectionDefinition(
            "ShorelineFoam",
            "海岸白沫",
            false,
            "_UseShoreLineFoam",
            "启用海岸白沫",
            "_Shore",
            "_SL_",
            "_ENABLESHORELINE",
            "_UseShorelineFoam")
    };

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var drawnProperties = new HashSet<string>(StringComparer.Ordinal);

        DrawSurfaceSection(materialEditor, properties, drawnProperties);

        foreach (SectionDefinition section in FeatureSections)
        {
            if (DrawFeatureSection(materialEditor, properties, drawnProperties, section))
            {
                EditorGUILayout.Space(4.0f);
            }
        }

        if (DrawUncategorizedSection(materialEditor, properties, drawnProperties))
        {
            EditorGUILayout.Space(4.0f);
        }

        DrawAdvancedSection(materialEditor);
    }

    private void DrawSurfaceSection(
        MaterialEditor materialEditor,
        MaterialProperty[] properties,
        ISet<string> drawnProperties)
    {
        bool expanded = DrawFoldout(SurfaceFoldoutKey, SurfaceHeader, true);
        if (expanded)
        {
            EditorGUI.indentLevel++;

            DrawProperty(materialEditor, properties, drawnProperties, "_Color_Shallow", "浅水颜色");
            DrawProperty(materialEditor, properties, drawnProperties, "_Color_Deep", "深水颜色");
            DrawProperty(materialEditor, properties, drawnProperties, "_DepthFadeDistance", "水深渐变范围");
            DrawProperty(materialEditor, properties, drawnProperties, "_WorldSpaceDepth", "使用世界空间水深");
            DrawProperty(materialEditor, properties, drawnProperties, "_FoamFade", "泡沫淡出");

            MaterialProperty usePlanetCenterUp = DrawProperty(
                materialEditor,
                properties,
                drawnProperties,
                "_UsePlanetCenterUp",
                "使用 Planet Center Up");

            MaterialProperty planetCenter = FindProperty("_PlanetCenter", properties, false);
            if (planetCenter != null)
            {
                drawnProperties.Add(planetCenter.name);

                bool showPlanetCenter = usePlanetCenterUp == null
                    || usePlanetCenterUp.hasMixedValue
                    || usePlanetCenterUp.floatValue > 0.5f;

                if (showPlanetCenter)
                {
                    EditorGUI.indentLevel++;
                    materialEditor.ShaderProperty(planetCenter, new GUIContent("行星中心"));
                    EditorGUI.indentLevel--;
                }
            }

            EditorGUI.indentLevel--;
        }
        else
        {
            MarkPropertyAsDrawn(properties, drawnProperties, "_Color_Shallow");
            MarkPropertyAsDrawn(properties, drawnProperties, "_Color_Deep");
            MarkPropertyAsDrawn(properties, drawnProperties, "_DepthFadeDistance");
            MarkPropertyAsDrawn(properties, drawnProperties, "_WorldSpaceDepth");
            MarkPropertyAsDrawn(properties, drawnProperties, "_FoamFade");
            MarkPropertyAsDrawn(properties, drawnProperties, "_UsePlanetCenterUp");
            MarkPropertyAsDrawn(properties, drawnProperties, "_PlanetCenter");
        }

        EditorGUILayout.Space(4.0f);
    }

    private bool DrawFeatureSection(
        MaterialEditor materialEditor,
        MaterialProperty[] properties,
        ISet<string> drawnProperties,
        SectionDefinition section)
    {
        if (!HasMatchingProperty(properties, section))
        {
            return false;
        }

        bool expanded = DrawFoldout(section.FoldoutKey, section.Header, section.DefaultExpanded);
        MaterialProperty toggle = string.IsNullOrEmpty(section.TogglePropertyName)
            ? null
            : FindProperty(section.TogglePropertyName, properties, false);

        if (expanded)
        {
            EditorGUI.indentLevel++;

            if (toggle != null)
            {
                materialEditor.ShaderProperty(toggle, new GUIContent(section.ToggleLabel));
                drawnProperties.Add(toggle.name);
            }

            bool showSettings = toggle == null
                || toggle.hasMixedValue
                || toggle.floatValue > 0.5f;
            bool indentSettings = showSettings && toggle != null;

            if (indentSettings)
            {
                EditorGUI.indentLevel++;
            }

            foreach (MaterialProperty property in properties)
            {
                if (!section.Matches(property.name))
                {
                    continue;
                }

                drawnProperties.Add(property.name);
                if (property == toggle || !showSettings)
                {
                    continue;
                }

                DrawAutomaticProperty(materialEditor, property);
            }

            if (indentSettings)
            {
                EditorGUI.indentLevel--;
            }

            EditorGUI.indentLevel--;
        }
        else
        {
            MarkSectionPropertiesAsDrawn(properties, drawnProperties, section);
        }

        return true;
    }

    private bool DrawUncategorizedSection(
        MaterialEditor materialEditor,
        MaterialProperty[] properties,
        ISet<string> drawnProperties)
    {
        bool hasUncategorizedProperties = false;
        foreach (MaterialProperty property in properties)
        {
            if (!drawnProperties.Contains(property.name))
            {
                hasUncategorizedProperties = true;
                break;
            }
        }

        if (!hasUncategorizedProperties)
        {
            return false;
        }

        bool expanded = DrawFoldout(UncategorizedFoldoutKey, UncategorizedHeader, true);
        if (expanded)
        {
            EditorGUILayout.HelpBox(
                "这些属性尚未登记到专属分组，但仍会自动显示。添加新功能时可在 FeatureSections 中配置标题、开关和属性前缀。",
                MessageType.Info);
            EditorGUI.indentLevel++;
        }

        foreach (MaterialProperty property in properties)
        {
            if (drawnProperties.Contains(property.name))
            {
                continue;
            }

            drawnProperties.Add(property.name);
            if (expanded)
            {
                DrawAutomaticProperty(materialEditor, property);
            }
        }

        if (expanded)
        {
            EditorGUI.indentLevel--;
        }

        return true;
    }

    private static void DrawAutomaticProperty(
        MaterialEditor materialEditor,
        MaterialProperty property)
    {
        if (ShouldDrawAsVector2(property))
        {
            DrawVector2Property(materialEditor, property, property.displayName);
            return;
        }

        materialEditor.ShaderProperty(property, property.displayName);
    }

    private static bool ShouldDrawAsVector2(MaterialProperty property)
    {
        if (property.type != MaterialProperty.PropType.Vector)
        {
            return false;
        }

        return property.name.EndsWith("Pan", StringComparison.Ordinal)
            || property.name.EndsWith("Tiling", StringComparison.Ordinal);
    }

    private MaterialProperty DrawProperty(
        MaterialEditor materialEditor,
        MaterialProperty[] properties,
        ISet<string> drawnProperties,
        string propertyName,
        string label)
    {
        MaterialProperty property = FindProperty(propertyName, properties, false);
        if (property == null)
        {
            return null;
        }

        materialEditor.ShaderProperty(property, new GUIContent(label));
        drawnProperties.Add(property.name);
        return property;
    }

    private static void DrawVector2Property(
        MaterialEditor materialEditor,
        MaterialProperty property,
        string label)
    {
        Vector4 value = property.vectorValue;

        EditorGUI.showMixedValue = property.hasMixedValue;
        EditorGUI.BeginChangeCheck();
        Vector2 nextValue = EditorGUILayout.Vector2Field(
            new GUIContent(label),
            new Vector2(value.x, value.y));

        if (EditorGUI.EndChangeCheck())
        {
            materialEditor.RegisterPropertyChangeUndo(label);
            property.vectorValue = new Vector4(
                nextValue.x,
                nextValue.y,
                value.z,
                value.w);
        }

        EditorGUI.showMixedValue = false;
    }

    private void MarkPropertyAsDrawn(
        MaterialProperty[] properties,
        ISet<string> drawnProperties,
        string propertyName)
    {
        MaterialProperty property = FindProperty(propertyName, properties, false);
        if (property != null)
        {
            drawnProperties.Add(property.name);
        }
    }

    private static void MarkSectionPropertiesAsDrawn(
        MaterialProperty[] properties,
        ISet<string> drawnProperties,
        SectionDefinition section)
    {
        foreach (MaterialProperty property in properties)
        {
            if (section.Matches(property.name))
            {
                drawnProperties.Add(property.name);
            }
        }
    }

    private static bool HasMatchingProperty(
        MaterialProperty[] properties,
        SectionDefinition section)
    {
        foreach (MaterialProperty property in properties)
        {
            if (section.Matches(property.name))
            {
                return true;
            }
        }

        return false;
    }

    private static void DrawAdvancedSection(MaterialEditor materialEditor)
    {
        bool expanded = DrawFoldout(AdvancedFoldoutKey, AdvancedHeader, false);
        if (!expanded)
        {
            return;
        }

        EditorGUI.indentLevel++;
        materialEditor.EnableInstancingField();
        materialEditor.RenderQueueField();
        EditorGUI.indentLevel--;
    }

    private static bool DrawFoldout(string key, GUIContent title, bool defaultValue)
    {
        bool expanded = SessionState.GetBool(key, defaultValue);
        bool nextExpanded = EditorGUILayout.Foldout(
            expanded,
            title,
            true,
            EditorStyles.foldoutHeader);

        if (nextExpanded != expanded)
        {
            SessionState.SetBool(key, nextExpanded);
        }

        return nextExpanded;
    }

    private sealed class SectionDefinition
    {
        private readonly string[] propertyPrefixes;

        public SectionDefinition(
            string keySuffix,
            string header,
            bool defaultExpanded,
            string togglePropertyName,
            string toggleLabel,
            params string[] propertyPrefixes)
        {
            FoldoutKey = SessionKeyPrefix + keySuffix;
            Header = new GUIContent(header);
            DefaultExpanded = defaultExpanded;
            TogglePropertyName = togglePropertyName;
            ToggleLabel = toggleLabel;
            this.propertyPrefixes = propertyPrefixes ?? Array.Empty<string>();
        }

        public string FoldoutKey { get; }
        public GUIContent Header { get; }
        public bool DefaultExpanded { get; }
        public string TogglePropertyName { get; }
        public string ToggleLabel { get; }

        public bool Matches(string propertyName)
        {
            if (!string.IsNullOrEmpty(TogglePropertyName)
                && string.Equals(propertyName, TogglePropertyName, StringComparison.Ordinal))
            {
                return true;
            }

            foreach (string prefix in propertyPrefixes)
            {
                if (propertyName.StartsWith(prefix, StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }
    }
}
