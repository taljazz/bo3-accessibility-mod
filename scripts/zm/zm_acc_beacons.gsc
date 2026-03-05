#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_beacons;

/*
    Interactable Object Audio Beacon System

    Provides blind players with navigation to interactables:
    - TTS announces object type + direction with every beep pulse
    - 3D beep plays AT the object so the player hears spatial direction
    - Beep pitch/volume indicates distance (high+loud = close, low+quiet = far)
    - Uses a persistent sound entity to prevent entity exhaustion / sound cutouts

    Object types detected:
    - Perk machines, GobbleGum machine, Wall buys, Mystery Box
    - Doors / debris, Power switch, Pack-a-Punch
    - Zombie barriers/windows, Traps

    Beacon modes (cycle with F7 key via dvar acc_beacon_mode):
    - all: beacon everything
    - perks: perk machines, gobblegum, pack-a-punch
    - weapons: wall buys, mystery box
    - navigation: doors, power, barriers, traps
    - off: no beacons
*/

function interactable_beacon_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    // Wait for map to fully load entities
    wait 3.0;

    // Cache static entity arrays
    self.accessibility.cached_perks = GetEntArray("zombie_vending", "targetname");

    // Wall buys: try structs first (BO3 standard), then entity fallback
    self.accessibility.cached_wallbuys = struct::get_array("weapon_upgrade", "targetname");
    if(!IsDefined(self.accessibility.cached_wallbuys) || self.accessibility.cached_wallbuys.size == 0)
        self.accessibility.cached_wallbuys = GetEntArray("weapon_upgrade", "targetname");

    // Doors: combine zombie_door + zombie_debris (maps use both)
    doors = GetEntArray("zombie_door", "targetname");
    debris = GetEntArray("zombie_debris", "targetname");
    self.accessibility.cached_doors = [];
    if(IsDefined(doors))
    {
        foreach(d in doors)
            self.accessibility.cached_doors[self.accessibility.cached_doors.size] = d;
    }
    if(IsDefined(debris))
    {
        foreach(d in debris)
            self.accessibility.cached_doors[self.accessibility.cached_doors.size] = d;
    }

    self.accessibility.cached_power = GetEnt("use_elec_switch", "targetname");
    self.accessibility.cached_pap = GetEnt("opack_a_punch", "targetname");
    if(!IsDefined(self.accessibility.cached_pap))
        self.accessibility.cached_pap = GetEnt("pack_a_punch", "targetname");

    // GobbleGum machines
    self.accessibility.cached_bgb = GetEntArray("bgb_machine_use", "targetname");

    // Zombie barriers / windows (struct-based)
    self.accessibility.cached_barriers = struct::get_array("exterior_goal", "targetname");

    // Traps
    self.accessibility.cached_traps = GetEntArray("zombie_trap", "targetname");

    // Spawn ONE persistent sound entity -- reuse it to avoid entity exhaustion
    // Guard against double-spawn
    if(IsDefined(self.accessibility.beacon_ent))
        self.accessibility.beacon_ent Delete();
    self.accessibility.beacon_ent = Spawn("script_origin", self.origin);
    self thread _beacon_cleanup_on_death();

    // Initialize beacon mode
    if(!IsDefined(self.accessibility.beacon_mode))
        self.accessibility.beacon_mode = "all";

    // Initialize TTS dedup tracker
    self.accessibility.last_beacon_msg = "";

    last_type = "";

    while(true)
    {
        // Re-spawn beacon_ent if it went missing
        if(!IsDefined(self.accessibility.beacon_ent))
        {
            self.accessibility.beacon_ent = Spawn("script_origin", self.origin);
            self thread _beacon_cleanup_on_death();
        }

        // Check if beacons are off
        if(self.accessibility.beacon_mode == "off")
        {
            wait 1.0;
            continue;
        }

        result = self find_nearest_interactable();

        if(IsDefined(result))
        {
            obj_type = result.type;
            obj_origin = result.origin;
            obj_dist = result.dist;

            // Get direction relative to player
            direction = self zm_accessibility::get_relative_direction(obj_origin);

            // Get proximity tier
            proximity = get_proximity_tier(obj_dist);

            // Build TTS message
            friendly_name = result.friendly_name;
            if(!IsDefined(friendly_name))
                friendly_name = get_friendly_name(obj_type);
            new_msg = friendly_name + ", " + direction;

            // Combat mode: skip TTS but still play 3D beep for spatial orientation
            in_combat = IsDefined(level.accessibility) && IsDefined(level.accessibility.combat_mode) && level.accessibility.combat_mode;

            if(!in_combat)
            {
                // TTS dedup: only send when message changes
                if(!IsDefined(self.accessibility.last_beacon_msg) || new_msg != self.accessibility.last_beacon_msg)
                {
                    if(IsDefined(level.accessibility) && IsDefined(level.accessibility.tts_queue))
                        zm_accessibility::queue_tts_message(new_msg, "low");
                    else
                        zm_accessibility::send_tts_message(new_msg);
                    self.accessibility.last_beacon_msg = new_msg;
                }
            }

            // Move persistent entity to object position and play 3D beep
            if(IsDefined(self.accessibility.beacon_ent))
            {
                self.accessibility.beacon_ent.origin = obj_origin;
                if(proximity == "close")
                    self.accessibility.beacon_ent PlaySound("aud_acc_beacon_close");
                else if(proximity == "near")
                    self.accessibility.beacon_ent PlaySound("aud_acc_beacon_near");
                else
                    self.accessibility.beacon_ent PlaySound("aud_acc_beacon_far");
            }

            last_type = obj_type;

            // Tight pulse rate for navigation lock-on
            if(proximity == "close")
                wait 1.5;
            else if(proximity == "near")
                wait 2.5;
            else
                wait 3.5;
        }
        else
        {
            // Nothing in range -- reset
            if(last_type != "")
            {
                last_type = "";
                self.accessibility.last_beacon_msg = "";
            }

            wait 4.0;
        }
    }
}

