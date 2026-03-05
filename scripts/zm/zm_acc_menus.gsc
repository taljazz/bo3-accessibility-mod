#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_menus;

/*
    Menu / Purchase Prompt TTS Reading

    Since BO3 menus (pause, GobbleGum selection, scoreboard) are entirely
    client-side LUI and cannot be read from server GSC, this module instead
    detects when the player is standing inside a purchasable trigger zone
    and announces what it is via TTS — effectively "reading" the hint
    string the engine would display visually.

    Detected prompts:
    - Wall buys: weapon name + cost (or "ammo" if already owned)
    - Perk machines: perk name + cost
    - Mystery Box: cost (950 / 10 fire sale)
    - Doors / debris: type + cost
    - Pack-a-Punch: cost
    - Power switch: on/off state
    - GobbleGum machine: cost
    - Revive: downed teammate nearby

    Uses IsTouching() polling with dedup to avoid spamming the same prompt.
    Toggle with F8 key (acc_menu_reading dvar).
*/

// ============================================
// MAIN THINK LOOP (per-player, called from main on_player_spawned)
// ============================================

function menu_prompt_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    // Wait for map entities to load
    wait 3.5;

    // Cache all trigger entities we care about
    triggers = cache_prompt_triggers();

    // Track which trigger we last announced to prevent spam
    last_announced_trigger = undefined;
    last_announced_time = 0;

    // Minimum time before re-announcing the same trigger after leaving and returning
    reannounce_cooldown = 5000; // 5 seconds

    while(true)
    {
        // Check if menu reading is enabled
        if(GetDvarInt("acc_menu_reading", 1) == 0)
        {
            wait 1.0;
            continue;
        }

        // Check master mod enabled
        if(IsDefined(level.accessibility) && !level.accessibility.enabled)
        {
            wait 1.0;
            continue;
        }

        // Scan all cached triggers for one the player is touching
        current_trigger = undefined;
        current_msg = undefined;
        current_priority = "medium";

        for(i = 0; i < triggers.size; i++)
        {
            t = triggers[i];

            if(!IsDefined(t) || !IsDefined(t.ent))
                continue;

            // Skip if entity was deleted (door opened, etc.)
            if(!IsDefined(t.ent.origin))
                continue;

            // IsTouching check
            if(self IsTouching(t.ent))
            {
                result = self build_prompt_message(t);
                if(IsDefined(result))
                {
                    current_trigger = t;
                    current_msg = result.msg;
                    if(IsDefined(result.priority))
                        current_priority = result.priority;
                    break; // first match wins (player can only interact with one at a time)
                }
            }
        }

        // Check mystery box (uses distance, not IsTouching, since box triggers are dynamic)
        if(!IsDefined(current_trigger))
        {
            box_result = self check_box_prompt();
            if(IsDefined(box_result))
            {
                current_msg = box_result.msg;
                current_priority = box_result.priority;
                // Use string sentinel for box dedup
                current_trigger = "mystery_box";
            }
        }

        // Also check for downed teammates (revive prompt)
        if(!IsDefined(current_trigger))
        {
            revive_result = self check_revive_prompt();
            if(IsDefined(revive_result))
            {
                current_msg = revive_result.msg;
                current_priority = "high";
                // Use a sentinel for revive dedup
                current_trigger = revive_result.target;
            }
        }

        now = GetTime();

        if(IsDefined(current_msg))
        {
            // Dedup: only announce if this is a different trigger, or enough time passed
            should_announce = false;

            if(!IsDefined(last_announced_trigger))
            {
                should_announce = true;
            }
            else if(current_trigger != last_announced_trigger)
            {
                should_announce = true;
            }
            else if((now - last_announced_time) > reannounce_cooldown)
            {
                // Same trigger but enough time passed (player left and came back)
                should_announce = true;
            }

            if(should_announce)
            {
                zm_accessibility::queue_tts_message(current_msg, current_priority);
                last_announced_trigger = current_trigger;
                last_announced_time = now;
            }
        }
        else
        {
            // Player left all triggers — clear tracking so re-entry announces fresh
            if(IsDefined(last_announced_trigger))
                last_announced_trigger = undefined;
        }

        wait 0.3;
    }
}

// ============================================
// TRIGGER CACHING
// ============================================

