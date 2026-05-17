namespace Bo3Access.Launcher;

#region Launch outcome

/// <summary>Result of trying to launch a map (enum tracking instead of bool+string).</summary>
public enum LaunchOutcome
{
    /// <summary>Mod mirrored and Steam started.</summary>
    Success,

    /// <summary>The mod has not been built yet (no zm_mod.ff).</summary>
    NotBuilt,

    /// <summary>Copying the built mod into the game folder failed.</summary>
    MirrorFailed,

    /// <summary>steam.exe was not found at the expected location.</summary>
    SteamMissing,
}

/// <summary>Launch result plus optional detail for the spoken message.</summary>
public readonly record struct LaunchResult(LaunchOutcome Outcome, string? Detail = null)
{
    public bool Ok => Outcome == LaunchOutcome.Success;
}

#endregion
