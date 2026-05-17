using System.Diagnostics;

namespace Bo3Access.Launcher;

#region Game launcher

/// <summary>
/// Mirrors the Mod-Tools build into the retail game's mods folder, then
/// starts BO3 via Steam with the accessibility mod and chosen map.
///
/// Mod Tools build into "...Black Ops III 455130\mods", but the retail
/// game (Steam app 311210) loads mods from its own base-game mods folder —
/// so every launch re-mirrors first.
/// </summary>
public static class GameLauncher
{
    #region Paths

    private const string SteamExe =
        @"C:\Program Files (x86)\Steam\steam.exe";
    private const string ToolsMod =
        @"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\mods\zm_accessibility";
    private const string GameMod =
        @"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\mods\zm_accessibility";

    #endregion

    #region Public API

    /// <summary>True when the linker has produced the mod fastfile.</summary>
    public static bool IsModBuilt =>
        File.Exists(Path.Combine(ToolsMod, "zone", "zm_mod.ff"));

    /// <summary>Mirror the built mod into the game folder, then launch the chosen map.</summary>
    public static LaunchResult LaunchMap(ZmMap map)
    {
        if (!IsModBuilt)
            return new LaunchResult(LaunchOutcome.NotBuilt,
                "The mod is not built yet. Run deploy first, then try again.");

        try
        {
            MirrorDirectory(ToolsMod, GameMod);
        }
        catch (Exception ex)
        {
            return new LaunchResult(LaunchOutcome.MirrorFailed,
                "Could not copy the mod into the game folder: " + ex.Message);
        }

        if (!File.Exists(SteamExe))
            return new LaunchResult(LaunchOutcome.SteamMissing,
                "Could not find Steam at the default location.");

        var psi = new ProcessStartInfo { FileName = SteamExe, UseShellExecute = false };
        foreach (string arg in new[]
                 { "-applaunch", "311210", "+set", "fs_game", "zm_accessibility",
                   "+devmap", map.DevmapId })
            psi.ArgumentList.Add(arg);

        try
        {
            Process.Start(psi);
            return new LaunchResult(LaunchOutcome.Success);
        }
        catch (Exception ex)
        {
            return new LaunchResult(LaunchOutcome.SteamMissing,
                "Steam failed to start: " + ex.Message);
        }
    }

    #endregion

    #region Helpers

    private static void MirrorDirectory(string source, string dest)
    {
        Directory.CreateDirectory(dest);
        foreach (string dir in Directory.GetDirectories(source, "*", SearchOption.AllDirectories))
            Directory.CreateDirectory(dir.Replace(source, dest));
        foreach (string file in Directory.GetFiles(source, "*", SearchOption.AllDirectories))
            File.Copy(file, file.Replace(source, dest), overwrite: true);
    }

    #endregion
}

#endregion