function cache_prompt_triggers()
{
    triggers = [];

    // --- Wall buy triggers ---
    // Wall buys use use_triggers linked to weapon_upgrade structs
    wallbuy_trigs = GetEntArray("weapon_upgrade", "targetname");
    if(IsDefined(wallbuy_trigs))
    {
        foreach(wb in wallbuy_trigs)
        {
            t = SpawnStruct();
            t.ent = wb;
            t.type = "wallbuy";
            triggers[triggers.size] = t;
        }
    }

    // --- Perk machine triggers ---
    perk_trigs = GetEntArray("zombie_vending", "targetname");
    if(IsDefined(perk_trigs))
    {
        foreach(p in perk_trigs)
        {
            t = SpawnStruct();
            t.ent = p;
            t.type = "perk";
            triggers[triggers.size] = t;
        }
    }

    // --- Mystery box triggers ---
    // Box triggers are dynamic — check level.chests each frame instead of caching
    // We'll handle box in build_prompt_message via level.chests

    // --- Door / debris triggers ---
    door_trigs = GetEntArray("zombie_door", "targetname");
    if(IsDefined(door_trigs))
    {
        foreach(d in door_trigs)
        {
            t = SpawnStruct();
            t.ent = d;
            t.type = "door";
            triggers[triggers.size] = t;
        }
    }
    debris_trigs = GetEntArray("zombie_debris", "targetname");
    if(IsDefined(debris_trigs))
    {
        foreach(d in debris_trigs)
        {
            t = SpawnStruct();
            t.ent = d;
            t.type = "debris";
            triggers[triggers.size] = t;
        }
    }

    // --- Power switch trigger ---
    power_trig = GetEnt("use_elec_switch", "targetname");
    if(IsDefined(power_trig))
    {
        t = SpawnStruct();
        t.ent = power_trig;
        t.type = "power";
        triggers[triggers.size] = t;
    }

    // --- Pack-a-Punch trigger ---
    pap_trig = GetEnt("opack_a_punch", "targetname");
    if(!IsDefined(pap_trig))
        pap_trig = GetEnt("pack_a_punch", "targetname");
    if(IsDefined(pap_trig))
    {
        t = SpawnStruct();
        t.ent = pap_trig;
        t.type = "pap";
        triggers[triggers.size] = t;
    }

    // --- GobbleGum machine triggers ---
    bgb_trigs = GetEntArray("bgb_machine_use", "targetname");
    if(IsDefined(bgb_trigs))
    {
        foreach(b in bgb_trigs)
        {
            t = SpawnStruct();
            t.ent = b;
            t.type = "gobblegum";
            triggers[triggers.size] = t;
        }
    }

    // --- Trap triggers ---
    trap_trigs = GetEntArray("zombie_trap", "targetname");
    if(IsDefined(trap_trigs))
    {
        foreach(tr in trap_trigs)
        {
            t = SpawnStruct();
            t.ent = tr;
            t.type = "trap";
            triggers[triggers.size] = t;
        }
    }

    return triggers;
}

// ============================================
// BUILD PROMPT MESSAGE FOR A TRIGGER
// Returns struct with .msg and .priority, or undefined to skip
// ============================================

function build_prompt_message(trigger_info)
{
    result = SpawnStruct();
    result.priority = "medium";

    switch(trigger_info.type)
    {
        case "wallbuy":
            return self build_wallbuy_prompt(trigger_info.ent);

        case "perk":
            return self build_perk_prompt(trigger_info.ent);

        case "door":
            return build_door_prompt(trigger_info.ent, "door");

        case "debris":
            return build_door_prompt(trigger_info.ent, "debris");

        case "power":
            return build_power_prompt();

        case "pap":
            return build_pap_prompt();

        case "gobblegum":
            return build_bgb_prompt();

        case "trap":
            return build_trap_prompt(trigger_info.ent);

        default:
            return undefined;
    }
}

// ============================================
// INDIVIDUAL PROMPT BUILDERS
// ============================================

