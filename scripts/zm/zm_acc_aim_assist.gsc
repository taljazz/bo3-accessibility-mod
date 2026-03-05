#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\zm\zm_accessibility_main;

#insert scripts\shared\shared.gsh;

#namespace zm_acc_aim;

/*
    Auto-Aim Assist System for Blind Accessibility

    Behavior:
    - When player aims down sights (ADS), snaps aim to nearest zombie
    - Continuously tracks the locked target until it dies
    - Prioritizes closest zombie by default
    - Optional auto-fire mode: automatically shoots when locked onto a target
    - Provides audio feedback when target is acquired/lost
    - Re-validates LOS each frame and breaks lock if blocked
    - Re-evaluates targets every 2s, switching if significantly better target found
*/

function aim_assist_think()
{
    self endon("disconnect");
    self endon("death");
    self endon("acc_restart");

    self.accessibility.aim_target = undefined;
    self.accessibility.aim_locked = false;
    self.accessibility._last_fire_time = undefined;
    self.accessibility._last_eval_time = 0;
    self.accessibility._last_lock_ping = 0;

    while(true)
    {
        // Check if player is aiming down sights
        is_aiming = self AdsButtonPressed();

        if(is_aiming)
        {
            // If we don't have a target or current target is dead/undefined, find one
            if(!IsDefined(self.accessibility.aim_target) || !IsAlive(self.accessibility.aim_target))
            {
                if(self.accessibility.aim_locked)
                {
                    self.accessibility.aim_locked = false;
                    self.accessibility.aim_target = undefined;
                }

                new_target = self find_best_target();

                if(IsDefined(new_target))
                {
                    self.accessibility.aim_target = new_target;
                    self.accessibility.aim_locked = true;
                    self.accessibility._last_eval_time = GetTime();
                    // Immediate first ping on lock
                    self PlayLocalSound("aud_acc_aim_lock");
                    self.accessibility._last_lock_ping = GetTime();
                }
                else
                {
                    self.accessibility.aim_locked = false;
                }
            }

            // If we have a valid target, validate LOS and track it
            if(self.accessibility.aim_locked && IsDefined(self.accessibility.aim_target) && IsAlive(self.accessibility.aim_target))
            {
                // LOS re-validation: break lock if we can't see the target
                target_eye = self.accessibility.aim_target GetEye();
                if(!IsDefined(target_eye))
                    target_eye = self.accessibility.aim_target.origin + (0, 0, 60);

                if(!SightTracePassed(self GetEye(), target_eye, false, self))
                {
                    self.accessibility.aim_target = undefined;
                    self.accessibility.aim_locked = false;
                    wait 0.05;
                    continue;
                }

                // Target re-evaluation every 2 seconds
                if(GetTime() - self.accessibility._last_eval_time >= 2000)
                {
                    self.accessibility._last_eval_time = GetTime();
                    current_score = self score_target(self.accessibility.aim_target);
                    new_result = self find_best_target_with_score();
                    if(IsDefined(new_result) && IsDefined(new_result.target) && new_result.target != self.accessibility.aim_target)
                    {
                        if(current_score > 0 && new_result.score >= current_score * 1.3)
                            self.accessibility.aim_target = new_result.target;
                        else if(current_score <= 0 && new_result.score > 0)
                            self.accessibility.aim_target = new_result.target;
                    }
                }

                self snap_aim_to_target(self.accessibility.aim_target);

                // Repeating ping while locked (every 500ms)
                if(GetTime() - self.accessibility._last_lock_ping >= 500)
                {
                    self PlayLocalSound("aud_acc_aim_lock");
                    self.accessibility._last_lock_ping = GetTime();
                }

                // Auto-fire (inline, not threaded) with fire rate cooldown
                if(IsDefined(level.accessibility) && level.accessibility.auto_fire && IsDefined(self.accessibility.aim_target))
                {
                    if(!IsDefined(self.accessibility._last_fire_time) || GetTime() - self.accessibility._last_fire_time >= 200)
                    {
                        self auto_fire_at_target(self.accessibility.aim_target);
                    }
                }
            }
        }
        else
        {
            // Not aiming - clear target lock (silence = no lock)
            if(self.accessibility.aim_locked)
            {
                self.accessibility.aim_locked = false;
                self.accessibility.aim_target = undefined;
            }
        }

        // Run every frame for responsive aim
        wait 0.05;
    }
}

function find_best_target()
{
    result = self find_best_target_with_score();
    if(IsDefined(result))
        return result.target;
    return undefined;
}

