#using scripts\codescripts\struct;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;

// Accessibility sub-modules
#using scripts\zm\zm_acc_aim_assist;
#using scripts\zm\zm_acc_proximity;
#using scripts\zm\zm_acc_gamestate;
#using scripts\zm\zm_acc_beacons;
#using scripts\zm\zm_acc_settings;
#using scripts\zm\zm_acc_menus;

#insert scripts\shared\shared.gsh;

#namespace zm_accessibility;

/*
    BO3 Zombies Accessibility Mod - Main Entry Point
    Designed for blind/low-vision players.

    Features:
    - Auto-aim assist (snap to nearest zombie)
    - Zombie proximity & directional audio cues
    - Game state audio (round, points, health)
    - Interactable audio beacons (perks, wall buys, mystery box)
*/

// ============================================
// CONFIGURATION - Tweak these values as needed
// ============================================

// Auto-aim settings
#define AIM_ASSIST_ENABLED          1
#define AIM_ASSIST_RANGE            1000        // Max range to acquire targets (units)
#define AIM_ASSIST_FOV              180         // Field of view for target acquisition (degrees) - wide for accessibility
#define AIM_ASSIST_SNAP_SPEED       1.0         // Instant snap - blind players gain nothing from gradual movement
#define AIM_ASSIST_AUTO_FIRE        0           // 1 = auto-fire when locked on, 0 = manual fire
#define AIM_ASSIST_HEAD_TARGETING   1           // 1 = aim for head, 0 = aim for center mass

// Audio cue settings
#define PROXIMITY_ALERT_RANGE       600         // Range at which proximity audio starts
#define PROXIMITY_UPDATE_INTERVAL   0.2         // How often proximity checks run (seconds)
#define BEACON_RANGE                1500        // Range for interactable audio beacons
#define BEACON_UPDATE_INTERVAL      1.0         // How often beacon checks run (seconds)

// Game state announcement settings
#define HEALTH_WARNING_THRESHOLD    50          // Health % to trigger warning
#define HEALTH_CRITICAL_THRESHOLD   25          // Health % for critical warning
#define POINTS_ANNOUNCE_INTERVAL    45          // Seconds between periodic point announcements

// TTS priority levels (lower number = higher priority)
#define TTS_PRIORITY_CRITICAL   0
#define TTS_PRIORITY_HIGH       1
#define TTS_PRIORITY_MEDIUM     2
#define TTS_PRIORITY_LOW        3

REGISTER_SYSTEM( "zm_accessibility", &__init__, undefined )

function __init__()
{
    // Enable console log file writing so the NVDA bridge can read it
    SetDvar("logfile", "2");

    // DEBUG: confirm mod is loading
    IPrintLnBold("ACC MOD: INIT OK");

    callback::on_connect(&on_player_connect);
    callback::on_spawned(&on_player_spawned);

    // Global level initialization
    level.accessibility = SpawnStruct();
    level.accessibility.enabled = true;
    level.accessibility.aim_assist = AIM_ASSIST_ENABLED;
    level.accessibility.auto_fire = AIM_ASSIST_AUTO_FIRE;

    // Wire up #define values to level.accessibility for runtime access
    level.accessibility.aim_range = AIM_ASSIST_RANGE;
    level.accessibility.aim_fov = AIM_ASSIST_FOV;
    level.accessibility.aim_head_targeting = AIM_ASSIST_HEAD_TARGETING;
    level.accessibility.proximity_range = PROXIMITY_ALERT_RANGE;
    level.accessibility.proximity_interval = PROXIMITY_UPDATE_INTERVAL;
    level.accessibility.beacon_range = BEACON_RANGE;
    level.accessibility.beacon_interval = BEACON_UPDATE_INTERVAL;
    level.accessibility.health_warning = HEALTH_WARNING_THRESHOLD;
    level.accessibility.health_critical = HEALTH_CRITICAL_THRESHOLD;
    level.accessibility.points_interval = POINTS_ANNOUNCE_INTERVAL * 1000;

    // Combat mode flag (managed by proximity module based on threat level)
    level.accessibility.combat_mode = false;

    // Initialize TTS priority queue
    level.accessibility.tts_queue = [];
    level.accessibility.tts_last_send = 0;

    // Initialize shared zombie cache
    level.accessibility.zombie_cache = [];

    // Initialize weapon display name lookup table
    zm_acc_menus::init_weapon_names();

    level thread monitor_round_changes();
    level thread monitor_game_end();
    level thread tts_queue_think();
    level thread zombie_cache_think();
    level thread zm_acc_gamestate::powerup_monitor_think();
}