function build_wallbuy_prompt(ent)
{
    result = SpawnStruct();
    result.priority = "medium";

    // Try to get weapon info from the entity
    weapon_name = "weapon";
    cost = 0;

    // Wall buy entities store weapon in script_noteworthy or weapon_name
    if(IsDefined(ent.zombie_weapon_upgrade))
    {
        weapon = ent.zombie_weapon_upgrade;
        if(IsString(weapon))
            weapon_name = weapon;
        else if(IsDefined(weapon.displayname) && weapon.displayname != "")
            weapon_name = weapon.displayname;
        else if(IsDefined(weapon.name))
            weapon_name = weapon.name;
    }
    else if(IsDefined(ent.script_noteworthy))
    {
        weapon_name = ent.script_noteworthy;
    }

    // Get cost
    if(IsDefined(ent.cost))
        cost = ent.cost;
    else if(IsDefined(ent.zombie_cost))
        cost = ent.zombie_cost;

    // Check if player already owns this weapon (announce ammo buy instead)
    is_ammo = false;
    current_weapons = self GetWeaponsList();
    if(IsDefined(current_weapons))
    {
        foreach(w in current_weapons)
        {
            w_name = "";
            if(IsString(w))
                w_name = w;
            else if(IsDefined(w.name))
                w_name = w.name;

            if(w_name == weapon_name || (IsDefined(ent.script_noteworthy) && w_name == ent.script_noteworthy))
            {
                is_ammo = true;
                break;
            }
        }
    }

    // Clean up weapon name for TTS (remove internal prefixes)
    display = clean_weapon_name(weapon_name);

    if(is_ammo)
    {
        if(cost > 0)
            result.msg = "Buy ammo, " + display + ", " + cost + " points";
        else
            result.msg = "Buy ammo, " + display;
    }
    else
    {
        if(cost > 0)
            result.msg = "Buy " + display + ", " + cost + " points";
        else
            result.msg = "Buy " + display;
    }

    return result;
}

function build_perk_prompt(ent)
{
    result = SpawnStruct();
    result.priority = "medium";

    perk_name = "Perk";
    cost = 0;

    // Perk machines store perk specialty in script_noteworthy
    if(IsDefined(ent.script_noteworthy))
    {
        perk_name = get_perk_display_name(ent.script_noteworthy);

        // Check if player already has this perk
        if(self HasPerk(ent.script_noteworthy))
        {
            // Don't announce — player already owns it
            return undefined;
        }
    }

    // Get cost from level._custom_perks or entity
    if(IsDefined(ent.cost))
        cost = ent.cost;
    else if(IsDefined(level._custom_perks) && IsDefined(ent.script_noteworthy) && IsDefined(level._custom_perks[ent.script_noteworthy]))
        cost = level._custom_perks[ent.script_noteworthy].cost;

    // Check if power is needed and off
    power_on = is_power_on();
    if(!power_on)
    {
        // Quick Revive works without power in solo
        is_quick_revive = IsDefined(ent.script_noteworthy) && ent.script_noteworthy == "specialty_quickrevive";
        players = GetPlayers();
        is_solo = players.size == 1;

        if(is_quick_revive && is_solo)
        {
            if(cost > 0)
                result.msg = "Buy " + perk_name + ", " + cost + " points";
            else
                result.msg = "Buy " + perk_name;
            return result;
        }

        result.msg = perk_name + ", needs power";
        return result;
    }

    if(cost > 0)
        result.msg = "Buy " + perk_name + ", " + cost + " points";
    else
        result.msg = "Buy " + perk_name;

    return result;
}

function build_door_prompt(ent, type_name)
{
    // Skip if door is already open
    if(IsDefined(ent._door_open) && ent._door_open)
        return undefined;

    result = SpawnStruct();
    result.priority = "medium";

    cost = 0;
    if(IsDefined(ent.zombie_cost))
        cost = ent.zombie_cost;
    else if(IsDefined(ent.cost))
        cost = ent.cost;

    label = "Open door";
    if(type_name == "debris")
        label = "Clear debris";

    if(cost > 0)
        result.msg = label + ", " + cost + " points";
    else
        result.msg = label;

    return result;
}

function build_power_prompt()
{
    result = SpawnStruct();
    result.priority = "medium";

    if(is_power_on())
        return undefined; // Power already on, nothing to interact with

    result.msg = "Activate power switch";
    return result;
}

function build_pap_prompt()
{
    result = SpawnStruct();
    result.priority = "medium";

    if(!is_power_on())
    {
        result.msg = "Pack a Punch, needs power";
        return result;
    }

    cost = 5000;
    result.msg = "Pack a Punch, " + cost + " points";
    return result;
}

