#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;

#using scripts\zm\zm_accessibility_main;
#using scripts\zm\_zm_bgb;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_gobblegum;

/*
    GobbleGum loadout (accessibility)

    The launcher writes the player's chosen gums as dvars (acc_bgb_0..4) into
    the mod's mod.cfg (the only reliable dvar-delivery path in +devmap). This
    module reads them and:
      - auto-gives the whole pack to the player shortly after spawn
      - lets the player re-grab the next gum (round-robin) by pressing Use at
        the GobbleGum machine, with a 5-second cooldown

    DEVMAP CAVEAT: +devmap is offline. bgb::give() only works if the gum is
    registered in level.bgb[]. Classic gums are the most likely to actually
    activate; Mega/Rare/Ultra may not. give_one() reports which case happened
    so a blind player gets honest feedback instead of silence.
*/

// ============================================
// INIT (level scope, called from zm_accessibility_main::__init__)
// ============================================

function init()
{
    level.accessibility.bgb_pack = [];

    for(i = 0; i < 5; i++)
    {
        name = GetDvarString("acc_bgb_" + i, "");
        if(IsDefined(name) && name != "")
            level.accessibility.bgb_pack[level.accessibility.bgb_pack.size] = name;
    }

    level.accessibility.bgb_names = build_display_names();
}

function display_name(internal_name)
{
    if(IsDefined(level.accessibility.bgb_names) && IsDefined(level.accessibility.bgb_names[internal_name]))
        return level.accessibility.bgb_names[internal_name];
    return "gobble gum";
}

// ============================================
// PER-PLAYER THINK (threaded from on_player_spawned)
// ============================================

function gobblegum_think()
{
    // Gums must survive going down, so (like downed_monitor) only end on
    // disconnect or a mod restart - NOT on "death".
    self endon("disconnect");
    self endon("acc_restart");

    if(!IsDefined(level.accessibility.bgb_pack) || level.accessibility.bgb_pack.size == 0)
        return;

    // Give the BGB system time to register (stock maps set level.bgb_in_use
    // in an autoexec; registration fills level.bgb[]).
    wait 5.0;

    // ---- Auto-give the whole pack on spawn ----
    self give_pack();

    // ---- Machine top-up: press Use near the GobbleGum machine ----
    pack = level.accessibility.bgb_pack;
    next_idx = 0;
    last_give = 0;

    while(true)
    {
        wait 0.25;

        machines = GetEntArray("bgb_machine_use", "targetname");
        if(!IsDefined(machines) || machines.size == 0)
            continue;

        near = false;
        foreach(m in machines)
        {
            if(Distance(self.origin, m.origin) <= 200)
            {
                near = true;
                break;
            }
        }
        if(!near)
            continue;

        if(self UseButtonPressed() && (GetTime() - last_give) >= 5000)
        {
            self give_one(pack[next_idx]);
            next_idx = (next_idx + 1) % pack.size;
            last_give = GetTime();
        }
    }
}

function give_pack()
{
    foreach(name in level.accessibility.bgb_pack)
    {
        self give_one(name);
        wait 0.5; // stagger so multiple gives don't collide on one frame
    }
}

function give_one(name)
{
    if(!IsDefined(name) || name == "")
        return;

    // bgb::give requires the gum to be registered. Guard the call so an
    // unregistered (offline-blocked) gum can't error the whole thread.
    given = false;
    if(IsDefined(level.bgb) && IsDefined(level.bgb[name]))
    {
        self bgb::give(name);
        given = true;
    }

    if(given)
        zm_accessibility::queue_tts_message("Gobble gum: " + display_name(name), "high");
    else
        zm_accessibility::queue_tts_message(display_name(name) + " is not available in this mode", "medium");
}

// ============================================
// DISPLAY NAME TABLE (63 gums - internal -> spoken)
// Internal names are authoritative (decompiled scripts/zm/bgbs/_zm_bgb_*).
// ============================================

