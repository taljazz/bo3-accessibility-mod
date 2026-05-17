using System.Runtime.InteropServices;

namespace Bo3Access.Audio;

#region Tolk native interop

/// <summary>
/// Thin P/Invoke layer over the bundled native <c>Tolk.dll</c>. Kept
/// internal and isolated so <see cref="TolkSpeechService"/> is the only
/// thing that touches unmanaged speech APIs.
/// </summary>
internal static class TolkNative
{
    private const string DllName = "Tolk.dll";

    #region Lifecycle

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void Tolk_Load();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void Tolk_Unload();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern bool Tolk_IsLoaded();

    /// <summary>Allow Tolk to fall back to SAPI when no screen reader is detected.</summary>
    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void Tolk_TrySAPI(bool useSAPI);

    #endregion

    #region Output

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    internal static extern bool Tolk_Output(string str, bool interrupt);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern bool Tolk_Silence();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern bool Tolk_HasSpeech();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr Tolk_DetectScreenReader();

    #endregion
}

#endregion
