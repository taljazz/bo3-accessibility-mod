using System.Text;

namespace Bo3Access.Launcher;

#region GobbleGum config writer

/// <summary>
/// Persists the chosen GobbleGum loadout as <c>seta acc_bgb_0..4</c> lines in
/// the mod's <c>mod.cfg</c>. Per the project's engine-constraints notes, a
/// loose <c>mod.cfg</c> in the mod folder is the only reliable way to deliver
/// custom dvars to GSC in <c>+devmap</c> (CLI <c>+set</c>, <c>+exec</c> and
/// keybinds do not work). The GSC side reads these dvars on spawn.
/// </summary>
public static class GobbleGumConfig
{
    #region Targets

    // The retail game (app 311210) execs the mod.cfg from the BASE-game mods
    // folder; the 455130 copy is the build source kept in sync.
    private static readonly string[] ModCfgPaths =
    {
        @"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\mods\zm_accessibility\mod.cfg",
        @"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\mods\zm_accessibility\mod.cfg",
    };

    #endregion

    #region Write

    /// <summary>
    /// Write the loadout. All 5 slots are always emitted (empty when unused)
    /// so a previous selection can never linger. Returns null on success,
    /// else an error message for the spoken UI.
    /// </summary>
    public static string? Save(IReadOnlyList<GobbleGum> picks)
    {
        var sb = new StringBuilder();
        sb.AppendLine("// BO3 Accessibility mod - GobbleGum loadout");
        sb.AppendLine("// Written by the launcher. Read by zm_acc_gobblegum.gsc on spawn.");
        for (int i = 0; i < GobbleGums.MaxSlots; i++)
        {
            string val = i < picks.Count ? picks[i].Internal : "";
            sb.AppendLine($"seta acc_bgb_{i} \"{val}\"");
        }

        string? firstError = null;
        foreach (string path in ModCfgPaths)
        {
            try
            {
                string? dir = Path.GetDirectoryName(path);
                if (dir is not null) Directory.CreateDirectory(dir);
                File.WriteAllText(path, sb.ToString());
            }
            catch (Exception ex)
            {
                // The 455130 copy is best-effort; only fail loudly if the
                // game-folder mod.cfg (the one actually exec'd) can't be written.
                if (path == ModCfgPaths[0])
                    firstError = "Could not save GobbleGum config: " + ex.Message;
            }
        }
        return firstError;
    }

    #endregion
}

#endregion
