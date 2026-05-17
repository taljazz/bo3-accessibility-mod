using System.Drawing;
using Bo3Access.Audio;
using Bo3Access.Native;
using Windows.Media.Ocr;

namespace Bo3Access.Bridge;

#region Menu OCR worker (orchestration half)

/// <summary>
/// Reads BO3 menus aloud: captures the screen, finds the orange highlight
/// bar, OCRs it with <c>Windows.Media.Ocr</c>, and speaks it. Concrete
/// <see cref="BridgeWorker"/> — replaces menu_ocr_bridge.py.
///
/// This class is <c>partial</c>: orchestration (the worker loop, speech
/// throttling, OCR engine call) lives here; the pixel-level imaging
/// (capture, perceptual hash, highlight detection, preprocessing) lives in
/// <see cref="MenuOcrService"/> .Imaging.cs.
///
/// BO3 must run in <b>Borderless Windowed</b> for GDI capture to work.
/// </summary>
public sealed partial class MenuOcrService : BridgeWorker
{
    #region Fields

    private OcrEngine? _engine;
    private volatile bool _active = true;

    // Change-detection + de-duplication state.
    private ulong _lastHash;
    private bool _haveHash;
    private string _lastHeader = "";
    private readonly Dictionary<string, DateTime> _spoken = new();
    private DateTime _lastSpeakUtc = DateTime.MinValue;

    #endregion

    #region Tunables

    private static readonly TimeSpan Cooldown = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan DuplicateWindow = TimeSpan.FromSeconds(10);
    private const int DHashThreshold = 3;        // <= this: treat as same screen
    private const int HeaderChangeThreshold = 12; // >= this: big change → re-read page header

    #endregion

    #region Construction

    public MenuOcrService(ISpeechService speech, BridgeState state)
        : base("ocr-reader", speech, state) { }

    /// <summary>Shift+F9 handler (wired through <see cref="BridgeHost"/>).</summary>
    public void Toggle()
    {
        _active = !_active;
        Speech.Speak(_active ? "Menu reading on" : "Menu reading off", true);
    }

    #endregion

    #region Startup (OCR engine init)

    protected override void OnStarting()
    {
        try { _engine = OcrEngine.TryCreateFromUserProfileLanguages(); }
        catch { _engine = null; }

        if (_engine is null)
            Speech.Speak("Menu reading unavailable: no Windows OCR language pack.", false);
    }

    #endregion

    #region Worker loop

    protected override void Run()
    {
        if (_engine is null) return; // nothing to do without an OCR engine

        Idle(1000);
        while (!StopRequested)
        {
            Idle(500);

            // ── Gate checks (cheap, no GPU work) ──
            if (!_active) continue;
            if (!Win32.IsBo3Foreground()) { Idle(1000); continue; }
            if (State.Mode != BridgeMode.Menu)
            {
                // Startup or active gameplay → stay silent.
                Idle(1000);
                continue;
            }

            using Bitmap? frame = Capture();
            if (frame is null) continue;

            // ── Has the menu region actually changed? ──
            int regionW = (int)(frame.Width * 0.55);
            using (Bitmap probe = Crop(frame, 0, 0, regionW, frame.Height))
            {
                ulong hash = DHash(probe);
                int dist = _haveHash ? Hamming(hash, _lastHash) : 99;
                if (_haveHash && dist <= DHashThreshold) continue;

                Idle(150); // let scroll/transition settle, then read a fresh frame
                using Bitmap? fresh = Capture();
                Bitmap shot = fresh ?? frame;

                using (Bitmap probe2 = Crop(shot, 0, 0, (int)(shot.Width * 0.55), shot.Height))
                    _lastHash = DHash(probe2);
                _haveHash = true;

                Announce(BuildSpeech(shot, dist));
            }
        }
    }

    #endregion

    #region Speech assembly + throttling

    /// <summary>Read the relevant regions in order and join them for one utterance.</summary>
    private string BuildSpeech(Bitmap frame, int changeDistance)
    {
        var parts = new List<string>();

        // Page header only on a big change (a new page, not a highlight move).
        if (changeDistance >= HeaderChangeThreshold)
        {
            string header = ReadRegion(frame, OcrRegionKind.Header);
            if (header.Length > 0 && header != _lastHeader)
            {
                _lastHeader = header;
                parts.Add(header);
            }
        }

        // The selected item, or a center fallback on big changes.
        using Bitmap? highlight = FindHighlightStrip(frame);
        if (highlight is not null)
        {
            string t = Clean(ReadOcr(Preprocess(highlight)));
            if (t.Length > 0) parts.Add(t);
        }
        else if (changeDistance >= HeaderChangeThreshold)
        {
            string t = ReadRegion(frame, OcrRegionKind.Center, maxLines: 5);
            if (t.Length > 0) parts.Add(t);
        }

        return string.Join(". ", parts);
    }

    /// <summary>Crop + OCR a fixed region kind (Header/Center). Highlight is handled separately.</summary>
    private string ReadRegion(Bitmap frame, OcrRegionKind kind, int maxLines = 0)
    {
        using Bitmap crop = kind switch
        {
            OcrRegionKind.Header => ExtractHeader(frame),
            OcrRegionKind.Center => ExtractCenter(frame),
            _ => throw new ArgumentOutOfRangeException(nameof(kind)),
        };
        return Clean(ReadOcr(Preprocess(crop)), maxLines);
    }

    private void Announce(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return;
        DateTime now = DateTime.UtcNow;

        if (_spoken.TryGetValue(text, out DateTime ts) && now - ts < DuplicateWindow) return;
        if (now - _lastSpeakUtc < Cooldown) return;

        Speech.Speak(text, true);
        _lastSpeakUtc = now;
        _spoken[text] = now;

        // Prune stale dedup entries so the dictionary can't grow unbounded.
        foreach (string k in _spoken
                     .Where(kv => now - kv.Value > DuplicateWindow + DuplicateWindow)
                     .Select(kv => kv.Key).ToList())
            _spoken.Remove(k);
    }

    #endregion
}

#endregion