function find_best_target_with_score()
{
    // Use shared zombie cache if available
    zombies = undefined;
    if(IsDefined(level.accessibility) && IsDefined(level.accessibility.zombie_cache))
        zombies = level.accessibility.zombie_cache;
    else
        zombies = GetAITeamArray("axis");

    best_target = undefined;
    best_score = -999999;

    player_origin = self GetEye();
    player_angles = self GetPlayerAngles();
    player_forward = AnglesToForward(player_angles);

    // Use level.accessibility defines for range
    aim_range = 1000;
    if(IsDefined(level.accessibility) && IsDefined(level.accessibility.aim_range))
        aim_range = level.accessibility.aim_range;
    range_sq = aim_range * aim_range;

    foreach(zombie in zombies)
    {
        if(!IsAlive(zombie))
            continue;

        // Quick range check with DistanceSquared (avoids sqrt)
        if(DistanceSquared(player_origin, zombie.origin) > range_sq)
            continue;

        // Get target point (head)
        target_point = zombie GetEye();
        if(!IsDefined(target_point))
            target_point = zombie.origin + (0, 0, 60);

        dist = Distance(player_origin, target_point);

        // Check line of sight (expensive, only for in-range zombies)
        if(!SightTracePassed(player_origin, target_point, false, self))
            continue;

        // Score: closer = better, in front = better
        to_target = VectorNormalize(target_point - player_origin);
        dot = VectorDot(player_forward, to_target);

        dist_score = 1.0 - (dist / aim_range);
        facing_score = (dot + 1.0) / 2.0;

        // Distance weighted higher -- blind players can't aim, closest matters most
        score = (dist_score * 0.7) + (facing_score * 0.3);

        if(score > best_score)
        {
            best_score = score;
            best_target = zombie;
        }
    }

    if(IsDefined(best_target))
    {
        result = SpawnStruct();
        result.target = best_target;
        result.score = best_score;
        return result;
    }
    return undefined;
}

function score_target(target)
{
    if(!IsDefined(target) || !IsAlive(target))
        return -999999;

    player_origin = self GetEye();
    player_angles = self GetPlayerAngles();
    player_forward = AnglesToForward(player_angles);

    aim_range = 1000;
    if(IsDefined(level.accessibility) && IsDefined(level.accessibility.aim_range))
        aim_range = level.accessibility.aim_range;
    range_sq = aim_range * aim_range;

    if(DistanceSquared(player_origin, target.origin) > range_sq)
        return -999999;

    target_point = target GetEye();
    if(!IsDefined(target_point))
        target_point = target.origin + (0, 0, 60);

    dist = Distance(player_origin, target_point);

    if(!SightTracePassed(player_origin, target_point, false, self))
        return -999999;

    to_target = VectorNormalize(target_point - player_origin);
    dot = VectorDot(player_forward, to_target);

    dist_score = 1.0 - (dist / aim_range);
    facing_score = (dot + 1.0) / 2.0;

    return (dist_score * 0.7) + (facing_score * 0.3);
}

function snap_aim_to_target(target)
{
    if(!IsDefined(target) || !IsAlive(target))
        return;

    player_eye = self GetEye();

    // Determine aim point - always head for accessibility
    target_point = target GetEye();
    if(!IsDefined(target_point))
        target_point = target.origin + (0, 0, 60);

    // Calculate desired angles
    delta = target_point - player_eye;
    desired_angles = VectorToAngles(delta);

    // Instant snap -- blind players gain nothing from gradual interpolation
    // Use normalize_angle to handle the 0/360 yaw boundary correctly
    current_angles = self GetPlayerAngles();
    new_pitch = current_angles[0] + normalize_angle(desired_angles[0] - current_angles[0]);
    new_yaw = current_angles[1] + normalize_angle(desired_angles[1] - current_angles[1]);

    self SetPlayerAngles((new_pitch, new_yaw, 0));
}

function auto_fire_at_target(target)
{
    if(!IsDefined(target) || !IsAlive(target))
        return;

    player_eye = self GetEye();
    target_point = target GetEye();
    if(!IsDefined(target_point))
        target_point = target.origin + (0, 0, 60);

    // Check if we have line of sight
    if(SightTracePassed(player_eye, target_point, false, self))
    {
        // Fire using MagicBullet from player's weapon
        weapon = self GetCurrentWeapon();
        if(IsDefined(weapon) && weapon != level.weaponNone)
        {
            MagicBullet(weapon, player_eye, target_point, self);
            self.accessibility._last_fire_time = GetTime();
        }
    }
}

// Normalize angle difference to [-180, 180] range
// Fixes the 0/360 yaw boundary wrapping bug
function normalize_angle(angle)
{
    while(angle > 180)
        angle -= 360;
    while(angle < -180)
        angle += 360;
    return angle;
}
