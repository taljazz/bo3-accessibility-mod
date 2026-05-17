namespace Bo3Access.Audio;

#region Tolk speech back-end

/// <summary>
/// Concrete <see cref="SpeechServiceBase"/> that speaks through Tolk
/// (NVDA / JAWS / SAPI fallback). Only the engine-specific calls are
/// overridden; locking, validation and disposal come from the base class.
/// This is the same Tolk pattern proven in CSharp Academy.
/// </summary>
public sealed class TolkSpeechService : SpeechServiceBase
{
    #region Fields

    private readonly bool _active;

    #endregion

    #region Construction

    public TolkSpeechService()
    {
        try
        {
            // Prefer a real screen reader; fall back to SAPI if none is running.
            TolkNative.Tolk_TrySAPI(true);
            TolkNative.Tolk_Load();
            _active = TolkNative.Tolk_IsLoaded() && TolkNative.Tolk_HasSpeech();
        }
        catch
        {
            _active = false;
        }
    }

    #endregion

    #region SpeechServiceBase overrides (polymorphism)

    protected override bool ScreenReaderActive => _active;

    protected override void SpeakCore(string text, bool interrupt)
    {
        if (_active)
            TolkNative.Tolk_Output(text, interrupt);
        else
            Console.WriteLine(text); // headless fallback (no screen reader present)
    }

    protected override void SilenceCore()
    {
        if (_active) TolkNative.Tolk_Silence();
    }

    protected override void DisposeCore()
    {
        if (_active) TolkNative.Tolk_Unload();
    }

    #endregion
}

#endregion
