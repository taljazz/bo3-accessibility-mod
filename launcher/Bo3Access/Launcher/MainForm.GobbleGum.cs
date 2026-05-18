namespace Bo3Access.Launcher;

#region MainForm — GobbleGum picker screen (partial)

public sealed partial class MainForm
{
    #region Enter / exit

    private void EnterGobbleGumPicker()
    {
        _screen = LauncherScreen.GobbleGumPicker;
        _gumIndex = 0;
        _speech.Speak(
            $"GobbleGum picker. {_gumPicks.Count} of {GobbleGums.MaxSlots} selected. " +
            "Up and Down to browse 63 gums. Enter adds or removes the current gum. " +
            "L lists your loadout. S saves and returns. Escape cancels. " +
            "Note: in offline devmap, Classic gums are the most likely to actually work.",
            true);
        AnnounceGum();
    }

    private void ExitToMap(string spoken)
    {
        _screen = LauncherScreen.MapPicker;
        _speech.Speak(spoken, true);
        AnnounceCurrent(); // re-announce the map cursor (MainForm.Input.cs)
    }

    #endregion

    #region Key handling

    private bool HandleGobbleGumKey(KeyEventArgs e)
    {
        switch (e.KeyCode)
        {
            case Keys.Down:
                _gumIndex = (_gumIndex + 1) % GobbleGums.All.Count;
                AnnounceGum();
                return true;

            case Keys.Up:
                _gumIndex = (_gumIndex - 1 + GobbleGums.All.Count) % GobbleGums.All.Count;
                AnnounceGum();
                return true;

            case Keys.Enter:
            case Keys.Space:
                ToggleCurrent();
                return true;

            case Keys.L:
                AnnounceLoadout();
                return true;

            case Keys.S:
                SaveAndExit();
                return true;

            case Keys.Escape:
                ExitToMap("GobbleGum changes cancelled. Returning to the map list.");
                return true;

            default:
                return false;
        }
    }

    #endregion

    #region Selection

    private void ToggleCurrent()
    {
        GobbleGum gum = GobbleGums.All[_gumIndex];
        int existing = _gumPicks.FindIndex(g => g.Internal == gum.Internal);

        if (existing >= 0)
        {
            _gumPicks.RemoveAt(existing);
            Announce($"Removed {gum.Display}. {_gumPicks.Count} selected.");
            return;
        }

        if (_gumPicks.Count >= GobbleGums.MaxSlots)
        {
            Announce($"Loadout full. {GobbleGums.MaxSlots} maximum. " +
                     "Remove one before adding another.");
            return;
        }

        _gumPicks.Add(gum);
        Announce($"Added {gum.Display}. Slot {_gumPicks.Count} of {GobbleGums.MaxSlots}.");
    }

    private void AnnounceLoadout()
    {
        if (_gumPicks.Count == 0)
        {
            _speech.Speak("Loadout is empty.", true);
            return;
        }
        var names = string.Join(", ", _gumPicks.Select((g, i) => $"{i + 1}, {g.Display}"));
        _speech.Speak($"Loadout: {names}.", true);
    }

    #endregion

    #region Save

    private void SaveAndExit()
    {
        string? err = GobbleGumConfig.Save(_gumPicks);
        if (err is not null)
        {
            SetStatus(err);
            _speech.Speak(err, true);
            return; // stay on the picker so the user can retry
        }

        string summary = _gumPicks.Count == 0
            ? "GobbleGum loadout cleared and saved."
            : $"Saved {_gumPicks.Count} GobbleGums. They apply on your next launch.";
        ExitToMap(summary);
    }

    #endregion

    #region Announce helpers

    private void AnnounceGum()
    {
        GobbleGum gum = GobbleGums.All[_gumIndex];
        int slot = _gumPicks.FindIndex(g => g.Internal == gum.Internal);
        string state = slot >= 0 ? $"selected, slot {slot + 1}" : "not selected";
        Announce($"{_gumIndex + 1} of {GobbleGums.All.Count}. {gum.Display}. {state}.");
    }

    private void Announce(string text)
    {
        SetStatus(text);
        _speech.Speak(text, true);
    }

    #endregion
}

#endregion