function build_display_names()
{
    n = [];
    n["zm_bgb_aftertaste"]                = "Aftertaste";
    n["zm_bgb_alchemical_antithesis"]     = "Alchemical Antithesis";
    n["zm_bgb_always_done_swiftly"]       = "Always Done Swiftly";
    n["zm_bgb_anywhere_but_here"]         = "Anywhere but Here";
    n["zm_bgb_armamental_accomplishment"] = "Armamental Accomplishment";
    n["zm_bgb_arms_grace"]                = "Arm's Grace";
    n["zm_bgb_arsenal_accelerator"]       = "Arsenal Accelerator";
    n["zm_bgb_board_games"]               = "Board Games";
    n["zm_bgb_board_to_death"]            = "Board to Death";
    n["zm_bgb_bullet_boost"]              = "Bullet Boost";
    n["zm_bgb_burned_out"]                = "Burned Out";
    n["zm_bgb_cache_back"]                = "Cache Back";
    n["zm_bgb_coagulant"]                 = "Coagulant";
    n["zm_bgb_crate_power"]               = "Crate Power";
    n["zm_bgb_crawl_space"]               = "Crawl Space";
    n["zm_bgb_danger_closest"]            = "Danger Closest";
    n["zm_bgb_dead_of_nuclear_winter"]    = "Dead of the Nuclear Winter";
    n["zm_bgb_disorderly_combat"]         = "Disorderly Combat";
    n["zm_bgb_ephemeral_enhancement"]     = "Ephemeral Enhancement";
    n["zm_bgb_extra_credit"]              = "Extra Credit";
    n["zm_bgb_eye_candy"]                 = "Eye Candy";
    n["zm_bgb_fatal_contraption"]         = "Fatal Contraption";
    n["zm_bgb_fear_in_headlights"]        = "Fear in Headlights";
    n["zm_bgb_firing_on_all_cylinders"]   = "Firing on All Cylinders";
    n["zm_bgb_flavor_hexed"]              = "Flavor Hexed";
    n["zm_bgb_head_drama"]                = "Head Drama";
    n["zm_bgb_idle_eyes"]                 = "Idle Eyes";
    n["zm_bgb_im_feelin_lucky"]           = "I'm Feelin' Lucky";
    n["zm_bgb_immolation_liquidation"]    = "Immolation Liquidation";
    n["zm_bgb_impatient"]                 = "Impatient";
    n["zm_bgb_in_plain_sight"]            = "In Plain Sight";
    n["zm_bgb_kill_joy"]                  = "Kill Joy";
    n["zm_bgb_killing_time"]              = "Killing Time";
    n["zm_bgb_licensed_contractor"]       = "Licensed Contractor";
    n["zm_bgb_lucky_crit"]                = "Lucky Crit";
    n["zm_bgb_mind_blown"]                = "Mind Blown";
    n["zm_bgb_near_death_experience"]     = "Near Death Experience";
    n["zm_bgb_newtonian_negation"]        = "Newtonian Negation";
    n["zm_bgb_now_you_see_me"]            = "Now You See Me";
    n["zm_bgb_on_the_house"]              = "On the House";
    n["zm_bgb_perkaholic"]                = "Perkaholic";
    n["zm_bgb_phoenix_up"]                = "Phoenix Up";
    n["zm_bgb_pop_shocks"]                = "Pop Shocks";
    n["zm_bgb_power_vacuum"]              = "Power Vacuum";
    n["zm_bgb_profit_sharing"]            = "Profit Sharing";
    n["zm_bgb_projectile_vomiting"]       = "Projectile Vomiting";
    n["zm_bgb_reign_drops"]               = "Reign Drops";
    n["zm_bgb_respin_cycle"]              = "Respin Cycle";
    n["zm_bgb_round_robbin"]              = "Round Robin";
    n["zm_bgb_secret_shopper"]            = "Secret Shopper";
    n["zm_bgb_self_medication"]           = "Self Medication";
    n["zm_bgb_shopping_free"]             = "Shopping Free";
    n["zm_bgb_slaughter_slide"]           = "Slaughter Slide";
    n["zm_bgb_soda_fountain"]             = "Soda Fountain";
    n["zm_bgb_stock_option"]              = "Stock Option";
    n["zm_bgb_sword_flay"]                = "Sword Flay";
    n["zm_bgb_temporal_gift"]             = "Temporal Gift";
    n["zm_bgb_tone_death"]                = "Tone Death";
    n["zm_bgb_unbearable"]                = "Unbearable";
    n["zm_bgb_undead_man_walking"]        = "Undead Man Walking";
    n["zm_bgb_unquenchable"]              = "Unquenchable";
    n["zm_bgb_wall_power"]                = "Wall Power";
    n["zm_bgb_whos_keeping_score"]        = "Who's Keeping Score";
    return n;
}
