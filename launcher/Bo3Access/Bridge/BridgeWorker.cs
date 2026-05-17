using Bo3Access.Audio;

namespace Bo3Access.Bridge;

#region Abstract bridge worker

/// <summary>
/// Base class for a long-running background piece of the TTS bridge.
/// Owns the thread lifecycle (create / background / cooperative stop / join)
/// so concrete workers only implement <see cref="Run"/>.
///
/// <see cref="BridgeHost"/> holds a collection of these and drives them
/// polymorphically — it never needs to know whether a worker is the
/// log-tail or the OCR reader.
/// </summary>
public abstract class BridgeWorker
{
    #region Fields

    private Thread? _thread;
    private volatile bool _stop;

    #endregion

    #region Construction

    protected BridgeWorker(string name, ISpeechService speech, BridgeState state)
    {
        Name = name;
        Speech = speech;
        State = state;
    }

    #endregion

    #region Protected surface for subclasses

    /// <summary>Human-readable worker name (also the OS thread name).</summary>
    public string Name { get; }

    protected ISpeechService Speech { get; }
    protected BridgeState State { get; }

    /// <summary>Subclasses loop on <c>while (!StopRequested)</c>.</summary>
    protected bool StopRequested => _stop;

    /// <summary>Sleep that wakes early on stop, so <see cref="Stop"/> stays responsive.</summary>
    protected void Idle(int milliseconds)
    {
        const int slice = 50;
        for (int waited = 0; waited < milliseconds && !_stop; waited += slice)
            Thread.Sleep(Math.Min(slice, milliseconds - waited));
    }

    /// <summary>Override for one-time setup before the thread starts (e.g. init OCR).</summary>
    protected virtual void OnStarting() { }

    /// <summary>The worker body. Must return promptly once <see cref="StopRequested"/> is true.</summary>
    protected abstract void Run();

    /// <summary>How long <see cref="Stop"/> waits for the thread to unwind.</summary>
    protected virtual int JoinTimeoutMs => 1500;

    #endregion

    #region Lifecycle (template methods)

    public void Start()
    {
        if (_thread is not null) return;
        _stop = false;
        OnStarting();
        _thread = new Thread(SafeRun) { IsBackground = true, Name = Name };
        _thread.Start();
    }

    public void Stop()
    {
        _stop = true;
        _thread?.Join(JoinTimeoutMs);
        _thread = null;
    }

    private void SafeRun()
    {
        // A worker dying must never take the process (and the speech bridge)
        // down with it — the user can relaunch the game and we keep tailing.
        try { Run(); }
        catch { /* swallowed by design */ }
    }

    #endregion
}

#endregion
