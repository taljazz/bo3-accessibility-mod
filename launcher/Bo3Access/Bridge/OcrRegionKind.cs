namespace Bo3Access.Bridge;

#region OCR region enum

/// <summary>
/// Which part of a BO3 menu screen a crop represents. Drives the read
/// order in <see cref="MenuOcrService"/> (enum tracking instead of ad-hoc flags).
/// </summary>
public enum OcrRegionKind
{
    /// <summary>Large page title at the top-left (MAPS, ZOMBIES, MODS, ...).</summary>
    Header,

    /// <summary>The orange highlight bar — the currently selected item.</summary>
    Highlight,

    /// <summary>Fallback: the central content area when no highlight is found.</summary>
    Center,
}

#endregion