function on_player_connect()
{
    self.accessibility = SpawnStruct();
    self.accessibility.aim_target = undefined;
    self.accessibility.last_health = self.maxhealth;
    self.accessibility.last_points = 0;
    self.accessibility.last_round_announced = 0;
}

function on_player_spawned()
{
    // DEBUG: confirm spawn fires (rumble + screen text)
    self PlayRumbleOnEntity("damage_heavy");
    IPrintLnBold("ACC MOD: PLAYER SPAWNED");

    self notify("acc_restart");
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    // Start all accessibility systems for this player
    if(level.accessibility.enabled)
    {
        if(level.accessibility.aim_assist)
        {
            self thread zm_acc_aim::aim_assist_think();
        }

        self thread zm_acc_proximity::zombie_proximity_think();
        self thread zm_acc_gamestate::health_monitor_think();
        self thread zm_acc_gamestate::points_monitor_think();
        self thread zm_acc_gamestate::ammo_monitor_think();
        self thread zm_acc_gamestate::weapon_monitor_think();
        self thread zm_acc_gamestate::downed_monitor_think();
        self thread zm_acc_gamestate::perk_monitor_think();
        self thread zm_acc_gamestate::special_round_monitor_think();
        self thread zm_acc_gamestate::zombie_count_monitor_think();
        self thread zm_acc_gamestate::power_monitor_think();
        self thread zm_acc_beacons::interactable_beacon_think();
        self thread zm_acc_settings::settings_think();
        self thread zm_acc_menus::menu_prompt_think();
    }

    // Announce spawn via TTS
    queue_tts_message("Game started", "high");
}

// ============================================
// TTS PRIORITY QUEUE SYSTEM
// ============================================

function queue_tts_message(text, priority)
{
    if(!IsDefined(priority))
        priority = "low";

    msg = SpawnStruct();
    msg.text = text;

    switch(priority)
    {
        case "critical":
            msg.priority = TTS_PRIORITY_CRITICAL;
            break;
        case "high":
            msg.priority = TTS_PRIORITY_HIGH;
            break;
        case "medium":
            msg.priority = TTS_PRIORITY_MEDIUM;
            break;
        default:
            msg.priority = TTS_PRIORITY_LOW;
            break;
    }

    msg.time = GetTime();

    queue = level.accessibility.tts_queue;
    queue[queue.size] = msg;
    level.accessibility.tts_queue = queue;
}

function tts_queue_think()
{
    level endon("end_game");

    min_gap_ms = 800; // 0.8s minimum gap between messages

    while(true)
    {
        if(level.accessibility.tts_queue.size > 0)
        {
            now = GetTime();
            if(now - level.accessibility.tts_last_send >= min_gap_ms)
            {
                // Find highest priority message (lowest number)
                best_idx = 0;
                best_priority = level.accessibility.tts_queue[0].priority;
                best_time = level.accessibility.tts_queue[0].time;

                for(i = 1; i < level.accessibility.tts_queue.size; i++)
                {
                    entry = level.accessibility.tts_queue[i];
                    if(entry.priority < best_priority || (entry.priority == best_priority && entry.time < best_time))
                    {
                        best_idx = i;
                        best_priority = entry.priority;
                        best_time = entry.time;
                    }
                }

                // Send the best message
                send_tts_message(level.accessibility.tts_queue[best_idx].text);
                level.accessibility.tts_last_send = now;

                // Remove from queue by rebuilding array without that index
                new_queue = [];
                for(i = 0; i < level.accessibility.tts_queue.size; i++)
                {
                    if(i != best_idx)
                        new_queue[new_queue.size] = level.accessibility.tts_queue[i];
                }
                level.accessibility.tts_queue = new_queue;
            }
        }

        wait 0.05;
    }
}

