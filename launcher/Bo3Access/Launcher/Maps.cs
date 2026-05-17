namespace Bo3Access.Launcher;

#region Map catalogue

/// <summary>A selectable Zombies map: spoken name, engine devmap id, and group.</summary>
public readonly record struct ZmMap(string Name, string DevmapId, MapGroup Group);

/// <summary>The 14 launchable Zombies maps (base + Zombies Chronicles).</summary>
public static class Maps
{
    public static readonly IReadOnlyList<ZmMap> All = new ZmMap[]
    {
        // ── Base ──
        new("Shadows of Evil",   "zm_zod",        MapGroup.Base),
        new("The Giant",         "zm_factory",    MapGroup.Base),
        new("Der Eisendrache",   "zm_castle",     MapGroup.Base),
        new("Zetsubou No Shima", "zm_island",     MapGroup.Base),
        new("Gorod Krovi",       "zm_stalingrad", MapGroup.Base),
        new("Revelations",       "zm_genesis",    MapGroup.Base),

        // ── Zombies Chronicles ──
        new("Nacht der Untoten", "zm_prototype",  MapGroup.ZombiesChronicles),
        new("Verruckt",          "zm_asylum",     MapGroup.ZombiesChronicles),
        new("Shi No Numa",       "zm_sumpf",      MapGroup.ZombiesChronicles),
        new("Kino der Toten",    "zm_theater",    MapGroup.ZombiesChronicles),
        new("Ascension",         "zm_cosmodrome", MapGroup.ZombiesChronicles),
        new("Shangri-La",        "zm_temple",     MapGroup.ZombiesChronicles),
        new("Moon",              "zm_moon",       MapGroup.ZombiesChronicles),
        new("Origins",           "zm_tomb",       MapGroup.ZombiesChronicles),
    };
}

#endregion
