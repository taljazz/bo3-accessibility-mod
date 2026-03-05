#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;
#using scripts\zm\zm_acc_menus;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_gamestate;

/*
    Game State Audio Announcements

    Keeps blind players informed about:
    - Health status (warning when low, critical alerts)
    - Point balance (milestones + periodic)
    - Ammo status (low ammo, empty magazine, weapon dry)
    - Weapon switches and pickups
    - Powerup pickups (Max Ammo, Double Points, Insta-Kill, Nuke, etc.)
    - Player downed/revived state
    - Perk gains and losses
    - Dog rounds and special rounds
    - Zombie count remaining
    - Power switch activation

    All announcements have cooldowns to prevent spam.
*/

// ============================================
// HEALTH MONITORING
// ============================================

function health_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_health_state = "full";

    while(true)
    {
        if(IsDefined(self.health) && IsDefined(self.maxhealth) && self.maxhealth > 0)
        {
            health_pct = Int((self.health / self.maxhealth) * 100);
            current_state = get_health_state(health_pct);

            // Only announce on state CHANGE to avoid spam
            if(current_state != last_health_state)
            {
                self thread announce_health_state(current_state);
                last_health_state = current_state;
            }
        }

        wait 0.5;
    }
}

function get_health_state(health_pct)
{
    if(health_pct <= 25)
        return "critical";
    else if(health_pct <= 50)
        return "warning";
    else
        return "full";
}

function announce_health_state(state)
{
    switch(state)
    {
        case "critical":
            self PlayLocalSound("aud_acc_threat_critical");
            wait 0.15;
            zm_accessibility::queue_tts_message("Health critical", "critical");
            self PlayRumbleOnEntity("damage_heavy");
            wait 0.5;
            self StopRumble("damage_heavy");
            break;
        case "warning":
            zm_accessibility::queue_tts_message("Health low", "high");
            break;
        case "full":
            zm_accessibility::queue_tts_message("Health recovered", "low");
            break;
    }
}

// ============================================
// POINTS MONITORING
// ============================================

function points_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_points = 0;
    last_announce_time = GetTime();
    last_milestone = 0;

    // Wait a moment for score to initialize
    wait 1.0;

    if(IsDefined(self.score))
        last_points = self.score;

    while(true)
    {
        if(IsDefined(self.score))
        {
            current_points = self.score;

            // Check for point milestones (every 1000 points)
            current_milestone = Int(current_points / 1000) * 1000;
            if(current_milestone > last_milestone && current_milestone > 0)
            {
                zm_accessibility::queue_tts_message(current_milestone + " points", "low");
                self PlayRumbleOnEntity("damage_light");
                wait 0.2;
                self StopRumble("damage_light");
                last_milestone = current_milestone;
                last_announce_time = GetTime();
            }

            // Periodic announcement using configurable interval
            interval = 45000;
            if(IsDefined(level.accessibility) && IsDefined(level.accessibility.points_interval))
                interval = level.accessibility.points_interval;

            if(GetTime() - last_announce_time > interval)
            {
                zm_accessibility::queue_tts_message(current_points + " points", "low");
                last_announce_time = GetTime();
            }

            last_points = current_points;
        }

        wait 2.0;
    }
}

// ============================================
// AMMO MONITORING
// ============================================

function ammo_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_ammo_state = "";
    last_ammo_announce = 0;
    last_weapon = undefined;

    while(true)
    {
        weapon = self GetCurrentWeapon();

        if(IsDefined(weapon) && weapon != level.weaponNone)
        {
            // Reset ammo state on weapon switch so new weapon is immediately evaluated
            if(IsDefined(last_weapon) && weapon != last_weapon)
            {
                last_ammo_state = "";
            }
            last_weapon = weapon;

            clip_ammo = self GetWeaponAmmoClip(weapon);
            stock_ammo = self GetWeaponAmmoStock(weapon);

            current_state = get_ammo_state(weapon, clip_ammo, stock_ammo);
            now = GetTime();

            // Only announce on state change, with minimum 2s between announcements
            if(current_state != last_ammo_state && (now - last_ammo_announce) > 2000)
            {
                self thread announce_ammo_state(current_state);
                last_ammo_state = current_state;
                last_ammo_announce = now;
            }
        }

        wait 1.0;
    }
}

