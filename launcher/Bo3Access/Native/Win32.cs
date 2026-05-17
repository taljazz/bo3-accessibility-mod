using System.Runtime.InteropServices;
using System.Text;

namespace Bo3Access.Native;

#region Win32 helpers

/// <summary>Small Win32 utilities used by the bridge.</summary>
internal static class Win32
{
    #region P/Invoke

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int count);

    #endregion

    #region Public helpers

    /// <summary>
    /// True if BO3 is the active foreground window, so we never OCR the
    /// desktop or another app. If the check fails we assume yes rather than
    /// silently disabling menu reading.
    /// </summary>
    public static bool IsBo3Foreground()
    {
        try
        {
            IntPtr hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return false;

            var sb = new StringBuilder(256);
            GetWindowTextW(hwnd, sb, sb.Capacity);
            string title = sb.ToString().ToLowerInvariant();
            return title.Contains("call of duty") || title.Contains("black ops");
        }
        catch
        {
            return true;
        }
    }

    #endregion
}

#endregion
