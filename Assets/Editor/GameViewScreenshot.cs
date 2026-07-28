using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class GameViewScreenshot
{
    private const string ScreenshotFolderName = "Screenshots";

    [MenuItem("Tools/Capture Game View Screenshot %#g")]
    private static void Capture()
    {
        string projectRoot = Directory.GetParent(Application.dataPath).FullName;
        string screenshotDirectory = Path.Combine(projectRoot, ScreenshotFolderName);
        Directory.CreateDirectory(screenshotDirectory);

        string fileName = $"GameView_{DateTime.Now:yyyyMMdd_HHmmss_fff}.png";
        string outputPath = Path.Combine(screenshotDirectory, fileName);

        ScreenCapture.CaptureScreenshot(outputPath);
        Debug.Log($"Game View screenshot exported to: {outputPath}");
    }
}
