using Bo3Access.Audio;
using Bo3Access.Bridge;
using Bo3Access.Native;

namespace Bo3Access.Launcher;

#region MainForm — construction & lifecycle

/// <summary>
/// Accessible launcher window. Follows the proven CSharp Academy pattern:
/// <see cref="Form.KeyPreview"/>, an accessible status <see cref="Label"/>,
/// and Tolk speech on show. Declared <c>partial</c> — input handling and
/// navigation live in MainForm.Input.cs.
/// </summary>
public sealed partial class MainForm : Form
{
    #region Fields

    private readonly ISpeechService _speech;
    private readonly BridgeHost _bridge;
    private readonly KeyboardHook _hook;
    private readonly Label _status;
    private int _index;
    private bool _announced;

    #endregion

    #region Construction

    public MainForm(ISpeechService speech, BridgeHost bridge)
    {
        _speech = speech;
        _bridge = bridge;

        // Global Shift+F9 → toggle menu OCR. Marshalled onto the UI thread.
        _hook = new KeyboardHook(() => BeginInvoke(_bridge.ToggleOcr));

        Text = "BO3 Zombies Accessibility Launcher";
        Size = new Size(640, 420);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(20, 20, 20);
        KeyPreview = true;

        _status = new Label
        {
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 14f),
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            AutoSize = false,
            Text = "BO3 Zombies Accessibility Launcher",
            AccessibleName = "Launcher status",
            AccessibleRole = AccessibleRole.StaticText,
        };
        Controls.Add(_status);

        KeyDown += OnKeyDown; // implemented in MainForm.Input.cs
        FormClosing += (_, _) => { _hook.Dispose(); _bridge.Stop(); };
    }

    #endregion

    #region Lifecycle

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        if (_announced) return;
        _announced = true;

        _hook.Install();

        string intro =
            "BO3 Zombies Accessibility Launcher. " +
            (_speech.IsScreenReaderActive
                ? "Speech bridge connected. "
                : "Warning: no screen reader detected. ") +
            (GameLauncher.IsModBuilt
                ? "Mod is built and ready. "
                : "Warning: the mod is not built. Run deploy first. ") +
            "Use Up and Down arrows to choose a map, Enter to launch, " +
            "Escape to quit. Shift plus F9 toggles menu reading at any time.";

        _speech.Speak(intro, true);
        AnnounceCurrent();
    }

    private void SetStatus(string text) => _status.Text = text;

    protected override void Dispose(bool disposing)
    {
        if (disposing) { _hook.Dispose(); _status.Dispose(); }
        base.Dispose(disposing);
    }

    #endregion
}

#endregion