function get_ammo_state(weapon, clip_ammo, stock_ammo)
{
    if(clip_ammo == 0 && stock_ammo == 0)
        return "empty";
    else if(clip_ammo == 0)
        return "reload";

    // Percentage-based thresholds using weapon.maxammo
    max_ammo = weapon.maxammo;
    if(IsDefined(max_ammo) && max_ammo > 0)
    {
        pct = Int((stock_ammo * 100) / max_ammo);
        if(stock_ammo == 0 && clip_ammo <= 8)
            return "last_clip_low";
        else if(pct <= 10)
            return "low_reserve";
        else
            return "full";
    }

    // Fallback absolute thresholds
    if(stock_ammo == 0 && clip_ammo <= 8)
        return "last_clip_low";
    else if(stock_ammo > 0 && stock_ammo <= 20)
        return "low_reserve";
    else
        return "full";
}

function announce_ammo_state(state)
{
    switch(state)
    {
        case "empty":
            self PlayLocalSound("aud_acc_threat_high");
            wait 0.15;
            zm_accessibility::queue_tts_message("Out of ammo", "critical");
            self PlayRumbleOnEntity("damage_heavy");
            wait 0.3;
            self StopRumble("damage_heavy");
            break;
        case "reload":
            zm_accessibility::queue_tts_message("Reload", "medium");
            break;
        case "last_clip_low":
            self PlayLocalSound("aud_acc_threat_high");
            wait 0.15;
            zm_accessibility::queue_tts_message("Ammo critical", "critical");
            break;
        case "critical_reserve":
            zm_accessibility::queue_tts_message("Ammo very low", "high");
            break;
        case "low_reserve":
            zm_accessibility::queue_tts_message("Ammo low", "medium");
            break;
    }
}

// ============================================
// WEAPON SWITCH / PICKUP MONITORING
// ============================================

function weapon_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_weapon = self GetCurrentWeapon();

    while(true)
    {
        weapon = self GetCurrentWeapon();

        if(IsDefined(weapon) && weapon != level.weaponNone)
        {
            if(!IsDefined(last_weapon) || weapon != last_weapon)
            {
                display_name = zm_acc_menus::clean_weapon_name(weapon);

                if(display_name != "weapon")
                    zm_accessibility::queue_tts_message("Weapon: " + display_name, "medium");

                last_weapon = weapon;
            }
        }

        wait 0.5;
    }
}

// ============================================
// PLAYER DOWNED / REVIVED DETECTION
// ============================================

function downed_monitor_think()
{
    self endon("disconnect");
    self endon("acc_restart");

    while(true)
    {
        self waittill("player_downed");

        // Announce downed state to this player
        self PlayLocalSound("aud_acc_threat_critical");
        wait 0.15;
        zm_accessibility::queue_tts_message("You are down", "critical");

        // In co-op, announce to other players with direction
        players = GetPlayers();
        if(players.size > 1)
        {
            foreach(player in players)
            {
                if(player == self)
                    continue;
                if(!IsAlive(player))
                    continue;

                direction = player zm_accessibility::get_relative_direction(self.origin);
                zm_accessibility::queue_tts_message("Player down, " + direction, "critical");
            }
        }

        // Now wait for revive or respawn
        self thread wait_for_revive();
    }
}