// ============================================
// BEACON ENTITY CLEANUP
// ============================================

function _beacon_cleanup_on_death()
{
    self endon("disconnect");
    self waittill("death");
    if(IsDefined(self.accessibility.beacon_ent))
        self.accessibility.beacon_ent Delete();
}

// Returns true if the given object type passes the current beacon mode filter
function is_type_in_mode(obj_type, mode)
{
    if(mode == "all")
        return true;

    if(mode == "perks")
        return (obj_type == "perk" || obj_type == "gobblegum" || obj_type == "pap");

    if(mode == "weapons")
        return (obj_type == "wallbuy" || obj_type == "box");

    if(mode == "navigation")
        return (obj_type == "door" || obj_type == "power" || obj_type == "barrier" || obj_type == "trap");

    return false;
}

// ============================================
// FIND NEAREST INTERACTABLE
// Returns struct with .type, .origin, .dist, .friendly_name or undefined
// ============================================

function find_nearest_interactable()
{
    best_dist_sq = 99999 * 99999;
    best_type = undefined;
    best_origin = undefined;
    best_friendly = undefined;
    found = false;
    player_pos = self.origin;
    mode = self.accessibility.beacon_mode;

    // --- Perk machines (range 1500) ---
    if(is_type_in_mode("perk", mode))
    {
        range_sq = 1500 * 1500;
        if(IsDefined(self.accessibility.cached_perks))
        {
            foreach(perk in self.accessibility.cached_perks)
            {
                if(!IsDefined(perk) || !IsDefined(perk.origin))
                    continue;
                // Skip perks the player already owns
                if(IsDefined(perk.script_noteworthy) && self HasPerk(perk.script_noteworthy))
                    continue;
                dist_sq = DistanceSquared(player_pos, perk.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "perk";
                    best_origin = perk.origin;
                    best_friendly = get_perk_display_name(perk.script_noteworthy);
                    found = true;
                }
            }
        }
    }

    // --- Wall buys (range 800) ---
    if(is_type_in_mode("wallbuy", mode))
    {
        range_sq = 800 * 800;
        if(IsDefined(self.accessibility.cached_wallbuys))
        {
            foreach(wb in self.accessibility.cached_wallbuys)
            {
                if(!IsDefined(wb) || !IsDefined(wb.origin))
                    continue;
                dist_sq = DistanceSquared(player_pos, wb.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "wallbuy";
                    best_origin = wb.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- Mystery box (use level.chests -- the stock BO3 system) ---
    if(is_type_in_mode("box", mode))
    {
        if(IsDefined(level.chests) && IsDefined(level.chest_index))
        {
            active_chest = level.chests[level.chest_index];
            if(IsDefined(active_chest) && IsDefined(active_chest.origin))
            {
                // Only beacon if the box is not hidden (hidden == 0 or undefined means visible)
                is_hidden = false;
                if(IsDefined(active_chest.hidden) && active_chest.hidden)
                    is_hidden = true;

                if(!is_hidden)
                {
                    range_sq = 1500 * 1500;
                    dist_sq = DistanceSquared(player_pos, active_chest.origin);
                    if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                    {
                        best_dist_sq = dist_sq;
                        best_type = "box";
                        best_origin = active_chest.origin;
                        best_friendly = undefined;
                        found = true;
                    }
                }
            }
        }
    }

    // --- Doors / debris (range 500) ---
    if(is_type_in_mode("door", mode))
    {
        range_sq = 500 * 500;
        if(IsDefined(self.accessibility.cached_doors))
        {
            foreach(door in self.accessibility.cached_doors)
            {
                if(!IsDefined(door) || !IsDefined(door.origin))
                    continue;
                // Skip opened doors
                if(IsDefined(door._door_open) && door._door_open)
                    continue;
                dist_sq = DistanceSquared(player_pos, door.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "door";
                    best_origin = door.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- Power switch (range 1500, only when power is off) ---
    if(is_type_in_mode("power", mode))
    {
        if(IsDefined(self.accessibility.cached_power) && IsDefined(self.accessibility.cached_power.origin))
        {
            power_on = false;
            if(IsDefined(level.zombie_vars) && IsDefined(level.zombie_vars["electric_switch"]))
                power_on = level.zombie_vars["electric_switch"];

            if(!power_on)
            {
                range_sq = 1500 * 1500;
                dist_sq = DistanceSquared(player_pos, self.accessibility.cached_power.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "power";
                    best_origin = self.accessibility.cached_power.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- Pack-a-Punch (range 1500, gated behind power) ---
    if(is_type_in_mode("pap", mode))
    {
        if(IsDefined(self.accessibility.cached_pap) && IsDefined(self.accessibility.cached_pap.origin))
        {
            // Only beacon PaP when power is on
            power_on = true;
            if(IsDefined(level.zombie_vars) && IsDefined(level.zombie_vars["electric_switch"]) && !level.zombie_vars["electric_switch"])
                power_on = false;

            if(power_on)
            {
                range_sq = 1500 * 1500;
                dist_sq = DistanceSquared(player_pos, self.accessibility.cached_pap.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "pap";
                    best_origin = self.accessibility.cached_pap.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- GobbleGum machines (range 1200) ---
    if(is_type_in_mode("gobblegum", mode))
    {
        range_sq = 1200 * 1200;
        if(IsDefined(self.accessibility.cached_bgb))
        {
            foreach(bgb in self.accessibility.cached_bgb)
            {
                if(!IsDefined(bgb) || !IsDefined(bgb.origin))
                    continue;
                dist_sq = DistanceSquared(player_pos, bgb.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "gobblegum";
                    best_origin = bgb.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- Zombie barriers / windows (range 400) ---
    if(is_type_in_mode("barrier", mode))
    {
        range_sq = 400 * 400;
        if(IsDefined(self.accessibility.cached_barriers))
        {
            foreach(barrier in self.accessibility.cached_barriers)
            {
                if(!IsDefined(barrier) || !IsDefined(barrier.origin))
                    continue;
                dist_sq = DistanceSquared(player_pos, barrier.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "barrier";
                    best_origin = barrier.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // --- Traps (range 800) ---
    if(is_type_in_mode("trap", mode))
    {
        range_sq = 800 * 800;
        if(IsDefined(self.accessibility.cached_traps))
        {
            foreach(trap in self.accessibility.cached_traps)
            {
                if(!IsDefined(trap) || !IsDefined(trap.origin))
                    continue;
                dist_sq = DistanceSquared(player_pos, trap.origin);
                if(dist_sq < best_dist_sq && dist_sq <= range_sq)
                {
                    best_dist_sq = dist_sq;
                    best_type = "trap";
                    best_origin = trap.origin;
                    best_friendly = undefined;
                    found = true;
                }
            }
        }
    }

    // Build result struct only for the winner
    if(found)
    {
        best = SpawnStruct();
        best.type = best_type;
        best.origin = best_origin;
        best.dist = Distance(player_pos, best_origin);
        if(IsDefined(best_friendly))
            best.friendly_name = best_friendly;
        return best;
    }

    return undefined;
}

// ============================================
// HELPERS
// ============================================

function get_proximity_tier(dist)
{
    if(dist < 200)
        return "close";
    else if(dist < 600)
        return "near";
    else
        return "far";
}

function get_friendly_name(obj_type)
{
    switch(obj_type)
    {
        case "perk":      return "Perk";
        case "wallbuy":   return "Wall weapon";
        case "box":       return "Mystery Box";
        case "door":      return "Door";
        case "power":     return "Power switch";
        case "pap":       return "Pack a Punch";
        case "gobblegum": return "GobbleGum";
        case "barrier":   return "Barrier";
        case "trap":      return "Trap";
        default:          return "Object";
    }
}

function get_perk_display_name(script_noteworthy)
{
    if(!IsDefined(script_noteworthy))
        return "Perk";

    switch(script_noteworthy)
    {
        case "specialty_armorvest":                return "Juggernog";
        case "specialty_quickrevive":              return "Quick Revive";
        case "specialty_fastreload":               return "Speed Cola";
        case "specialty_staminup":                 return "Staminup";
        case "specialty_deadshot":                 return "Deadshot";
        case "specialty_widowswine":               return "Widow's Wine";
        case "specialty_rof":                      return "Double Tap";
        case "specialty_additionalprimaryweapon":  return "Mule Kick";
        default:                                   return "Perk";
    }
}