function build_bgb_prompt()
{
    result = SpawnStruct();
    result.priority = "medium";

    cost = 500;
    result.msg = "GobbleGum machine, " + cost + " points";
    return result;
}

function build_trap_prompt(ent)
{
    result = SpawnStruct();
    result.priority = "medium";

    cost = 0;
    if(IsDefined(ent.zombie_cost))
        cost = ent.zombie_cost;
    else if(IsDefined(ent.cost))
        cost = ent.cost;

    trap_name = "Trap";
    if(IsDefined(ent.script_noteworthy))
        trap_name = ent.script_noteworthy;

    if(cost > 0)
        result.msg = "Activate " + trap_name + ", " + cost + " points";
    else
        result.msg = "Activate " + trap_name;

    return result;
}

// ============================================
// REVIVE PROMPT (downed teammate detection)
// ============================================

function check_revive_prompt()
{
    players = GetPlayers();
    if(players.size <= 1)
        return undefined;

    foreach(player in players)
    {
        if(player == self)
            continue;

        if(!IsDefined(player.laststand) || !player.laststand)
            continue;

        // Check if we're close enough to revive (within ~100 units)
        if(DistanceSquared(self.origin, player.origin) < 100 * 100)
        {
            result = SpawnStruct();
            result.msg = "Revive teammate";
            result.target = player;
            return result;
        }
    }

    return undefined;
}

// ============================================
// MYSTERY BOX PROMPT (checked via level.chests, not cached triggers)
// Integrated into main loop via a separate check
// ============================================

function check_box_prompt()
{
    if(!IsDefined(level.chests) || !IsDefined(level.chest_index))
        return undefined;

    active_chest = level.chests[level.chest_index];
    if(!IsDefined(active_chest))
        return undefined;

    // Check if box is hidden
    if(IsDefined(active_chest.hidden) && active_chest.hidden)
        return undefined;

    // Check if we're close enough (within trigger range ~80 units)
    if(DistanceSquared(self.origin, active_chest.origin) > 80 * 80)
        return undefined;

    result = SpawnStruct();
    result.priority = "medium";

    // Fire sale cost
    is_fire_sale = false;
    if(IsDefined(level.zombie_vars))
    {
        if(IsDefined(level.zombie_vars["axis"]) && IsDefined(level.zombie_vars["axis"]["zombie_powerup_fire_sale_on"]))
            is_fire_sale = level.zombie_vars["axis"]["zombie_powerup_fire_sale_on"];
        else if(IsDefined(level.zombie_vars["zombie_powerup_fire_sale_on"]))
            is_fire_sale = level.zombie_vars["zombie_powerup_fire_sale_on"];
    }

    cost = 950;
    if(is_fire_sale)
        cost = 10;

    result.msg = "Mystery Box, " + cost + " points";
    return result;
}

// ============================================
// HELPERS
// ============================================

function is_power_on()
{
    if(IsDefined(level.zombie_vars) && IsDefined(level.zombie_vars["electric_switch"]) && level.zombie_vars["electric_switch"])
        return true;
    if(IsDefined(level.electric_switch) && level.electric_switch)
        return true;
    return false;
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
        case "specialty_staminup":                 return "Stamin-Up";
        case "specialty_deadshot":                 return "Deadshot Daiquiri";
        case "specialty_widowswine":               return "Widow's Wine";
        case "specialty_nomotionsensor":           return "Widow's Wine";
        case "specialty_rof":                      return "Double Tap";
        case "specialty_additionalprimaryweapon":  return "Mule Kick";
        case "specialty_scavenger":                return "Electric Cherry";
        case "specialty_longersprint":             return "Stamin-Up";
        default:                                   return "Perk";
    }
}

