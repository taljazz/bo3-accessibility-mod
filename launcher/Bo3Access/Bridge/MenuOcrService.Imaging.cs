using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Graphics.Imaging;

namespace Bo3Access.Bridge;

#region Menu OCR worker (imaging half)

/// <summary>
/// Pixel-level half of <see cref="MenuOcrService"/>: screen capture,
/// perceptual hashing, the BO3 orange-highlight-bar detector, OCR
/// preprocessing and the WinRT OCR call. Split out as a <c>partial</c>
/// so the orchestration file stays readable.
/// </summary>
public sealed partial class MenuOcrService
{
    #region Screen capture (GDI — requires Borderless Windowed)

    private static Bitmap? Capture()
    {
        try
        {
            Rectangle b = Screen.PrimaryScreen!.Bounds;
            var bmp = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
            using Graphics g = Graphics.FromImage(bmp);
            g.CopyFromScreen(b.Location, Point.Empty, b.Size);
            return bmp;
        }
        catch
        {
            return null; // exclusive-fullscreen or capture blocked
        }
    }

    private static Bitmap Crop(Bitmap src, int x, int y, int w, int h)
    {
        x = Math.Clamp(x, 0, src.Width - 1);
        y = Math.Clamp(y, 0, src.Height - 1);
        w = Math.Clamp(w, 1, src.Width - x);
        h = Math.Clamp(h, 1, src.Height - y);
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using Graphics g = Graphics.FromImage(dst);
        g.DrawImage(src, new Rectangle(0, 0, w, h),
                         new Rectangle(x, y, w, h), GraphicsUnit.Pixel);
        return dst;
    }

    #endregion

    #region Perceptual hash (8x8 dhash) — "did the screen change?"

    private static ulong DHash(Bitmap img)
    {
        using var small = new Bitmap(9, 8, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(small))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBilinear;
            g.DrawImage(img, 0, 0, 9, 8);
        }

        ulong hash = 0;
        int bit = 0;
        for (int y = 0; y < 8; y++)
            for (int x = 0; x < 8; x++)
            {
                // Each bit: is the next pixel brighter than this one?
                if (Luminance(small.GetPixel(x + 1, y)) > Luminance(small.GetPixel(x, y)))
                    hash |= 1UL << bit;
                bit++;
            }
        return hash;

