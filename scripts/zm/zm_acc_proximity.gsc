#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_proximity;

/*
    Zombie Proximity & Directional Audio System

    Provides blind players with spatial awareness:
    - Threat level indicator (critical/high/medium/low)
    - Directional audio cues (front, behind, left, right)
    - Swarm warning when surrounded
    - Controller rumble scaled to threat
    - Special enemy detection (dogs, bosses)
    - Multi-directional behind warnings
    - Hysteresis to prevent threat level flapping
    - Round-scaled detection range

    Uses cooldowns to prevent overlapping/spamming audio.
*/

function zombie_proximity_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_threat_level = "none";
    last_direction = "";
    last_threat_time = 0;
    last_dir_time = 0;
    last_swarm_time = 0;
    last_clear_time = 0;
    last_dog_time = 0;
    last_boss_time = 0;
    last_behind_time = 0;

    // Hysteresis: track consecutive ticks at a new threat level
    self.accessibility.current_threat = "none";
    self.accessibility.threat_stable_count = 0;

    while(true)
    {
        range = get_scan_range();
        scan = self proximity_scan(range);
        count = scan.count;
        now = GetTime();

        if(count > 0 && IsDefined(scan.nearest_origin))
        {
            nearest_origin = scan.nearest_origin;
            nearest_dist = scan.nearest_dist;
            direction = self zm_accessibility::get_relative_direction(nearest_origin);
            new_threat = get_threat_level(nearest_dist, count, range);

            // Special enemy announcements (high priority, cooldown 4s)
            if(scan.has_boss && (now - last_boss_time) > 4000)
            {
                zm_accessibility::queue_tts_message("Boss nearby", "critical");
                last_boss_time = now;
            }
            if(scan.has_dogs && (now - last_dog_time) > 4000)
            {
                zm_accessibility::queue_tts_message("Dogs nearby", "critical");
                last_dog_time = now;
            }

            // Hysteresis: only change announced threat if stable for 2+ ticks
            threat_changed = false;
            if(new_threat != self.accessibility.current_threat)
            {
                self.accessibility.threat_stable_count++;
                if(self.accessibility.threat_stable_count >= 2)
                {
                    self.accessibility.current_threat = new_threat;
                    self.accessibility.threat_stable_count = 0;
                    threat_changed = true;
                }
            }
            else
            {
                self.accessibility.threat_stable_count = 0;
            }

            threat_level = self.accessibility.current_threat;

            // Set combat_mode flag for other systems
            if(threat_level == "critical" || threat_level == "high")
                level.accessibility.combat_mode = true;
            else if(threat_level == "low" || threat_level == "none")
                level.accessibility.combat_mode = false;

            // Play threat level sound with count - on change or every 2 seconds
            if(threat_changed || (now - last_threat_time) > 2000)
            {
                self thread play_threat_sound(threat_level);
                zm_accessibility::queue_tts_message(count + " zombies, " + threat_level + " threat", "high");
                last_threat_level = threat_level;
                last_threat_time = now;
            }

            // Play direction - only on change or every 3 seconds
            if(direction != last_direction || (now - last_dir_time) > 3000)
            {
                wait 0.4;
                self thread play_direction_sound(direction);
                last_direction = direction;
                last_dir_time = GetTime();
            }

            // Rumble only on critical/high
            if(threat_level == "critical" || threat_level == "high")
            {
                self thread proximity_rumble(threat_level);
            }

            // Multi-directional behind warning
            if(count >= 3 && (now - last_behind_time) > 4000)
            {
                behind_count = count_zombies_behind(self, scan.zombies_in_range);
                if(behind_count > 0)
                {
                    zm_accessibility::queue_tts_message(behind_count + " behind you", "high");
                    last_behind_time = GetTime();
                }
            }

            // Swarm warning - max once every 5 seconds
            if(count >= 5 && (now - last_swarm_time) > 5000)
            {
                wait 0.3;
                zm_accessibility::queue_tts_message("Surrounded", "critical");
                last_swarm_time = GetTime();
            }
        }
        else
        {
            // All clear - announce once when transitioning from threat
            if(last_threat_level != "none" && (now - last_clear_time) > 5000)
            {
                zm_accessibility::queue_tts_message("All clear", "medium");
                last_threat_level = "none";
                self.accessibility.current_threat = "none";
                self.accessibility.threat_stable_count = 0;
                level.accessibility.combat_mode = false;
                last_clear_time = now;
            }
        }

        // Update rate: check frequently but sounds are gated by cooldowns
        if(last_threat_level == "critical")
            wait 0.8;
        else if(last_threat_level == "high")
            wait 1.0;
        else if(last_threat_level == "medium")
            wait 1.5;
        else
            wait 2.0;
    }
}

