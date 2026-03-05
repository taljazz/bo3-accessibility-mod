# BO3 Zombies Accessibility Mod

A mod for Call of Duty: Black Ops 3 Zombies designed to make the game playable for blind and low-vision players. Works on any Zombies map (map-agnostic).

## Features

### Auto-Aim Assist
- Snaps aim to nearest zombie when ADS or firing
- Line-of-sight checking (won't target through walls)
- Prioritizes closest visible zombie
- Optional auto-fire mode (configurable)
- Head targeting for efficient kills

### Zombie Proximity Audio
- Directional audio cues (front, behind, left, right)
- Threat level scaling (low → medium → high → critical)
- Heartbeat-style pulse that speeds up as zombies approach
- Swarm warning when surrounded
- Controller rumble feedback scaled to threat

### Game State Announcements
- Health status changes (full, warning, critical)
- Damage taken / health recovered feedback
- Point milestone announcements (every 1000 points)
- Ammo status (low, reload needed, empty)
- Round change announcements

### Interactable Audio Beacons
- Perk machines (Juggernog, Speed Cola, etc.)
- Wall buy weapons
- Mystery Box location
- Purchasable doors/debris
- Power switch (only beacons when power is off)
- Pack-a-Punch machine
- Distance-scaled audio (close, near, far)
- Directional indicators for each beacon

## Prerequisites

1. **Call of Duty: Black Ops III** (Steam version)
2. **BO3 Mod Tools** - Free on Steam (search "Call of Duty: Black Ops III - Mod Tools")

## Installation & Setup

### Step 1: Install BO3 Mod Tools
1. Open Steam → Library
2. Search for "Call of Duty: Black Ops III - Mod Tools"
3. Install (it's free if you own BO3)

### Step 2: Locate Your Mod Directory
Your BO3 mod tools install to:
```
Steam\steamapps\common\Call of Duty Black Ops III\
```

Mods go into the `mods` folder, and user maps into `usermaps`.

### Step 3: Deploy the Scripts
1. Create a folder for your mod in the BO3 mods directory:
   ```
   ...\Call of Duty Black Ops III\mods\zm_accessibility\
   ```
2. Copy the `scripts\zm\` folder from this project into:
   ```
   ...\mods\zm_accessibility\scripts\zm\
   ```

### Step 4: Create Sound Aliases
The mod references sound aliases (prefixed with `aud_acc_`) that need to be created in the BO3 sound system. You will need to:
1. Create or source audio files for each cue
2. Set up sound aliases in the BO3 Asset Property Editor (APE)
3. Link the aliases to your audio files

See the **Sound Alias Reference** section below for the full list.

### Step 5: Compile and Load
1. Open the BO3 Mod Tools Launcher
2. Select your mod
3. Compile scripts
4. Launch the game with your mod loaded

## Configuration

Key settings are defined as `#define` constants in `zm_accessibility_main.gsc`:

| Setting | Default | Description |
|---------|---------|-------------|
| AIM_ASSIST_ENABLED | 1 | Enable/disable auto-aim |
| AIM_ASSIST_RANGE | 1000 | Max targeting range (units) |
| AIM_ASSIST_SNAP_SPEED | 0.8 | Aim snap speed (0.0-1.0) |
| AIM_ASSIST_AUTO_FIRE | 0 | Auto-fire when locked on |
| PROXIMITY_ALERT_RANGE | 600 | Zombie detection range |
| HEALTH_WARNING_THRESHOLD | 50 | Health % for warning |
| HEALTH_CRITICAL_THRESHOLD | 25 | Health % for critical alert |

## Sound Alias Reference

These sound aliases must be created in APE for the mod to produce audio:

### General
- `aud_acc_spawned` - Player spawn confirmation
- `aud_acc_round_start` - New round beginning

### Threat / Proximity
- `aud_acc_threat_critical` - Zombies extremely close
- `aud_acc_threat_high` - Zombies close
- `aud_acc_threat_medium` - Zombies approaching
- `aud_acc_threat_low` - Zombies detected at range
- `aud_acc_all_clear` - No zombies nearby
- `aud_acc_swarm_warning` - Surrounded by 5+ zombies

### Directional
- `aud_acc_dir_front` - Threat/object ahead
- `aud_acc_dir_behind` - Threat/object behind
- `aud_acc_dir_left` - Threat/object to left
- `aud_acc_dir_right` - Threat/object to right

### Targeting
- `aud_acc_target_acquired` - Auto-aim locked on

### Health
- `aud_acc_health_critical` - Health below 25%
- `aud_acc_health_warning` - Health below 50%
- `aud_acc_health_full` - Health recovered
- `aud_acc_damage_taken` - Took damage
- `aud_acc_health_recovered` - Health regenerated

### Points
- `aud_acc_points_gained` - Earned 100+ points
- `aud_acc_points_milestone` - Hit a 1000-point milestone
- `aud_acc_points_status` - Periodic point update

### Ammo
- `aud_acc_ammo_empty` - Weapon completely dry
- `aud_acc_ammo_reload` - Clip empty, reserves available
- `aud_acc_ammo_critical` - Last clip, running low
- `aud_acc_ammo_low` - Low reserve ammo

### Beacons (each has _close, _near, _far variants)
- `aud_acc_beacon_perk_*` - Perk machine nearby
- `aud_acc_beacon_wallbuy_*` - Wall buy weapon nearby
- `aud_acc_beacon_box_*` - Mystery Box nearby
- `aud_acc_beacon_door_*` - Purchasable door nearby
- `aud_acc_beacon_power_*` - Power switch nearby
- `aud_acc_beacon_pap_*` - Pack-a-Punch nearby

## File Structure

```
scripts/zm/
├── zm_accessibility_main.gsc    # Entry point, config, utilities
├── zm_acc_aim_assist.gsc        # Auto-aim targeting system
├── zm_acc_proximity.gsc         # Zombie proximity & directional audio
├── zm_acc_gamestate.gsc         # Health, points, ammo monitoring
└── zm_acc_beacons.gsc           # Interactable object audio beacons
```

## Known Limitations

- Sound aliases must be manually created in APE (no default BO3 sounds for these cues)
- Auto-aim uses `SetPlayerAngles()` which can feel abrupt; tuning snap speed helps
- Entity targetnames may vary between custom maps
- Some maps may use non-standard entity naming that beacons won't detect
- MagicBullet auto-fire consumes ammo differently than normal firing

## Future Improvements

- Text-to-speech integration for dynamic announcements
- Navigation waypoint system (audio breadcrumb trails)
- Teammate proximity and status audio
- Power-up identification sounds
- Trap activation audio warnings
- Menu/UI audio navigation overlay
