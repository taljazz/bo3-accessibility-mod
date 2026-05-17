namespace Bo3Access.Audio;

#region Abstract speech base

/// <summary>
/// Base class for every speech back-end. Implements the cross-cutting
/// concerns once — input validation, thread-safety, and disposal — and
/// defers the actual engine calls to subclasses via the template methods
/// <see cref="SpeakCore"/> / <see cref="SilenceCore"/>.
///
/// The launcher UI thread, the gameplay log-tail thread, and the OCR thread
/// all call <see cref="Speak"/> concurrently, so serialization lives here
/// rather than being re-implemented in each subclass.
/// </summary>
public abstract class SpeechServiceBase : ISpeechService, IDisposable
{
    #region Fields

    private readonly object _gate = new();
    private bool _disposed;

    #endregion

    #region ISpeechService (template methods)

    /// <inheritdoc/>
    public bool IsScreenReaderActive => ScreenReaderActive;

    /// <inheritdoc/>
    public void Speak(string text, bool interrupt = false)
    {
        // Common guard clauses handled once for all back-ends.
        if (string.IsNullOrWhiteSpace(text)) return;

        lock (_gate)
        {
            if (_disposed) return;
            try { SpeakCore(text, interrupt); }
            catch { /* a flaky screen reader must never crash the bridge */ }
        }
    }

    /// <inheritdoc/>
    public void Silence()
    {
        lock (_gate)
        {
            if (_disposed) return;
            try { SilenceCore(); }
            catch { }
        }
    }

    #endregion

    #region Subclass contract (polymorphic hooks)

    /// <summary>True when this back-end can actually speak.</summary>
    protected abstract bool ScreenReaderActive { get; }

    /// <summary>Engine-specific speech. Always called under the lock.</summary>
    protected abstract void SpeakCore(string text, bool interrupt);

    /// <summary>Engine-specific silence. Always called under the lock.</summary>
    protected abstract void SilenceCore();

    /// <summary>Engine-specific teardown. Called once, under the lock.</summary>
    protected virtual void DisposeCore() { }

    #endregion

    #region IDisposable

    public void Dispose()
    {
        lock (_gate)
        {
            if (_disposed) return;
            _disposed = true;
            try { DisposeCore(); }
            catch { }
        }
        GC.SuppressFinalize(this);
    }

    #endregion
}

#endregion