// Round-scaled detection range
function get_scan_range()
{
    range = 600;
    if(IsDefined(level.round_number))
    {
        if(level.round_number > 20)
            range = 800;
        else if(level.round_number > 10)
            range = 700;
    }
    return range;
}

// Proximity scan using shared zombie cache, with special enemy classification
// Returns struct with .count, .nearest_origin (cached), .nearest_dist, .has_dogs, .has_boss, .zombies_in_range
function proximity_scan(range)
{
    result = SpawnStruct();
    result.count = 0;
    result.nearest_origin = undefined;
    result.nearest_dist = range + 1;
    result.has_dogs = false;
    result.has_boss = false;
    result.zombies_in_range = [];

    // Use shared zombie cache, fallback to GetAITeamArray
    zombies = level.accessibility.zombie_cache;
    if(!IsDefined(zombies) || zombies.size == 0)
        zombies = GetAITeamArray("axis");

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
            result.zombies_in_range[result.zombies_in_range.size] = zombie;

            if(dist_sq < best_dist_sq)
            {
                best_dist_sq = dist_sq;
                result.nearest_origin = zombie.origin; // Cache origin at scan time
            }

            // Classify special enemies
            if(IsDefined(zombie.archetype))
            {
                arch = ToLower(zombie.archetype);
                if(IsSubStr(arch, "dog"))
                    result.has_dogs = true;
                if(IsSubStr(arch, "margwa") || IsSubStr(arch, "panzer") || IsSubStr(arch, "thrasher"))
                    result.has_boss = true;
            }
        }
    }

    // Compute real distance for nearest only
    if(IsDefined(result.nearest_origin))
        result.nearest_dist = Distance(player_pos, result.nearest_origin);

    return result;
}

// Weighted threat formula using distance + count scoring
function get_threat_level(nearest_dist, zombie_count, max_range)
{
    threat_score = (max_range - nearest_dist) + (zombie_count * 40);

    if(nearest_dist < 100 || threat_score > 700)
        return "critical";
    if(nearest_dist < 250 || threat_score > 450)
        return "high";
    if(nearest_dist < 400 || threat_score > 250)
        return "medium";
    return "low";
}

// Count zombies behind the player using dot product
function count_zombies_behind(player, zombies)
{
    behind = 0;
    angles = player GetPlayerAngles();
    forward = AnglesToForward(angles);
    player_pos = player.origin;

    foreach(zombie in zombies)
    {
        if(!IsAlive(zombie))
            continue;

        to_zombie = VectorNormalize(zombie.origin - player_pos);
        dot = VectorDot(to_zombie, forward);
        if(dot < -0.5)
            behind++;
    }
    return behind;
}

function play_threat_sound(threat_level)
{
    switch(threat_level)
    {
        case "critical":
            self PlayLocalSound("aud_acc_threat_critical");
            break;
        case "high":
            self PlayLocalSound("aud_acc_threat_high");
            break;
        case "medium":
            self PlayLocalSound("aud_acc_threat_medium");
            break;
        case "low":
            self PlayLocalSound("aud_acc_threat_low");
            break;
    }
}

function play_direction_sound(direction)
{
    // Map 8-direction strings to nearest cardinal for sound playback
    // (only 4 directional sound aliases exist)
    sound_dir = direction;
    if(direction == "front-left" || direction == "front-right")
        sound_dir = "front";
    else if(direction == "behind-left" || direction == "behind-right")
        sound_dir = "behind";

    switch(sound_dir)
    {
        case "front":
            self PlayLocalSound("aud_acc_dir_front");
            break;
        case "behind":
            self PlayLocalSound("aud_acc_dir_behind");
            break;
        case "left":
            self PlayLocalSound("aud_acc_dir_left");
            break;
        case "right":
            self PlayLocalSound("aud_acc_dir_right");
            break;
    }
}

function proximity_rumble(threat_level)
{
    switch(threat_level)
    {
        case "critical":
            self PlayRumbleOnEntity("damage_heavy");
            wait 0.15;
            self StopRumble("damage_heavy");
            break;
        case "high":
            self PlayRumbleOnEntity("damage_light");
            wait 0.1;
            self StopRumble("damage_light");
            break;
    }
}