function wait_for_revive()
{
    self endon("disconnect");
    self endon("acc_restart");

    // Wait for player to be alive and no longer in laststand
    while(true)
    {
        wait 0.5;

        // Player revived: they are alive and no longer in laststand/downed
        if(IsAlive(self) && (!IsDefined(self.laststand) || !self.laststand))
        {
            zm_accessibility::queue_tts_message("You have been revived", "high");

            // Announce perk status since perks are lost on down
            wait 0.5;
            perk_count = 0;
            if(IsDefined(self.num_perks))
                perk_count = self.num_perks;

            if(perk_count == 0)
                zm_accessibility::queue_tts_message("All perks lost", "high");
            else
                zm_accessibility::queue_tts_message(perk_count + " perks remaining", "medium");

            return;
        }
    }
}

// ============================================
// PERK MONITORING
// ============================================

function perk_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_perk_count = 0;
    if(IsDefined(self.num_perks))
        last_perk_count = self.num_perks;

    // Known perk mappings for name announcements
    perk_display_names = [];
    perk_display_names["specialty_quickrevive"] = "Quick Revive";
    perk_display_names["specialty_fastreload"] = "Speed Cola";
    perk_display_names["specialty_rof"] = "Double Tap";
    perk_display_names["specialty_longersprint"] = "Stamin-Up";
    perk_display_names["specialty_armorvest"] = "Juggernog";
    perk_display_names["specialty_deadshot"] = "Deadshot";
    perk_display_names["specialty_additionalprimaryweapon"] = "Mule Kick";
    perk_display_names["specialty_nomotionsensor"] = "Widows Wine";
    perk_display_names["specialty_scavenger"] = "Electric Cherry";

    // Track which perks the player currently has
    last_perks = [];

    while(true)
    {
        current_count = 0;
        if(IsDefined(self.num_perks))
            current_count = self.num_perks;

        if(current_count != last_perk_count)
        {
            if(current_count > last_perk_count)
            {
                // Player gained a perk - try to identify which one
                perk_keys = GetArrayKeys(perk_display_names);
                foreach(perk in perk_keys)
                {
                    if(self HasPerk(perk) && !IsDefined(last_perks[perk]))
                    {
                        zm_accessibility::queue_tts_message(perk_display_names[perk], "medium");
                        last_perks[perk] = true;
                    }
                }
            }
            else if(current_count == 0 && last_perk_count > 0)
            {
                // Lost all perks (typically from going down)
                // Note: downed_monitor also announces this, but this catches edge cases
                last_perks = [];
            }
            else if(current_count < last_perk_count)
            {
                // Lost some perks - refresh tracking
                perk_keys = GetArrayKeys(perk_display_names);
                foreach(perk in perk_keys)
                {
                    if(IsDefined(last_perks[perk]) && !self HasPerk(perk))
                    {
                        zm_accessibility::queue_tts_message("Lost " + perk_display_names[perk], "high");
                        last_perks[perk] = undefined;
                    }
                }
            }

            last_perk_count = current_count;
        }

        wait 1.0;
    }
}

// ============================================
// SPECIAL ROUND DETECTION (Dog rounds, etc.)
// ============================================

function special_round_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_dog_round_announced = 0;

    while(true)
    {
        if(IsDefined(level.zombie_vars) && IsDefined(level.round_number))
        {
            // Dog round detection
            is_dog_round = false;
            if(IsDefined(level.zombie_vars["zombie_dog_round"]))
                is_dog_round = level.zombie_vars["zombie_dog_round"];

            if(is_dog_round && last_dog_round_announced != level.round_number)
            {
                zm_accessibility::queue_tts_message("Dog round", "critical");
                last_dog_round_announced = level.round_number;
            }
        }

        wait 2.0;
    }
}

// ============================================
// ZOMBIE COUNT TRACKING
// ============================================

