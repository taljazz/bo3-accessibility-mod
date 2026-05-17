namespace Bo3Access.Audio;

#region Speech contract

/// <summary>
/// Abstraction over a screen-reader / speech back-end. Implemented by the
/// <see cref="SpeechServiceBase"/> hierarchy so the launcher and the bridge
/// workers can speak without knowing which engine is behind it.
/// </summary>
public interface ISpeechService
{
    /// <summary>Speak <paramref name="text"/>. When <paramref name="interrupt"/>
    /// is true, any in-progress speech is cut off first.</summary>
    void Speak(string text, bool interrupt = false);

    /// <summary>Immediately stop any speech in progress.</summary>
    void Silence();

    /// <summary>True when a real screen reader (or SAPI fallback) is driving output.</summary>
    bool IsScreenReaderActive { get; }
}

#endregion
