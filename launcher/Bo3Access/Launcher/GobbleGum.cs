namespace Bo3Access.Launcher;

#region GobbleGum catalogue

/// <summary>
/// One BO3 GobbleGum. <see cref="Internal"/> is the engine name passed to
/// the GSC <c>bgb::give()</c> and written to mod.cfg — it must match the
/// decompiled <c>scripts/zm/bgbs/_zm_bgb_*.gsc</c> exactly. <see cref="Display"/>
/// is only for the spoken picker.
/// </summary>
public readonly record struct GobbleGum(string Internal, string Display);

/// <summary>
/// All 63 GobbleGums registered in BO3's GSC (authoritative list taken from
/// the decompiled <c>scripts/zm/bgbs/</c> directory). NOTE: in <c>+devmap</c>
/// offline mode the engine only honours a subset — Classic gums are the most
/// likely to actually activate; Mega/Rare/Ultra may not. The picker still
/// lists them all so the choice is the user's.
/// </summary>
public static class GobbleGums
{
    public const int MaxSlots = 5; // acc_bgb_0 .. acc_bgb_4

    public static readonly IReadOnlyList<GobbleGum> All = new GobbleGum[]
    {
        new("zm_bgb_aftertaste",               "Aftertaste"),
        new("zm_bgb_alchemical_antithesis",    "Alchemical Antithesis"),
        new("zm_bgb_always_done_swiftly",      "Always Done Swiftly"),
        new("zm_bgb_anywhere_but_here",        "Anywhere but Here"),
        new("zm_bgb_armamental_accomplishment","Armamental Accomplishment"),
        new("zm_bgb_arms_grace",               "Arm's Grace"),
        new("zm_bgb_arsenal_accelerator",      "Arsenal Accelerator"),
        new("zm_bgb_board_games",              "Board Games"),
        new("zm_bgb_board_to_death",           "Board to Death"),
        new("zm_bgb_bullet_boost",             "Bullet Boost"),
        new("zm_bgb_burned_out",               "Burned Out"),
        new("zm_bgb_cache_back",               "Cache Back"),
        new("zm_bgb_coagulant",                "Coagulant"),
        new("zm_bgb_crate_power",              "Crate Power"),
        new("zm_bgb_crawl_space",              "Crawl Space"),
        new("zm_bgb_danger_closest",           "Danger Closest"),
        new("zm_bgb_dead_of_nuclear_winter",   "Dead of the Nuclear Winter"),
        new("zm_bgb_disorderly_combat",        "Disorderly Combat"),
        new("zm_bgb_ephemeral_enhancement",    "Ephemeral Enhancement"),
        new("zm_bgb_extra_credit",             "Extra Credit"),
        new("zm_bgb_eye_candy",                "Eye Candy"),
        new("zm_bgb_fatal_contraption",        "Fatal Contraption"),
        new("zm_bgb_fear_in_headlights",       "Fear in Headlights"),
        new("zm_bgb_firing_on_all_cylinders",  "Firing on All Cylinders"),
        new("zm_bgb_flavor_hexed",             "Flavor Hexed"),
        new("zm_bgb_head_drama",               "Head Drama"),
        new("zm_bgb_idle_eyes",                "Idle Eyes"),
        new("zm_bgb_im_feelin_lucky",          "I'm Feelin' Lucky"),
        new("zm_bgb_immolation_liquidation",   "Immolation Liquidation"),
        new("zm_bgb_impatient",                "Impatient"),
        new("zm_bgb_in_plain_sight",           "In Plain Sight"),
        new("zm_bgb_kill_joy",                 "Kill Joy"),
        new("zm_bgb_killing_time",             "Killing Time"),
        new("zm_bgb_licensed_contractor",      "Licensed Contractor"),
        new("zm_bgb_lucky_crit",               "Lucky Crit"),
        new("zm_bgb_mind_blown",               "Mind Blown"),
        new("zm_bgb_near_death_experience",    "Near Death Experience"),
        new("zm_bgb_newtonian_negation",       "Newtonian Negation"),
        new("zm_bgb_now_you_see_me",           "Now You See Me"),
        new("zm_bgb_on_the_house",             "On the House"),
        new("zm_bgb_perkaholic",               "Perkaholic"),
        new("zm_bgb_phoenix_up",               "Phoenix Up"),
        new("zm_bgb_pop_shocks",               "Pop Shocks"),
        new("zm_bgb_power_vacuum",             "Power Vacuum"),
        new("zm_bgb_profit_sharing",           "Profit Sharing"),
        new("zm_bgb_projectile_vomiting",      "Projectile Vomiting"),
        new("zm_bgb_reign_drops",              "Reign Drops"),
        new("zm_bgb_respin_cycle",             "Respin Cycle"),
        new("zm_bgb_round_robbin",             "Round Robin"),
        new("zm_bgb_secret_shopper",           "Secret Shopper"),
        new("zm_bgb_self_medication",          "Self Medication"),
        new("zm_bgb_shopping_free",            "Shopping Free"),
        new("zm_bgb_slaughter_slide",          "Slaughter Slide"),
        new("zm_bgb_soda_fountain",            "Soda Fountain"),
        new("zm_bgb_stock_option",             "Stock Option"),
        new("zm_bgb_sword_flay",               "Sword Flay"),
        new("zm_bgb_temporal_gift",            "Temporal Gift"),
        new("zm_bgb_tone_death",               "Tone Death"),
        new("zm_bgb_unbearable",               "Unbearable"),
        new("zm_bgb_undead_man_walking",       "Undead Man Walking"),
        new("zm_bgb_unquenchable",             "Unquenchable"),
        new("zm_bgb_wall_power",               "Wall Power"),
        new("zm_bgb_whos_keeping_score",       "Who's Keeping Score?"),
    };
}

#endregion
