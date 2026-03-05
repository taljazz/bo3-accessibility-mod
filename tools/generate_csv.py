"""Generate the BO3 sound alias CSV file for the accessibility mod.

Sound approach:
- Beacon beeps are 3D (positioned at the interactable) so the player hears direction
- TTS via NVDA also announces object name + direction as backup
- Threat and direction sounds remain as 2D audio cues (player-relative)
"""
import os

HEADER = "Name,Behavior,Storage,FileSpec,FileSpecSustain,FileSpecRelease,Template,Loadspec,Secondary,SustainAlias,ReleaseAlias,Bus,VolumeGroup,DuckGroup,Duck,ReverbSend,CenterSend,VolMin,VolMax,DistMin,DistMaxDry,DistMaxWet,DryMinCurve,DryMaxCurve,WetMinCurve,WetMaxCurve,LimitCount,LimitType,EntityLimitCount,EntityLimitType,PitchMin,PitchMax,PriorityMin,PriorityMax,PriorityThresholdMin,PriorityThresholdMax,AmplitudePriority,PanType,Pan,Futz,Looping,RandomizeType,Probability,StartDelay,EnvelopMin,EnvelopMax,EnvelopPercent,OcclusionLevel,IsBig,DistanceLpf,FluxType,FluxTime,Subtitle,Doppler,ContextType,ContextValue,ContextType1,ContextValue1,ContextType2,ContextValue2,ContextType3,ContextValue3,Timescale,IsMusic,IsCinematic,FadeIn,FadeOut,Pauseable,StopOnEntDeath,Compression,StopOnPlay,DopplerScale,FutzPatch,VoiceLimit,IgnoreMaxDist,NeverPlayTwice,ContinuousPan,FileSource,FileSourceSustain,FileSourceRelease,FileTarget,FileTargetSustain,FileTargetRelease,Platform,Language,OutputDevices,PlatformMask,WiiUMono,StopAlias,DistanceLpfMin,DistanceLpfMax,FacialAnimationName,RestartContextLoops,SilentInCPZ,ContextFailsafe,GPAD,GPADOnly,MuteVoice,MuteMusic,RowSourceFileName,RowSourceShortName,RowSourceLineNumber"

NUM_COLS = len(HEADER.split(","))

def make_row_2d(alias, category, vol=80):
    """2D sound alias - plays on the player, no spatial positioning.
    Uses UIN_MOD template (bus_ui, grp_menu, 2d pan)."""
    filespec = f"accessibility\\{category}\\{alias}.wav"
    trailing = NUM_COLS - 19
    row = f"{alias},,,{filespec},,,UIN_MOD,,,,,,,,,,,{vol},{vol}" + "," * trailing
    return row

def make_row_3d(alias, category, vol=80, dist_min=100, dist_max=1800):
    """3D positional sound alias - spatialized at a world position.
    Custom fields: bus_fx, grp_set_piece, PanType=3d, no occlusion.
    Column layout (0-indexed, from the 97-column aliases CSV header):
      0=Name, 3=FileSpec, 11=Bus, 12=VolumeGroup,
      17=VolMin, 18=VolMax, 19=DistMin, 20=DistMaxDry, 21=DistMaxWet,
      26=LimitCount, 27=LimitType, 28=EntityLimitCount, 29=EntityLimitType,
      37=PanType, 68=StopOnEntDeath
    """
    cols = [""] * NUM_COLS
    cols[0] = alias
    cols[3] = f"accessibility\\{category}\\{alias}.wav"
    cols[11] = "bus_fx"
    cols[12] = "grp_set_piece"
    cols[13] = "snp_never_duck"    # DuckGroup — don't let other sounds duck beacons
    cols[17] = str(vol)
    cols[18] = str(vol)
    cols[19] = str(dist_min)       # DistMin — full volume within this range
    cols[20] = str(dist_max)       # DistMaxDry — sound inaudible beyond this
    cols[21] = str(dist_max + 200) # DistMaxWet — reverb tail extends a bit further
    cols[26] = "2"                 # LimitCount — max 2 instances
    cols[27] = "oldest"            # LimitType
    cols[28] = "1"                 # EntityLimitCount — 1 per entity
    cols[29] = "oldest"            # EntityLimitType
    cols[37] = "3d"                # PanType — THIS makes it spatial
    cols[68] = "yes"               # StopOnEntDeath — clean up when ent deleted
    return ",".join(cols)

# ===== 3D BEACON ALIASES (positioned at interactable objects) =====
# These beeps play AT the object's world position so the player hears direction.
# Volume still indicates proximity: close = loud high beep, far = quiet low beep.
aliases_3d = {}

aliases_3d["beacons"] = [
    ("aud_acc_beacon_close", 60, 50, 1500),     # < 200 units: moderate, short range
    ("aud_acc_beacon_near", 45, 100, 1800),      # 200-600 units: soft
    ("aud_acc_beacon_far", 30, 200, 2000),        # 600+ units: quiet
]

# ===== 2D ALIASES (player-relative, no spatial positioning) =====
aliases_2d = {}

# Threat level heartbeats / tones
aliases_2d["threat"] = [
    ("aud_acc_threat_critical", 100),
    ("aud_acc_threat_high", 85),
    ("aud_acc_threat_medium", 70),
    ("aud_acc_threat_low", 55),
]

# Direction indicator sounds
aliases_2d["proximity"] = [
    ("aud_acc_dir_front", 80),
    ("aud_acc_dir_behind", 80),
    ("aud_acc_dir_left", 80),
    ("aud_acc_dir_right", 80),
]

# Generate CSV
output_path = r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\share\raw\sound\aliases\zm_mod.csv"

rows = [HEADER]
total = 0

# 3D beacon rows
for category, alias_list in aliases_3d.items():
    for alias, vol, dist_min, dist_max in alias_list:
        rows.append(make_row_3d(alias, category, vol, dist_min, dist_max))
        total += 1

# 2D rows
for category, alias_list in aliases_2d.items():
    for item in alias_list:
        if isinstance(item, tuple):
            alias, vol = item
        else:
            alias = item
            vol = 80
        rows.append(make_row_2d(alias, category, vol))
        total += 1

# Write
with open(output_path, "w", newline="\n") as f:
    f.write("\n".join(rows))
    f.write("\n")

print(f"Generated {total} sound alias rows ({len(aliases_3d.get('beacons', []))} 3D beacons)")
print(f"Written to: {output_path}")
