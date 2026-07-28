using System;
using System.IO;
using UnityEditor;
using UnityEditor.Recorder;
using UnityEditor.Recorder.Encoder;
using UnityEditor.Recorder.Input;
using UnityEngine;

public sealed class GameViewVideoRecorderWindow : EditorWindow
{
    private const string PreferencesPrefix = "Axeria.GameViewVideoRecorder.";
    private const string OutputFolderName = "Recordings";

    private enum ResolutionMode
    {
        GameView,
        Custom
    }

    private enum PlaybackMode
    {
        FixedFrameRate,
        RealtimeVariable
    }

    private ResolutionMode resolutionMode = ResolutionMode.GameView;
    private PlaybackMode playbackMode = PlaybackMode.FixedFrameRate;
    private int customWidth = 1920;
    private int customHeight = 1080;
    private int frameRate = 60;
    private bool captureAudio;

    private RecorderController recorderController;
    private RecorderControllerSettings controllerSettings;
    private MovieRecorderSettings movieSettings;
    private string currentOutputPath;
    private string statusMessage = "Ready.";
    private MessageType statusType = MessageType.Info;

    private static string OutputDirectory =>
        Path.GetFullPath(Path.Combine(Application.dataPath, "..", OutputFolderName));

    private bool IsRecording =>
        recorderController != null && recorderController.IsRecording();

    [MenuItem("Tools/Capture Game View Video")]
    private static void OpenWindow()
    {
        var window = GetWindow<GameViewVideoRecorderWindow>();
        window.titleContent = new GUIContent("Game View Video");
        window.minSize = new Vector2(390f, 330f);
        window.Show();
    }

    private void OnEnable()
    {
        LoadPreferences();
        EditorApplication.playModeStateChanged += OnPlayModeStateChanged;
    }

    private void OnDisable()
    {
        EditorApplication.playModeStateChanged -= OnPlayModeStateChanged;
        SavePreferences();

        if (IsRecording)
        {
            StopRecording("Recording stopped because the recorder window was closed or reloaded.");
        }
        else
        {
            DisposeRecorderObjects();
        }
    }

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Play Mode Game View Recorder", EditorStyles.boldLabel);
        EditorGUILayout.Space(4f);

        EditorGUI.BeginChangeCheck();
        using (new EditorGUI.DisabledScope(IsRecording))
        {
            resolutionMode = (ResolutionMode)EditorGUILayout.EnumPopup(
                new GUIContent("Resolution", "Use the current Game View size or force a custom output size."),
                resolutionMode);

            if (resolutionMode == ResolutionMode.Custom)
            {
                customWidth = EditorGUILayout.IntField("Width", customWidth);
                customHeight = EditorGUILayout.IntField("Height", customHeight);
                EditorGUILayout.HelpBox(
                    "Custom output size can change the active Game View size. After recording, restore it manually from the Game View size dropdown.",
                    MessageType.Warning);
            }

            frameRate = EditorGUILayout.IntField(
                new GUIContent("Frame Rate", "Valid range: 1 to 120 frames per second."),
                frameRate);
            playbackMode = (PlaybackMode)EditorGUILayout.EnumPopup(
                new GUIContent("Playback", "Fixed caps rendering to the selected rate. Realtime keeps variable frame timing."),
                playbackMode);
            captureAudio = EditorGUILayout.Toggle(
                new GUIContent("Capture Audio", "Records Unity's Mono or Stereo audio output into the MP4."),
                captureAudio);
        }

        if (EditorGUI.EndChangeCheck())
        {
            SavePreferences();
        }

        EditorGUILayout.Space(8f);

        if (!EditorApplication.isPlaying)
        {
            EditorGUILayout.HelpBox("Enter Play Mode before starting a recording.", MessageType.Info);
        }

        if (!ValidateSettings(out var validationMessage))
        {
            EditorGUILayout.HelpBox(validationMessage, MessageType.Error);
        }

        EditorGUILayout.HelpBox(statusMessage, statusType);

        if (!string.IsNullOrEmpty(currentOutputPath))
        {
            EditorGUILayout.LabelField("Last Output", EditorStyles.boldLabel);
            EditorGUILayout.SelectableLabel(currentOutputPath, EditorStyles.textField, GUILayout.Height(36f));
        }

        EditorGUILayout.Space(4f);