function clean_weapon_name(weapon_ref)
{
    if(!IsDefined(weapon_ref))
        return "weapon";

    // Handle weapon objects — try engine displayname first
    if(!IsString(weapon_ref))
    {
        if(IsDefined(weapon_ref.displayname) && weapon_ref.displayname != "")
        {
            dn = weapon_ref.displayname;
            // If displayname looks like a proper name (has a space or no underscores), trust it
            if(IsSubStr(dn, " ") || !IsSubStr(dn, "_"))
                return dn;
        }

        // Fall through to lookup using the internal name string
        if(IsDefined(weapon_ref.name) && weapon_ref.name != "")
            weapon_ref = weapon_ref.name;
        else
            return "weapon";
    }

    if(weapon_ref == "")
        return "weapon";

    // Normalize to lowercase
    name = ToLower(weapon_ref);

    // Strip attachment suffixes (everything after +)
    tokens = StrTok(name, "+");
    if(tokens.size > 0)
        name = tokens[0];

    // Strip _zm suffix
    if(name.size >= 4 && GetSubStr(name, name.size - 3) == "_zm")
        name = GetSubStr(name, 0, name.size - 3);

    // Detect and strip _upgraded (Pack-a-Punch)
    is_upgraded = false;
    if(name.size >= 10 && GetSubStr(name, name.size - 9) == "_upgraded")
    {
        is_upgraded = true;
        name = GetSubStr(name, 0, name.size - 9);
    }

    // Look up in weapon display name table
    if(IsDefined(level.acc_weapon_names) && IsDefined(level.acc_weapon_names[name]))
    {
        display = level.acc_weapon_names[name];
        if(is_upgraded)
            display = display + " Pack-a-Punched";
        return display;
    }

    // Fallback: intelligent string cleaning for unknown weapons
    // Strip known category prefixes (longest first to avoid partial matches)
    if(name.size > 13 && GetSubStr(name, 0, 13) == "oneshotmelee_")
        name = GetSubStr(name, 13);
    else if(name.size > 9 && GetSubStr(name, 0, 9) == "launcher_")
        name = GetSubStr(name, 9);
    else if(name.size > 8 && GetSubStr(name, 0, 8) == "shotgun_")
        name = GetSubStr(name, 8);
    else if(name.size > 8 && GetSubStr(name, 0, 8) == "special_")
        name = GetSubStr(name, 8);
    else if(name.size > 7 && GetSubStr(name, 0, 7) == "pistol_")
        name = GetSubStr(name, 7);
    else if(name.size > 7 && GetSubStr(name, 0, 7) == "sniper_")
        name = GetSubStr(name, 7);
    else if(name.size > 7 && GetSubStr(name, 0, 7) == "wonder_")
        name = GetSubStr(name, 7);
    else if(name.size > 6 && GetSubStr(name, 0, 6) == "melee_")
        name = GetSubStr(name, 6);
    else if(name.size > 4 && GetSubStr(name, 0, 4) == "smg_")
        name = GetSubStr(name, 4);
    else if(name.size > 4 && GetSubStr(name, 0, 4) == "lmg_")
        name = GetSubStr(name, 4);
    else if(name.size > 3 && GetSubStr(name, 0, 3) == "ar_")
        name = GetSubStr(name, 3);

    // Replace underscores with spaces and capitalize each word
    parts = StrTok(name, "_");
    result = "";
    for(i = 0; i < parts.size; i++)
    {
        if(i > 0)
            result = result + " ";
        part = parts[i];
        if(part.size > 0)
            result = result + ToUpper(GetSubStr(part, 0, 1)) + GetSubStr(part, 1);
    }

    if(result == "")
        return "weapon";

    if(is_upgraded)
        result = result + " Pack-a-Punched";

    return result;
}

// ============================================
// WEAPON DISPLAY NAME TABLE
// ============================================

