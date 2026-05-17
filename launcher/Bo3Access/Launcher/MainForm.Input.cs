namespace Bo3Access.Launcher;

#region MainForm — input & navigation (partial)

public sealed partial class MainForm
{
    #region Key handling

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        switch (e.KeyCode)
        {
            case Keys.Down:
                _index = (_index + 1) % Maps.All.Count;
                AnnounceCurrent();
                break;

            case Keys.Up:
                _index = (_index - 1 + Maps.All.Count) % Maps.All.Count;
                AnnounceCurrent();
                break;

            case Keys.Enter:
                LaunchSelected();
                break;

            case Keys.Escape:
                _speech.Speak("Quitting.", true);
                Close();
                break;

            default:
                return; // let other keys through untouched
        }

        e.Handled = true;
        e.SuppressKeyPress = true;
    }

    #endregion

    #region Navigation

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