// ============================================
// ROUND CHANGE MONITOR (level-scope)
// ============================================

function monitor_round_changes()
{
    level endon("end_game");

    last_round = 0;

    while(true)
    {
        if(IsDefined(level.round_number) && level.round_number != last_round)
        {
            last_round = level.round_number;

            // Announce to all players
            players = GetPlayers();
            foreach(player in players)
            {
                player thread announce_round(last_round);
            }
        }

        wait 0.5;
    }
}

function announce_round(round_num)
{
    // TTS announcement with dynamic round number
    queue_tts_message("Round " + round_num, "critical");

    // Haptic feedback via rumble
    self PlayRumbleOnEntity("damage_heavy");
    wait 0.3;
    self StopRumble("damage_heavy");
}

// ============================================
// GAME-OVER MONITOR (level-scope)
// ============================================

function monitor_game_end()
{
    level waittill("end_game");
    wait 1.0;
    players = GetPlayers();
    foreach(player in players)
        queue_tts_message("Game over. You reached round " + level.round_number, "critical");
}

// ============================================
// SHARED ZOMBIE CACHE (level-scope)
// ============================================

function zombie_cache_think()
{
    level endon("end_game");

    while(true)
    {
        level.accessibility.zombie_cache = GetAITeamArray("axis");
        wait 0.1;
    }
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

// Send a text message to the NVDA TTS bridge via console log
// logPrint() doesn't write to console_mp.log in BO3, but IPrintLn() does
// (appears as [msg]ACC_TTS:... lines). The bridge matches the ACC_TTS: substring.
function send_tts_message(text)
{
    IPrintLn("ACC_TTS:" + text);
}

function play_accessibility_sound(alias)
{
    if(IsDefined(alias) && alias != "")
    {
        self PlayLocalSound(alias);
    }
}

// Removed: use persistent entity pattern instead. See zm_acc_beacons for example.
function play_sound_at_pos(alias, pos)
{
    // Spawning/deleting entities per sound pulse causes entity exhaustion.
    // Use a persistent entity and move it with .origin = pos instead.
}

// Combined scan: returns struct with .count, .nearest, .nearest_dist
// Uses shared zombie cache + DistanceSquared for speed
function get_zombie_scan(range)
{
    result = SpawnStruct();
    result.count = 0;
    result.nearest = undefined;
    result.nearest_dist = range + 1;

    zombies = level.accessibility.zombie_cache;
    if(!IsDefined(zombies))
        zombies = [];

    range_sq = range * range;
    player_pos = self.origin;
    best_dist_sq = range_sq + 1;

    foreach(zombie in zombies)
    {
        if(!IsAlive(zombie))
            continue;

        dist_sq = DistanceSquared(player_pos, zombie.origin);
        if(dist_sq <= range_sq)
        {
            result.count++;
            if(dist_sq < best_dist_sq)
            {
                best_dist_sq = dist_sq;
                result.nearest = zombie;
            }
        }
    }

    // Only compute real distance for the single nearest
    if(IsDefined(result.nearest))
        result.nearest_dist = Distance(player_pos, result.nearest.origin);

    return result;
}

// Returns 8-way direction relative to player facing:
// "front", "front-right", "right", "behind-right", "behind", "behind-left", "left", "front-left"
function get_relative_direction(target_origin)
{
    to_target = VectorNormalize(target_origin - self.origin);
    angles = self GetPlayerAngles();
    forward = AnglesToForward(angles);
    right_vec = AnglesToRight(angles);

    dot_forward = VectorDot(to_target, forward);
    dot_right = VectorDot(to_target, right_vec);

    // Threshold for diagonal detection: sin(22.5 degrees) ~ 0.383
    threshold = 0.383;

    if(dot_forward > threshold)
    {
        // Forward half
        if(dot_right > threshold)
            return "front-right";
        else if(dot_right < -threshold)
            return "front-left";
        else
            return "front";
    }
    else if(dot_forward < -threshold)
    {
        // Behind half
        if(dot_right > threshold)
            return "behind-right";
        else if(dot_right < -threshold)
            return "behind-left";
        else
            return "behind";
    }
    else
    {
        // Side
        if(dot_right > 0)
            return "right";
        else
            return "left";
    }
}