function zombie_count_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    last_threshold_announced = 0;
    last_count_check = 0;

    while(true)
    {
        // Count zombies: spawned alive + yet to spawn
        alive_count = 0;
        zombies = level.accessibility.zombie_cache;
        if(IsDefined(zombies))
            alive_count = zombies.size;

        remaining_to_spawn = 0;
        if(IsDefined(level.zombie_total))
            remaining_to_spawn = level.zombie_total;

        total_remaining = alive_count + remaining_to_spawn;

        // Announce at key thresholds (only once per threshold per direction)
        if(total_remaining != last_threshold_announced)
        {
            if(total_remaining == 1)
            {
                zm_accessibility::queue_tts_message("Last zombie", "high");
                last_threshold_announced = total_remaining;
            }
            else if(total_remaining == 5 && last_threshold_announced > 5)
            {
                zm_accessibility::queue_tts_message("5 zombies remaining", "medium");
                last_threshold_announced = total_remaining;
            }
            else if(total_remaining == 10 && last_threshold_announced > 10)
            {
                zm_accessibility::queue_tts_message("10 zombies remaining", "medium");
                last_threshold_announced = total_remaining;
            }
            else if(total_remaining == 20 && last_threshold_announced > 20)
            {
                zm_accessibility::queue_tts_message("20 zombies remaining", "medium");
                last_threshold_announced = total_remaining;
            }
        }

        // Reset threshold tracking at round start (high count means new round)
        if(total_remaining > 25)
            last_threshold_announced = total_remaining;

        wait 10.0;
    }
}

// ============================================
// POWER ON DETECTION
// ============================================

function power_monitor_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    power_announced = false;

    while(true)
    {
        if(!power_announced)
        {
            power_on = false;

            // Check the standard zombie_vars electric_switch flag
            if(IsDefined(level.zombie_vars) && IsDefined(level.zombie_vars["electric_switch"]))
                power_on = level.zombie_vars["electric_switch"];

            // Alternative: check level flag used by some maps
            if(!power_on && IsDefined(level.electric_switch) && level.electric_switch)
                power_on = true;

            if(power_on)
            {
                self PlayLocalSound("aud_acc_threat_critical");
                wait 0.15;
                zm_accessibility::queue_tts_message("Power is on", "critical");
                power_announced = true;
            }
        }

        wait 2.0;
    }
}

// ============================================
// POWERUP MONITORING (level-scope, not per-player)
// ============================================

// Monitors level.zombie_vars for powerup activation
// Runs at level scope so it fires once per powerup, not per-player
function powerup_monitor_think()
{
    level endon("end_game");

    // Wait for zombie_vars to be initialized by the map
    wait 5.0;

    // Track active state of each powerup we care about
    // Keys: zombie_vars key name, Values: friendly TTS name
    powerup_names = [];
    powerup_names["zombie_powerup_insta_kill_on"] = "Insta Kill";
    powerup_names["zombie_powerup_double_points_on"] = "Double Points";
    powerup_names["zombie_powerup_fire_sale_on"] = "Fire Sale";
    powerup_names["zombie_powerup_full_ammo_on"] = "Max Ammo";
    powerup_names["zombie_powerup_nuke_on"] = "Nuke";
    powerup_names["zombie_powerup_carpenter_on"] = "Carpenter";
    powerup_names["zombie_powerup_free_perk_on"] = "Free Perk";

    // Track previous states so we only announce on activation
    prev_states = [];
    keys = GetArrayKeys(powerup_names);
    foreach(key in keys)
    {
        prev_states[key] = false;
    }

    while(true)
    {
        if(IsDefined(level.zombie_vars))
        {
            // BO3 zombie_vars are team-indexed: level.zombie_vars[team][key]
            // Try team-indexed first (stock pattern), fall back to direct access
            foreach(key in keys)
            {
                is_active = false;
                if(IsDefined(level.zombie_vars["axis"]) && IsDefined(level.zombie_vars["axis"][key]))
                    is_active = level.zombie_vars["axis"][key];
                else if(IsDefined(level.zombie_vars[key]))
                    is_active = level.zombie_vars[key];

                // Announce on activation (false -> true transition)
                if(is_active && !prev_states[key])
                {
                    zm_accessibility::queue_tts_message(powerup_names[key], "high");
                }

                prev_states[key] = is_active;
            }
        }

        wait 0.5;
    }
}
