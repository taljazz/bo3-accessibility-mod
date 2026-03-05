#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_settings;

/*
	Runtime Settings & Tutorial System

	Controls use keyboard F-keys via dvar binds (shipped in mod.cfg):
	  F1 = Toggle master on/off
	  F2 = Toggle beacons
	  F3 = Toggle proximity alerts
	  F4 = Toggle aim assist
	  F5 = Toggle auto fire
	  F6 = Toggle announcements
	  F7 = Cycle beacon mode (all/perks/weapons/navigation/off)
	  F8 = Toggle menu/prompt reading

	The GSC polls dvars each 0.5s and announces changes via TTS.
	No D-pad or ActionSlot buttons are used (they conflict with Zombies).
*/

// ============================================
// DVAR REGISTRATION
// ============================================

function init()
{
	// SetDvarIfUninitialized doesn't exist in BO3 GSC -- use GetDvarString check
	if(GetDvarString("acc_enabled") == "")          SetDvar("acc_enabled", 1);
	if(GetDvarString("acc_aim_assist") == "")       SetDvar("acc_aim_assist", 1);
	if(GetDvarString("acc_auto_fire") == "")        SetDvar("acc_auto_fire", 0);
	if(GetDvarString("acc_beacons") == "")          SetDvar("acc_beacons", 1);
	if(GetDvarString("acc_proximity") == "")        SetDvar("acc_proximity", 1);
	if(GetDvarString("acc_announcements") == "")    SetDvar("acc_announcements", 1);
	if(GetDvarString("acc_beacon_range") == "")     SetDvar("acc_beacon_range", 1500);
	if(GetDvarString("acc_proximity_range") == "")  SetDvar("acc_proximity_range", 600);
	if(GetDvarString("acc_aim_range") == "")        SetDvar("acc_aim_range", 1000);
	if(GetDvarString("acc_beacon_mode") == "")      SetDvar("acc_beacon_mode", 0);  // 0=all, 1=perks, 2=weapons, 3=navigation, 4=off
	if(GetDvarString("acc_menu_reading") == "")     SetDvar("acc_menu_reading", 1);
}

// ============================================
// SETTINGS THINK (per-player, called from main)
// ============================================

