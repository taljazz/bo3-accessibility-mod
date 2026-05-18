namespace Bo3Access.Launcher;

#region MainForm — input routing & map navigation (partial)

public sealed partial class MainForm
{
    #region Key router

    /// <summary>Dispatch keys to the active screen (enum-driven).</summary>
    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        bool handled = _screen switch
        {
            LauncherScreen.MapPicker       => HandleMapKey(e),
            LauncherScreen.GobbleGumPicker => HandleGobbleGumKey(e), // MainForm.GobbleGum.cs
            _ => false,
        };

        if (handled)
        {
            e.Handled = true;
            e.SuppressKeyPress = true;
        }
    }

    #endregion

    #region Map screen

    private bool HandleMapKey(KeyEventArgs e)
    {
        switch (e.KeyCode)
        {
            case Keys.Down:
                _index = (_index + 1) % Maps.All.Count;
                AnnounceCurrent();
                return true;

            case Keys.Up:
                _index = (_index - 1 + Maps.All.Count) % Maps.All.Count;
                AnnounceCurrent();
                return true;

            case Keys.Enter:
                LaunchSelected();
                return true;

            case Keys.G:
                EnterGobbleGumPicker(); // MainForm.GobbleGum.cs
                return true;

            case Keys.Escape:
                _speech.Speak("Quitting.", true);
                Close();
                return true;

            default:
                return false;
        }
    }

    #endregion

    #region Map navigation

    private void AnnounceCurrent()
    {
        ZmMap m = Maps.All[_index];
        string text = $"{_index + 1} of {Maps.All.Count}. {m.Name}. {m.Group.Describe()}.";
        SetStatus(text);
        _speech.Speak(text, true);
    }

    #endregion

    #region Launch (polymorphic outcome handling)

    private void LaunchSelected()
    {
        ZmMap m = Maps.All[_index];
        _speech.Speak($"Preparing {m.Name}.", true);

        LaunchResult result = GameLauncher.LaunchMap(m);

        // Enum tracking: one switch maps every outcome to spoken feedback.
        string message = result.Outcome switch
        {
            LaunchOutcome.Success =>
                $"Launching {m.Name}. Keep this window open. " +
                "The speech bridge is running and will read the game.",
            LaunchOutcome.NotBuilt =>
                result.Detail ?? "The mod is not built yet.",
            LaunchOutcome.MirrorFailed =>
                result.Detail ?? "Could not copy the mod into the game folder.",
            LaunchOutcome.SteamMissing =>
                result.Detail ?? "Could not start Steam.",
            _ => "Unknown launch error.",
        };

        SetStatus(message);
        _speech.Speak(message, true);
    }

    #endregion
}

#endregion
