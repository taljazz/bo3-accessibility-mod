using Bo3Access.Audio;

namespace Bo3Access.Bridge;

#region Gameplay log-tail worker

/// <summary>
/// Tails the BO3 console log for <c>ACC_TTS:</c> lines (written by the GSC
/// mod via <c>IPrintLn</c>) and speaks them. Concrete <see cref="BridgeWorker"/>
/// — replaces nvda_bridge.py.
/// </summary>
public sealed class LogTailService : BridgeWorker
{
    #region Constants

    private const string Bo3Dir =
        @"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III";
    private const string Prefix = "ACC_TTS:";

    private static readonly string[] LogPaths =
    {
        Path.Combine(Bo3Dir, "console_mp.log"),
        Path.Combine(Bo3Dir, "mods", "zm_accessibility", "console_mp.log"),
        Path.Combine(Bo3Dir, "console_zm.log"),
    };

    #endregion

    #region Construction

    public LogTailService(ISpeechService speech, BridgeState state)
        : base("log-tail", speech, state) { }

    #endregion

    #region Log discovery

    private static string? FindLog()
    {
        foreach (var p in LogPaths)
            if (File.Exists(p)) return p;

        try
        {
            var matches = Directory.GetFiles(Bo3Dir, "console*.log");
            if (matches.Length > 0)
                return matches.OrderByDescending(File.GetLastWriteTimeUtc).First();
        }
        catch { /* directory may not exist until the game runs */ }

        return null;
    }

    #endregion

    #region Worker body

    protected override void Run()
    {
        // The game may not be running yet — wait for a log to appear.
        string? path = null;
        while (!StopRequested && path is null)
        {
            path = FindLog();
            if (path is null) Idle(2000);
        }
        if (StopRequested || path is null) return;

        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        using var reader = new StreamReader(fs);

        fs.Seek(0, SeekOrigin.End); // only read lines written from now on
        long lastPos = fs.Position;

        while (!StopRequested)
        {
            string? line = reader.ReadLine();

            if (line is null)
            {
                Idle(50);
                TryHandleRotation(fs, reader, path, ref lastPos);
                continue;
            }

            lastPos = fs.Position;

            int idx = line.IndexOf(Prefix, StringComparison.Ordinal);
            if (idx < 0) continue;

            string msg = line[(idx + Prefix.Length)..].Trim();
            if (msg.Length == 0) continue;

            // Gameplay is live: record it (suppresses OCR) and speak at once.
            State.MarkGameplay();
            Speech.Speak(msg, interrupt: true);
        }
    }

    /// <summary>Re-seek if the game truncated/rotated the log under us.</summary>
    private static void TryHandleRotation(FileStream fs, StreamReader reader,
                                          string path, ref long lastPos)
    {
        try
        {
            if (new FileInfo(path).Length < lastPos)
            {
                fs.Seek(0, SeekOrigin.Begin);
                reader.DiscardBufferedData();
                lastPos = 0;
            }
        }
        catch { /* transient IO while the game writes */ }
    }

    #endregion
}

#endregion
