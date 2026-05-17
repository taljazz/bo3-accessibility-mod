namespace Bo3Access.Launcher;

#region Map group enum

/// <summary>Which collection a Zombies map belongs to (enum tracking on <see cref="ZmMap"/>).</summary>
public enum MapGroup
{
    /// <summary>Base game maps (shipped with BO3 Zombies).</summary>
    Base,

    /// <summary>Zombies Chronicles remastered maps (DLC 5).</summary>
    ZombiesChronicles,
}

/// <summary>Spoken-friendly names for <see cref="MapGroup"/> values.</summary>
public static class MapGroupExtensions
{
    public static string Describe(this MapGroup group) => group switch
    {
        MapGroup.Base => "Base game",
        MapGroup.ZombiesChronicles => "Zombies Chronicles",
        _ => group.ToString(),
    };
}

#endregion
