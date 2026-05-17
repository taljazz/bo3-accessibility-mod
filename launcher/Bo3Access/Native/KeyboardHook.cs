using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Bo3Access.Native;

#region Global keyboard hook

/// <summary>
/// Global low-level keyboard hook for one chord (Shift+F9). A low-level
/// hook is required because BO3 — not our window — holds keyboard focus, so
/// ordinary form key handling never sees the keypress. Install from a
/// thread with a message loop (the WinForms UI thread).
/// </summary>
public sealed class KeyboardHook : IDisposable
{
    #region Win32 constants

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int VK_SHIFT = 0x10;
    private const int VK_F9 = 0x78;

    #endregion

    #region P/Invoke

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookExW(int idHook, LowLevelKeyboardProc lpfn,
        IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandleW(string? lpModuleName);

    [DllImport("user32.dll")]
    private static extern short GetKeyState(int nVirtKey);

    #endregion

    #region Fields

    private readonly LowLevelKeyboardProc _proc; // strong ref — must not be GC'd
    private readonly Action _onChord;
    private IntPtr _hook = IntPtr.Zero;

    #endregion

    #region Construction / install

    public KeyboardHook(Action onChord)
    {
        _onChord = onChord;
        _proc = HookProc;
    }

    public void Install()
    {
        using ProcessModule mod = Process.GetCurrentProcess().MainModule!;
        _hook = SetWindowsHookExW(WH_KEYBOARD_LL, _proc,
            GetModuleHandleW(mod.ModuleName), 0);
    }

    #endregion

    #region Hook callback

    private IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN))
        {
            int vk = Marshal.ReadInt32(lParam);
            // High bit of GetKeyState = key currently down.
            if (vk == VK_F9 && (GetKeyState(VK_SHIFT) & 0x8000) != 0)
            {
                try { _onChord(); } catch { }
            }
        }
        return CallNextHookEx(_hook, nCode, wParam, lParam);
    }

    #endregion

    #region IDisposable

    public void Dispose()
    {
        if (_hook != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_hook);
            _hook = IntPtr.Zero;
        }
    }

    #endregion
}

#endregion
