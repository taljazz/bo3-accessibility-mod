using Bo3Access.Audio;

namespace Bo3Access.Bridge;

#region Bridge host

/// <summary>
/// Owns the background TTS bridge. Holds its workers as a polymorphic
/// collection of <see cref="BridgeWorker"/> and starts/stops them without
/// caring which concrete worker each one is. One process replaces both
/// nvda_bridge.py and menu_ocr_bridge.py.
/// </summary>
public sealed class BridgeHost : IDisposable
{
    #region Fields

    private readonly BridgeState _state = new();
    private readonly IReadOnlyList<BridgeWorker> _workers;
    private readonly MenuOcrService _ocr; // kept typed for the Shift+F9 toggle
    private bool _started;

    #endregion

    #region Construction

    public BridgeHost(ISpeechService speech)
    {
        _ocr = new MenuOcrService(speech, _state);

        // Polymorphic worker list — add future workers here and Start/Stop
        // pick them up automatically.
        _workers = new BridgeWorker[]
        {
            new LogTailService(speech, _state),
            _ocr,
        };
    }

    #endregion

    #region Lifecycle

    public void Start()
    {
        if (_started) return;
        _started = true;
        foreach (BridgeWorker w in _workers) w.Start();
    }

    public void Stop()
    {
        if (!_started) return;
        _started = false;
        foreach (BridgeWorker w in _workers) w.Stop();
    }

    public void Dispose() => Stop();

    #endregion

    #region Hotkey

    /// <summary>Shift+F9 → toggle menu OCR on/off.</summary>
    public void ToggleOcr() => _ocr.Toggle();

    #endregion
}

#endregion