        static double Luminance(Color c) => 0.299 * c.R + 0.587 * c.G + 0.114 * c.B;
    }

    private static int Hamming(ulong a, ulong b) =>
        System.Numerics.BitOperations.PopCount(a ^ b);

    #endregion

    #region BO3 orange highlight-bar detector

    /// <summary>
    /// BO3 menus draw a solid, very-saturated orange bar behind the selected
    /// item. We scan the left half for rows dense in that exact orange and
    /// return a tight crop around the strongest band, or null if none.
    /// Thresholds are tuned for ~1080p (ported from menu_ocr_bridge.py) and
    /// may need by-ear adjustment at other resolutions.
    /// </summary>
    private static Bitmap? FindHighlightStrip(Bitmap frame)
    {
        int w = frame.Width, h = frame.Height;
        int yStart = (int)(h * 0.10), yEnd = (int)(h * 0.96);
        int regionW = (int)(w * 0.5), regionH = yEnd - yStart;
        if (regionH < 10 || regionW < 10) return null;

        var rowScores = new double[regionH];

        BitmapData data = frame.LockBits(
            new Rectangle(0, yStart, regionW, regionH),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            unsafe
            {
                byte* basePtr = (byte*)data.Scan0;
                for (int ry = 0; ry < regionH; ry++)
                {
                    byte* row = basePtr + ry * data.Stride;
                    int count = 0;
                    for (int rx = 0; rx < regionW; rx++)
                    {
                        // 32bpp ARGB in memory is B,G,R,A.
                        byte bch = row[rx * 4 + 0];
                        byte gch = row[rx * 4 + 1];
                        byte rch = row[rx * 4 + 2];
                        ToHsv255(rch, gch, bch, out int hue, out int sat, out int val);
                        if (hue >= 8 && hue <= 42 && sat >= 150 && val >= 100) count++;
                    }
                    rowScores[ry] = count;
                }
            }
        }
        finally { frame.UnlockBits(data); }

        double minOrange = regionW * 0.08;
        double peak = rowScores.Max();
        if (peak < minOrange) return null;

        // Tallest contiguous run of rows that are at least half the peak.
        double thr = peak * 0.5;
        int bestStart = -1, bestEnd = -1, bestLen = 0, runStart = -1;
        for (int i = 0; i < regionH; i++)
        {
            if (rowScores[i] >= thr)
            {
                if (runStart == -1) runStart = i;
            }
            else if (runStart != -1)
            {
                int len = i - runStart;
                if (len > bestLen) { bestLen = len; bestStart = runStart; bestEnd = i; }
                runStart = -1;
            }
        }
        if (runStart != -1 && regionH - runStart > bestLen)
        {
            bestLen = regionH - runStart; bestStart = runStart; bestEnd = regionH;
        }

        // Reject bars that are too thin (icon borders) or too tall (glow bleed).
        if (bestLen < 20 || bestLen > 55) return null;

        int dense = 0;
        for (int i = bestStart; i < bestEnd; i++)
            if (rowScores[i] >= minOrange) dense++;
        if ((double)dense / bestLen < 0.5) return null;

        int peakRow = bestStart;
        double peakVal = rowScores[bestStart];
        for (int i = bestStart; i < bestEnd; i++)
            if (rowScores[i] > peakVal) { peakVal = rowScores[i]; peakRow = i; }

        int halfCrop = (int)(h * 0.032);
        int top = Math.Max(yStart, yStart + peakRow - halfCrop);
        int bottom = Math.Min(h, yStart + peakRow + halfCrop);
        return Crop(frame, 15, top, (int)(w * 0.4) - 15, bottom - top);
    }

    #endregion

    #region Fixed-region crops

    private static Bitmap ExtractHeader(Bitmap f) =>
        Crop(f, 0, (int)(f.Height * 0.01), (int)(f.Width * 0.55), (int)(f.Height * 0.11));

    private static Bitmap ExtractCenter(Bitmap f) =>
        Crop(f, (int)(f.Width * 0.02), (int)(f.Height * 0.12),
                (int)(f.Width * 0.68), (int)(f.Height * 0.78));

    #endregion

    #region OCR preprocessing (isolate bright text)

    /// <summary>
    /// BO3 menu text is white/bright on orange bars or dark backgrounds.
    /// Thresholding on the minimum RGB channel keeps only white text:
    /// orange (low B) and dark (low everything) both fall out. Small crops
    /// are upscaled because the OCR engine needs a minimum glyph size.
    /// </summary>
    private static Bitmap Preprocess(Bitmap src)
    {
        var bin = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);

        BitmapData s = src.LockBits(new Rectangle(0, 0, src.Width, src.Height),
            ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData d = bin.LockBits(new Rectangle(0, 0, bin.Width, bin.Height),
            ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        try
        {
            unsafe
            {
                for (int y = 0; y < src.Height; y++)
                {
                    byte* sr = (byte*)s.Scan0 + y * s.Stride;
                    byte* dr = (byte*)d.Scan0 + y * d.Stride;
                    for (int x = 0; x < src.Width; x++)
                    {
                        int min = Math.Min(sr[x * 4], Math.Min(sr[x * 4 + 1], sr[x * 4 + 2]));
                        byte v = (byte)(min > 130 ? 255 : 0);
                        dr[x * 4] = v; dr[x * 4 + 1] = v; dr[x * 4 + 2] = v; dr[x * 4 + 3] = 255;
                    }
                }
            }
        }
        finally { src.UnlockBits(s); bin.UnlockBits(d); }

        if (bin.Height < 50)
        {
            double scale = Math.Min(2.5, Math.Max(2.0, 50.0 / bin.Height));
            var up = new Bitmap(bin, (int)(bin.Width * scale), (int)(bin.Height * scale));
            bin.Dispose();
            return up;
        }
        return bin;
    }

    #endregion

    #region Windows.Media.Ocr call

    /// <summary>Run WinRT OCR on a bitmap (disposes it) and return raw text.</summary>
    private string ReadOcr(Bitmap bmp)
    {
        if (_engine is null) { bmp.Dispose(); return ""; }
        try
        {
            using (bmp)
            {
                int w = bmp.Width, h = bmp.Height;
                BitmapData bd = bmp.LockBits(new Rectangle(0, 0, w, h),
                    ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                byte[] buffer = new byte[bd.Stride * h];
                System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buffer, 0, buffer.Length);
                bmp.UnlockBits(bd);

                // 32bpp ARGB (managed) == BGRA8 bytes for WinRT.
                using SoftwareBitmap sb = SoftwareBitmap.CreateCopyFromBuffer(
                    buffer.AsBuffer(), BitmapPixelFormat.Bgra8, w, h);

                var result = _engine.RecognizeAsync(sb)
                                    .AsTask().GetAwaiter().GetResult();
                return result.Text?.Trim() ?? "";
            }
        }
        catch
        {
            return "";
        }
    }

    #endregion

    #region Text cleanup

    private static readonly char[] NoiseTrim =
        ".,;:!?\"'`-_/\\|@#$%^&*()[]{}~<> ".ToCharArray();

    private static readonly string[] SkipContains =
        { "call of duty", "taljazz", "ship -", "- ship", "black ops" };

    /// <summary>Filter OCR noise: drop tiny/numeric/timestamp/window-chrome lines.</summary>
    private static string Clean(string raw, int maxLines = 0)
    {
        if (string.IsNullOrEmpty(raw)) return "";

        var keep = new List<string>();
        foreach (string rawLine in raw.Split('\n'))
        {
            string line = rawLine.Trim().Trim(NoiseTrim);
            if (line.Length < 3) continue;

            string stripped = line.Replace(" ", "").Replace(".", "").Replace(",", "");
            if (!stripped.Any(char.IsLetter)) continue;                  // pure numbers/symbols
            if (line.Contains("AM ") || line.Contains("PM ") || line.Contains("/202")) continue; // clock
            string lower = line.ToLowerInvariant();
            if (SkipContains.Any(lower.Contains)) continue;              // title bar / username

            keep.Add(line);
            if (maxLines > 0 && keep.Count >= maxLines) break;
        }

        if (keep.Count == 0) return "";
        string result = string.Join(". ", keep);
        return result.Length > 500 ? result[..500] : result;
    }

    #endregion

    #region RGB → HSV (PIL-compatible 0-255 ranges)

    /// <summary>
    /// Matches PIL's "HSV" conversion (all channels 0-255) so the orange
    /// thresholds ported from the Python detector stay valid.
    /// </summary>
    private static void ToHsv255(byte r, byte g, byte b, out int h, out int s, out int v)
    {
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        v = max;
        if (max == min) { h = 0; s = 0; return; }

        int delta = max - min;
        s = (int)(delta * 255.0 / max);

        double rc = (max - r) / (double)delta;
        double gc = (max - g) / (double)delta;
        double bc = (max - b) / (double)delta;

        double hh;
        if (r == max) hh = bc - gc;
        else if (g == max) hh = 2 + rc - bc;
        else hh = 4 + gc - rc;

        hh = (hh / 6.0) % 1.0;
        if (hh < 0) hh += 1.0;
        h = (int)(hh * 255.0);
    }

    #endregion
}

#endregion
