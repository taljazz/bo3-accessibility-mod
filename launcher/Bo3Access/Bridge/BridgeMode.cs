namespace Bo3Access.Bridge;

#region Bridge mode enum

/// <summary>
/// What the bridge is currently doing. Tracked on <see cref="BridgeState"/>
/// and used polymorphically by workers: the OCR worker stays silent unless
/// the mode is <see cref="Menu"/>, so it never talks over gameplay speech.
/// </summary>
public enum BridgeMode
{
    /// <summary>No gameplay seen yet — game probably still at menus / not launched.</summary>
    Startup = 0,

    /// <summary>Gameplay TTS is actively flowing (a round is in progress).</summary>
    Gameplay = 1,

    /// <summary>Gameplay has gone quiet — assume the player is in menus.</summary>
    Menu = 2,
}

#endregion