function settings_think()
{
	self endon("disconnect");
	self endon("death");
	self endon("acc_restart");

	// Register dvars on first run
	init();

	// Start tutorial
	self thread tutorial_think();

	// Track previous dvar values for change detection
	prev_enabled = GetDvarInt("acc_enabled", 1);
	prev_aim = GetDvarInt("acc_aim_assist", 1);
	prev_auto_fire = GetDvarInt("acc_auto_fire", 0);
	prev_beacons = GetDvarInt("acc_beacons", 1);
	prev_proximity = GetDvarInt("acc_proximity", 1);
	prev_announcements = GetDvarInt("acc_announcements", 1);
	prev_beacon_mode = GetDvarInt("acc_beacon_mode", 0);
	prev_menu_reading = GetDvarInt("acc_menu_reading", 1);

	// Beacon mode names for TTS
	beacon_mode_names = [];
	beacon_mode_names[0] = "All";
	beacon_mode_names[1] = "Perks";
	beacon_mode_names[2] = "Weapons";
	beacon_mode_names[3] = "Navigation";
	beacon_mode_names[4] = "Off";

	// Main loop: sync dvars to level.accessibility and detect changes
	while(true)
	{
		// Read current dvar values
		cur_enabled = GetDvarInt("acc_enabled", 1);
		cur_aim = GetDvarInt("acc_aim_assist", 1);
		cur_auto_fire = GetDvarInt("acc_auto_fire", 0);
		cur_beacons = GetDvarInt("acc_beacons", 1);
		cur_proximity = GetDvarInt("acc_proximity", 1);
		cur_announcements = GetDvarInt("acc_announcements", 1);
		cur_beacon_mode = GetDvarInt("acc_beacon_mode", 0);
		cur_menu_reading = GetDvarInt("acc_menu_reading", 1);

		// Clamp beacon mode to valid range
		if(cur_beacon_mode < 0 || cur_beacon_mode > 4)
			cur_beacon_mode = 0;

		// Sync to level.accessibility for other modules
		level.accessibility.enabled = cur_enabled;
		level.accessibility.aim_assist = cur_aim;
		level.accessibility.auto_fire = cur_auto_fire;
		level.accessibility.beacons_enabled = cur_beacons;
		level.accessibility.proximity_enabled = cur_proximity;
		level.accessibility.announcements_enabled = cur_announcements;
		level.accessibility.beacon_range = GetDvarInt("acc_beacon_range", 1500);
		level.accessibility.proximity_range = GetDvarInt("acc_proximity_range", 600);
		level.accessibility.aim_range = GetDvarInt("acc_aim_range", 1000);
		level.accessibility.menu_reading = cur_menu_reading;

		// Map beacon mode integer to string for beacon module
		switch(cur_beacon_mode)
		{
			case 0: self.accessibility.beacon_mode = "all"; break;
			case 1: self.accessibility.beacon_mode = "perks"; break;
			case 2: self.accessibility.beacon_mode = "weapons"; break;
			case 3: self.accessibility.beacon_mode = "navigation"; break;
			case 4: self.accessibility.beacon_mode = "off"; break;
			default: self.accessibility.beacon_mode = "all"; break;
		}

		// Announce changes via TTS
		if(cur_enabled != prev_enabled)
			zm_accessibility::queue_tts_message("Accessibility mod " + on_off(cur_enabled), "high");

		if(cur_aim != prev_aim)
			zm_accessibility::queue_tts_message("Aim assist " + on_off(cur_aim), "high");

		if(cur_auto_fire != prev_auto_fire)
			zm_accessibility::queue_tts_message("Auto fire " + on_off(cur_auto_fire), "high");

		if(cur_beacons != prev_beacons)
			zm_accessibility::queue_tts_message("Beacons " + on_off(cur_beacons), "high");

		if(cur_proximity != prev_proximity)
			zm_accessibility::queue_tts_message("Proximity alerts " + on_off(cur_proximity), "high");

		if(cur_announcements != prev_announcements)
			zm_accessibility::queue_tts_message("Announcements " + on_off(cur_announcements), "high");

		if(cur_beacon_mode != prev_beacon_mode)
		{
			mode_name = "All";
			if(cur_beacon_mode >= 0 && cur_beacon_mode <= 4)
				mode_name = beacon_mode_names[cur_beacon_mode];
			zm_accessibility::queue_tts_message("Beacon mode: " + mode_name, "high");
			// Reset beacon TTS dedup so next pulse announces fresh
			self.accessibility.last_beacon_msg = "";
		}

		if(cur_menu_reading != prev_menu_reading)
			zm_accessibility::queue_tts_message("Menu reading " + on_off(cur_menu_reading), "high");

		// Update previous values
		prev_enabled = cur_enabled;
		prev_aim = cur_aim;
		prev_auto_fire = cur_auto_fire;
		prev_beacons = cur_beacons;
		prev_proximity = cur_proximity;
		prev_announcements = cur_announcements;
		prev_beacon_mode = cur_beacon_mode;
		prev_menu_reading = cur_menu_reading;

		wait 0.5;
	}
}

function on_off(val)
{
	if(val)
		return "on";
	return "off";
}

// ============================================
// FIRST-TIME TUTORIAL
// ============================================

function tutorial_think()
{
	self endon("disconnect");
	self endon("death");
	self endon("acc_restart");

	if(IsDefined(self.accessibility.tutorial_played) && self.accessibility.tutorial_played)
		return;

	wait 5.0;  // let game settle

	self.accessibility.tutorial_played = true;

	messages = [];
	messages[0] = "Accessibility mod active";
	messages[1] = "Beacons guide you to objects with 3D sound. Higher pitch means closer";
	messages[2] = "Proximity alerts warn of nearby zombies with threat levels";
	messages[3] = "Aim down sights to auto target enemies";
	messages[4] = "Press tilde to open console, type exec acc_binds.cfg, press enter. This enables F keys.";
	messages[5] = "After that, F1 through F8 toggle features. F7 cycles beacon filter. F8 toggles menu reading";

	for(i = 0; i < messages.size; i++)
	{
		// Check if player wants to skip (attack button)
		if(self AttackButtonPressed())
			break;
		zm_accessibility::queue_tts_message(messages[i], "high");
		wait 4.0;
	}
}
