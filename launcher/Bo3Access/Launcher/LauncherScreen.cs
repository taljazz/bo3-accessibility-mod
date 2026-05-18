namespace Bo3Access.Launcher;

#region Launcher screen enum

/// <summary>
/// Which screen the single launcher window is showing. Enum tracking keeps
/// key routing in <see cref="MainForm"/> explicit instead of using flags.
/// </summary>
public enum LauncherScreen
{
    /// <summary>The 14-map chooser (default).</summary>
    MapPicker,

    /// <summary>The 63-GobbleGum loadout chooser.</summary>
    GobbleGumPicker,
}

#endregion
