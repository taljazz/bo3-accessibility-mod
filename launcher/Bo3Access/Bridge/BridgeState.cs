using System.Diagnostics;

namespace Bo3Access.Bridge;

#region Shared bridge state

/// <summary>
/// Thread-safe state shared between the bridge workers. The log-tail worker
/// reports gameplay activity; the OCR worker reads <see cref="Mode"/> to
/// decide whether it may speak. State is expressed as a <see cref="BridgeMode"/>
/// enum rather than scattered booleans (enum tracking).
/// </summary>
public sealed class BridgeState
{
    #region Fields

    private long _lastGameplayTicks; // Stopwatch timestamp; 0 = never

    /// <summary>Silence window after the last gameplay line before we assume menus.</summary>
    private static readonly TimeSpan GameplayTimeout = TimeSpan.FromSeconds(8);

    #endregion

    #region Mutation

    /// <summary>Called by the log-tail worker whenever a gameplay line is spoken.</summary>
    public void MarkGameplay() =>
        Interlocked.Exchange(ref _lastGameplayTicks, Stopwatch.GetTimestamp());

    #endregion

    #region Derived mode (enum tracking)

    /// <summary>Current <see cref="BridgeMode"/>, derived from recent gameplay activity.</summary>
    public BridgeMode Mode
    {
        get
        {
            long last = Interlocked.Read(ref _lastGameplayTicks);
            if (last == 0) return BridgeMode.Startup;
            return Stopwatch.GetElapsedTime(last) < GameplayTimeout
                ? BridgeMode.Gameplay
                : BridgeMode.Menu;
        }
    }

    /// <summary>Convenience: true while gameplay speech is recent.</summary>
    public bool InGameplay => Mode == BridgeMode.Gameplay;

    #endregion
}

#endregion
