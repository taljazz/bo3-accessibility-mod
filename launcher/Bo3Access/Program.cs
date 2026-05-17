using Bo3Access.Audio;
using Bo3Access.Bridge;
using Bo3Access.Launcher;

namespace Bo3Access;

#region Entry point

/// <summary>
/// Composition root. Wires the speech back-end and the background bridge,
/// then runs the accessible launcher window. One process is both the
/// launcher and the TTS bridge (replaces the old .bat + Python scripts).
/// </summary>
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();

        // ISpeechService is abstract over the back-end; TolkSpeechService is
        // the concrete one. Swapping engines would not touch the bridge/UI.
        ISpeechService speech = new TolkSpeechService();

        var bridge = new BridgeHost(speech);
        bridge.Start();

        try
        {
            Application.Run(new MainForm(speech, bridge));
        }
        finally
        {
            bridge.Dispose();
            (speech as IDisposable)?.Dispose();
        }
    }
}

#endregion