function init_weapon_names()
{
    level.acc_weapon_names = [];

    // ----- Assault Rifles -----
    level.acc_weapon_names["ar_standard"]    = "KN-44";
    level.acc_weapon_names["ar_kn44"]        = "KN-44";
    level.acc_weapon_names["kn44"]           = "KN-44";
    level.acc_weapon_names["ar_accurate"]    = "M8A7";
    level.acc_weapon_names["ar_m8a7"]        = "M8A7";
    level.acc_weapon_names["ar_fastfire"]    = "HVK-30";
    level.acc_weapon_names["ar_hvk30"]       = "HVK-30";
    level.acc_weapon_names["ar_longrange"]   = "ICR-1";
    level.acc_weapon_names["ar_icr1"]        = "ICR-1";
    level.acc_weapon_names["ar_cqb"]         = "Man-O-War";
    level.acc_weapon_names["ar_manowar"]     = "Man-O-War";
    level.acc_weapon_names["ar_semiauto"]    = "Sheiva";
    level.acc_weapon_names["ar_sheiva"]      = "Sheiva";
    level.acc_weapon_names["ar_burst"]       = "XR-2";
    level.acc_weapon_names["ar_xr2"]         = "XR-2";
    level.acc_weapon_names["ar_peacekeeper"] = "Peacekeeper MK2";
    level.acc_weapon_names["ar_garand"]      = "M1 Garand";
    level.acc_weapon_names["ar_m1garand"]    = "M1 Garand";

    // Classic / Chronicles ARs
    level.acc_weapon_names["ar_an94"]   = "AN-94";
    level.acc_weapon_names["an94"]      = "AN-94";
    level.acc_weapon_names["ar_m14"]    = "M14";
    level.acc_weapon_names["rifle_m14"] = "M14";
    level.acc_weapon_names["m14"]       = "M14";
    level.acc_weapon_names["ar_m16"]    = "M16";
    level.acc_weapon_names["m16"]       = "M16";
    level.acc_weapon_names["ar_stg44"]  = "STG-44";
    level.acc_weapon_names["stg44"]     = "STG-44";
    level.acc_weapon_names["ar_galil"]  = "Galil";
    level.acc_weapon_names["galil"]     = "Galil";
    level.acc_weapon_names["ar_famas"]  = "FFAR";
    level.acc_weapon_names["ar_ffar"]   = "FFAR";
    level.acc_weapon_names["famas"]     = "FFAR";

    // ----- Submachine Guns -----
    level.acc_weapon_names["smg_standard"]  = "Kuda";
    level.acc_weapon_names["smg_kuda"]      = "Kuda";
    level.acc_weapon_names["smg_versatile"] = "VMP";
    level.acc_weapon_names["smg_vmp"]       = "VMP";
    level.acc_weapon_names["smg_capacity"]  = "Weevil";
    level.acc_weapon_names["smg_weevil"]    = "Weevil";
    level.acc_weapon_names["smg_fastfire"]  = "Vesper";
    level.acc_weapon_names["smg_vesper"]    = "Vesper";
    level.acc_weapon_names["smg_burst"]     = "Pharo";
    level.acc_weapon_names["smg_pharo"]     = "Pharo";
    level.acc_weapon_names["smg_longrange"] = "Razorback";
    level.acc_weapon_names["smg_razorback"] = "Razorback";
    level.acc_weapon_names["smg_bootlegger"]= "Bootlegger";

    // DLC / Black Market SMGs
    level.acc_weapon_names["smg_hg40"] = "HG 40";
    level.acc_weapon_names["smg_ppsh"] = "PPSh-41";
    level.acc_weapon_names["smg_sten"] = "Sten";

    // Classic / Chronicles SMGs
    level.acc_weapon_names["smg_mp40"]    = "MP40";
    level.acc_weapon_names["mp40"]        = "MP40";
    level.acc_weapon_names["smg_ak74u"]   = "AK-74u";
    level.acc_weapon_names["ak74u"]       = "AK-74u";
    level.acc_weapon_names["smg_thompson"]= "Thompson";
    level.acc_weapon_names["smg_type100"] = "Type 100";
    level.acc_weapon_names["type100"]     = "Type 100";

    // ----- Shotguns -----
    level.acc_weapon_names["shotgun_pump"]     = "KRM-262";
    level.acc_weapon_names["shotgun_krm"]      = "KRM-262";
    level.acc_weapon_names["shotgun_spread"]   = "205 Brecci";
    level.acc_weapon_names["shotgun_brecci"]   = "205 Brecci";
    level.acc_weapon_names["shotgun_semiauto"] = "Haymaker 12";
    level.acc_weapon_names["shotgun_haymaker"] = "Haymaker 12";
    level.acc_weapon_names["shotgun_precision"]= "Argus";
    level.acc_weapon_names["shotgun_argus"]    = "Argus";
    level.acc_weapon_names["shotgun_energy"]   = "Banshii";

    // Classic Shotguns
    level.acc_weapon_names["shotgun_olympia"] = "Olympia";
    level.acc_weapon_names["olympia"]         = "Olympia";

    // ----- Light Machine Guns -----
    level.acc_weapon_names["lmg_heavy"]    = "BRM";
    level.acc_weapon_names["lmg_brm"]      = "BRM";
    level.acc_weapon_names["lmg_light"]    = "Dingo";
    level.acc_weapon_names["lmg_dingo"]    = "Dingo";
    level.acc_weapon_names["lmg_slowfire"] = "Gorgon";
    level.acc_weapon_names["lmg_gorgon"]   = "Gorgon";
    level.acc_weapon_names["lmg_burst"]    = "48 Dredge";
    level.acc_weapon_names["lmg_dredge"]   = "48 Dredge";

    // Classic LMGs
    level.acc_weapon_names["lmg_rpk"] = "RPK";
    level.acc_weapon_names["rpk"]     = "RPK";

    // ----- Sniper Rifles -----
    level.acc_weapon_names["sniper_bolt"]       = "Locus";
    level.acc_weapon_names["sniper_locus"]      = "Locus";
    level.acc_weapon_names["sniper_fullauto"]   = "Drakon";
    level.acc_weapon_names["sniper_drakon"]     = "Drakon";
    level.acc_weapon_names["sniper_heavy"]      = "SVG-100";
    level.acc_weapon_names["sniper_svg"]        = "SVG-100";
    level.acc_weapon_names["sniper_chargeshot"] = "P-06";
    level.acc_weapon_names["sniper_p06"]        = "P-06";
    level.acc_weapon_names["sniper_dbsr"]       = "DBSR-50";

    // ----- Pistols -----
    level.acc_weapon_names["pistol_standard"] = "MR6";
    level.acc_weapon_names["pistol_mr6"]      = "MR6";
    level.acc_weapon_names["pistol_burst"]    = "RK5";
    level.acc_weapon_names["pistol_rk5"]      = "RK5";
    level.acc_weapon_names["pistol_fullauto"] = "L-CAR 9";
    level.acc_weapon_names["pistol_lcar9"]    = "L-CAR 9";

    // Classic / DLC Pistols
    level.acc_weapon_names["pistol_m1911"]    = "M1911";
    level.acc_weapon_names["m1911"]           = "M1911";
    level.acc_weapon_names["pistol_cz75"]     = "CZ75";
    level.acc_weapon_names["cz75"]            = "CZ75";
    level.acc_weapon_names["pistol_python"]   = "Python";
    level.acc_weapon_names["pistol_crossbow"] = "NX ShadowClaw";
    level.acc_weapon_names["pistol_marshal"]  = "Marshal 16";
    level.acc_weapon_names["pistol_rift"]     = "Rift E9";

    // ----- Launchers -----
    level.acc_weapon_names["launcher_standard"] = "XM-53";
    level.acc_weapon_names["launcher_xm53"]     = "XM-53";
    level.acc_weapon_names["launcher_l4siege"]  = "L4 Siege";
    level.acc_weapon_names["launcher_coda"]     = "MAX-GL";

    // ----- Wonder Weapons -----
    level.acc_weapon_names["ray_gun"]            = "Ray Gun";
    level.acc_weapon_names["raygun"]             = "Ray Gun";
    level.acc_weapon_names["raygun_mark2"]       = "Ray Gun Mark 2";
    level.acc_weapon_names["ray_gun_mark2"]      = "Ray Gun Mark 2";
    level.acc_weapon_names["raygun_mark3"]       = "GKZ-45 Mk3";
    level.acc_weapon_names["gkz45mk3"]           = "GKZ-45 Mk3";
    level.acc_weapon_names["thundergun"]         = "Thundergun";
    level.acc_weapon_names["wonder_thundergun"]  = "Thundergun";
    level.acc_weapon_names["tesla_gun"]          = "Wunderwaffe DG-2";
    level.acc_weapon_names["wunderwaffe_dg2"]    = "Wunderwaffe DG-2";
    level.acc_weapon_names["wunderwaffe"]        = "Wunderwaffe DG-2";
    level.acc_weapon_names["idgun"]              = "Apothicon Servant";
    level.acc_weapon_names["apothicon_servant"]  = "Apothicon Servant";
    level.acc_weapon_names["kt4"]                = "KT-4";
    level.acc_weapon_names["masamune"]           = "Masamune";
    level.acc_weapon_names["shrink_ray"]         = "31-79 JGb215";
    level.acc_weapon_names["shrinkray"]          = "31-79 JGb215";
    level.acc_weapon_names["baby_gun"]           = "31-79 JGb215";
    level.acc_weapon_names["wave_gun"]           = "Wave Gun";
    level.acc_weapon_names["microwavegun"]       = "Wave Gun";
    level.acc_weapon_names["microwavegundw"]     = "Wave Gun";
    level.acc_weapon_names["microwavegunlh"]     = "Zap Gun";
    level.acc_weapon_names["quantum_bomb"]       = "QED";
    level.acc_weapon_names["gersch_device"]      = "Gersh Device";

    // Der Eisendrache Bows
    level.acc_weapon_names["oneshotmelee_rune_prison"] = "Wrath of the Ancients";
    level.acc_weapon_names["oneshotmelee_bow"]         = "Wrath of the Ancients";
    level.acc_weapon_names["oneshotmelee_storm"]       = "Storm Bow";
    level.acc_weapon_names["bow_storm"]                = "Storm Bow";
    level.acc_weapon_names["lightning_bow"]             = "Storm Bow";
    level.acc_weapon_names["oneshotmelee_fire"]        = "Fire Bow";
    level.acc_weapon_names["bow_fire"]                 = "Fire Bow";
    level.acc_weapon_names["fire_bow"]                 = "Fire Bow";
    level.acc_weapon_names["oneshotmelee_void"]        = "Void Bow";
    level.acc_weapon_names["bow_void"]                 = "Void Bow";
    level.acc_weapon_names["void_bow"]                 = "Void Bow";
    level.acc_weapon_names["oneshotmelee_wolf"]        = "Wolf Bow";
    level.acc_weapon_names["bow_wolf"]                 = "Wolf Bow";
    level.acc_weapon_names["wolf_bow"]                 = "Wolf Bow";

    // Origins Staffs
    level.acc_weapon_names["staff_fire"]      = "Staff of Fire";
    level.acc_weapon_names["staff_water"]     = "Staff of Ice";
    level.acc_weapon_names["staff_ice"]       = "Staff of Ice";
    level.acc_weapon_names["staff_lightning"] = "Staff of Lightning";
    level.acc_weapon_names["staff_electric"]  = "Staff of Lightning";
    level.acc_weapon_names["staff_wind"]      = "Staff of Wind";
    level.acc_weapon_names["staff_air"]       = "Staff of Wind";

    // ----- Equipment & Melee -----
    level.acc_weapon_names["cymbal_monkey"]        = "Monkey Bomb";
    level.acc_weapon_names["octobomb"]             = "Li'l Arnie";
    level.acc_weapon_names["lil_arnie"]            = "Li'l Arnie";
    level.acc_weapon_names["oneshotmelee"]         = "Ragnarok DG-4";
    level.acc_weapon_names["oneshotmelee_ragnarok"]= "Ragnarok DG-4";
    level.acc_weapon_names["oneshotmelee_dg4"]     = "Ragnarok DG-4";
    level.acc_weapon_names["bowie_knife"]          = "Bowie Knife";
    level.acc_weapon_names["knife_bowie"]          = "Bowie Knife";
    level.acc_weapon_names["knife_ballistic"]      = "Ballistic Knife";
    level.acc_weapon_names["ballistic_knife"]      = "Ballistic Knife";
    level.acc_weapon_names["trip_mine"]            = "Trip Mine";
    level.acc_weapon_names["claymore"]             = "Trip Mine";
    level.acc_weapon_names["frag_grenade"]         = "Frag Grenade";
    level.acc_weapon_names["semtex"]               = "Semtex";
    level.acc_weapon_names["dragon_strike"]        = "Dragon Strike";

    // Special / Powerup weapons
    level.acc_weapon_names["hero_minigun"]  = "Death Machine";
    level.acc_weapon_names["minigun"]       = "Death Machine";
    level.acc_weapon_names["death_machine"] = "Death Machine";
    level.acc_weapon_names["special_discgun"]= "D13 Sector";
    level.acc_weapon_names["melee_nailgun"] = "DIY 11 Renovator";

    // DLC Melee weapons
    level.acc_weapon_names["melee_katana"]    = "Fury's Song";
    level.acc_weapon_names["melee_crowbar"]   = "Iron Jim";
    level.acc_weapon_names["melee_wrench"]    = "Wrench";
    level.acc_weapon_names["melee_nunchucks"] = "Nunchucks";
}