        if (IsRecording)
        {
            GUI.backgroundColor = new Color(1f, 0.55f, 0.55f);
            if (GUILayout.Button("Stop Recording", GUILayout.Height(32f)))
            {
                StopRecording("Recording stopped by the user.");
            }
        }
        else
        {
            using (new EditorGUI.DisabledScope(!EditorApplication.isPlaying || !ValidateSettings(out _)))
            {
                GUI.backgroundColor = new Color(0.65f, 1f, 0.65f);
                if (GUILayout.Button("Start Recording", GUILayout.Height(32f)))
                {
                    StartRecording();
                }
            }
        }

        GUI.backgroundColor = Color.white;

        if (GUILayout.Button("Open Output Folder"))
        {
            Directory.CreateDirectory(OutputDirectory);
            EditorUtility.RevealInFinder(OutputDirectory);
        }
    }

    private void Update()
    {
        Repaint();
    }

    private void StartRecording()
    {
        if (!EditorApplication.isPlaying)
        {
            ReportError("Video recording can only start in Play Mode.");
            return;
        }

        if (IsRecording)
        {
            ReportError("A Game View video recording is already active.");
            return;
        }

        if (!ValidateSettings(out var validationMessage))
        {
            ReportError(validationMessage);
            return;
        }

        DisposeRecorderObjects();

        try
        {
            Directory.CreateDirectory(OutputDirectory);

            var outputFileWithoutExtension = Path.Combine(
                OutputDirectory,
                $"GameView_{DateTime.Now:yyyyMMdd_HHmmss_fff}");
            currentOutputPath = outputFileWithoutExtension + ".mp4";
            EditorPrefs.SetString(PreferencesPrefix + "LastOutput", currentOutputPath);

            var inputSettings = new GameViewInputSettings();
            if (resolutionMode == ResolutionMode.Custom)
            {
                inputSettings.OutputWidth = customWidth;
                inputSettings.OutputHeight = customHeight;
            }

            if (inputSettings.OutputWidth <= 0 || inputSettings.OutputHeight <= 0)
            {
                throw new InvalidOperationException(
                    $"The selected Game View resolution is invalid: {inputSettings.OutputWidth}x{inputSettings.OutputHeight}.");
            }

            if ((inputSettings.OutputWidth & 1) != 0 || (inputSettings.OutputHeight & 1) != 0)
            {
                throw new InvalidOperationException(
                    $"H.264 MP4 requires an even resolution, but the selected size is {inputSettings.OutputWidth}x{inputSettings.OutputHeight}.");
            }

            movieSettings = ScriptableObject.CreateInstance<MovieRecorderSettings>();
            movieSettings.name = "Axeria Game View Video Recorder";
            movieSettings.Enabled = true;
            movieSettings.EncoderSettings = new CoreEncoderSettings
            {
                Codec = CoreEncoderSettings.OutputCodec.MP4,
                EncodingQuality = CoreEncoderSettings.VideoEncodingQuality.High
            };
            movieSettings.CaptureAlpha = false;
            movieSettings.CaptureAudio = captureAudio;
            movieSettings.ImageInputSettings = inputSettings;
            movieSettings.OutputFile = outputFileWithoutExtension.Replace('\\', '/');

            controllerSettings = ScriptableObject.CreateInstance<RecorderControllerSettings>();
            controllerSettings.SetRecordModeToManual();
            controllerSettings.FrameRate = frameRate;
            controllerSettings.FrameRatePlayback = playbackMode == PlaybackMode.FixedFrameRate
                ? FrameRatePlayback.Constant
                : FrameRatePlayback.Variable;
            controllerSettings.CapFrameRate = playbackMode == PlaybackMode.FixedFrameRate;
            controllerSettings.ExitPlayMode = false;
            controllerSettings.AddRecorderSettings(movieSettings);

            recorderController = new RecorderController(controllerSettings);
            recorderController.PrepareRecording();

            if (!recorderController.StartRecording())
            {
                throw new InvalidOperationException(
                    "Unity Recorder could not start. Check the Console for Recorder validation errors.");
            }

            statusMessage = $"Recording {inputSettings.OutputWidth}x{inputSettings.OutputHeight} at {frameRate} fps.";
            statusType = MessageType.Info;
            Debug.Log($"Game View video recording started: {currentOutputPath}");
        }
        catch (Exception exception)
        {
            try
            {
                recorderController?.StopRecording();
            }
            catch (Exception stopException)
            {
                Debug.LogException(stopException);
            }

            DisposeRecorderObjects();
            ReportError($"Could not start Game View video recording: {exception.Message}");
            Debug.LogException(exception);
        }
    }

    private void StopRecording(string reason)
    {
        var wasRecording = IsRecording;
        var outputPath = currentOutputPath;

        try
        {
            if (wasRecording)
            {
                recorderController.StopRecording();
            }
        }
        catch (Exception exception)
        {
            ReportError($"Could not stop Game View video recording cleanly: {exception.Message}");
            Debug.LogException(exception);
        }
        finally
        {
            DisposeRecorderObjects();
        }

        if (!wasRecording)
        {
            return;
        }

        statusMessage = $"{reason}\nSaved to: {outputPath}";
        statusType = MessageType.Info;

        EditorApplication.delayCall += () => VerifyOutputFile(outputPath);
    }

    private void DisposeRecorderObjects()
    {
        recorderController = null;

        if (movieSettings != null)
        {
            DestroyImmediate(movieSettings);
            movieSettings = null;
        }

        if (controllerSettings != null)
        {
            DestroyImmediate(controllerSettings);
            controllerSettings = null;
        }
    }

    private void OnPlayModeStateChanged(PlayModeStateChange state)
    {
        if (state == PlayModeStateChange.ExitingPlayMode && IsRecording)
        {
            StopRecording("Recording stopped because Play Mode exited.");
        }
    }

    private bool ValidateSettings(out string message)
    {
        if (frameRate < 1 || frameRate > 120)
        {
            message = "Frame Rate must be between 1 and 120.";
            return false;
        }

        if (resolutionMode == ResolutionMode.Custom)
        {
            if (customWidth <= 0 || customHeight <= 0)
            {
                message = "Custom width and height must be greater than zero.";
                return false;
            }

            if ((customWidth & 1) != 0 || (customHeight & 1) != 0)
            {
                message = "H.264 MP4 requires even custom width and height values.";
                return false;
            }
        }

        message = null;
        return true;
    }

    private void ReportError(string message)
    {
        statusMessage = message;
        statusType = MessageType.Error;
        Debug.LogError(message);
    }

    private void LoadPreferences()
    {
        resolutionMode = (ResolutionMode)EditorPrefs.GetInt(
            PreferencesPrefix + "ResolutionMode",
            (int)ResolutionMode.GameView);
        playbackMode = (PlaybackMode)EditorPrefs.GetInt(
            PreferencesPrefix + "PlaybackMode",
            (int)PlaybackMode.FixedFrameRate);
        customWidth = EditorPrefs.GetInt(PreferencesPrefix + "CustomWidth", 1920);
        customHeight = EditorPrefs.GetInt(PreferencesPrefix + "CustomHeight", 1080);
        frameRate = EditorPrefs.GetInt(PreferencesPrefix + "FrameRate", 60);
        captureAudio = EditorPrefs.GetBool(PreferencesPrefix + "CaptureAudio", false);
        currentOutputPath = EditorPrefs.GetString(PreferencesPrefix + "LastOutput", string.Empty);
    }

    private void SavePreferences()
    {
        EditorPrefs.SetInt(PreferencesPrefix + "ResolutionMode", (int)resolutionMode);
        EditorPrefs.SetInt(PreferencesPrefix + "PlaybackMode", (int)playbackMode);
        EditorPrefs.SetInt(PreferencesPrefix + "CustomWidth", customWidth);
        EditorPrefs.SetInt(PreferencesPrefix + "CustomHeight", customHeight);
        EditorPrefs.SetInt(PreferencesPrefix + "FrameRate", frameRate);
        EditorPrefs.SetBool(PreferencesPrefix + "CaptureAudio", captureAudio);
    }

    private void VerifyOutputFile(string outputPath)
    {
        if (string.IsNullOrEmpty(outputPath))
        {
            return;
        }

        if (File.Exists(outputPath))
        {
            var size = new FileInfo(outputPath).Length;
            statusMessage = $"Recording saved ({size:N0} bytes):\n{outputPath}";
            statusType = MessageType.Info;
            Debug.Log($"Game View video recording saved: {outputPath} ({size:N0} bytes)");
        }
        else
        {
            statusMessage = $"Recorder stopped, but the output file was not found:\n{outputPath}";
            statusType = MessageType.Warning;
            Debug.LogWarning(statusMessage);
        }

        Repaint();
    }
}
