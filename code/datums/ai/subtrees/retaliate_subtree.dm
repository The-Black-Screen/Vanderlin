/// Sets the BB target to a mob which you can see and who has recently attacked you
/datum/ai_planning_subtree/target_retaliate
	/// Blackboard key which tells us how to select valid targets
	var/targetting_datum_key = BB_TARGETTING_DATUM
	/// Blackboard key in which to store selected target
	var/target_key = BB_BASIC_MOB_CURRENT_TARGET
	/// Blackboard key in which to store selected target's hiding place
	var/hiding_place_key = BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION

/datum/ai_planning_subtree/target_retaliate/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	. = ..()
	controller.queue_behavior(/datum/ai_behavior/target_from_retaliate_list, BB_BASIC_MOB_RETALIATE_LIST, target_key, targetting_datum_key, hiding_place_key)

/datum/ai_planning_subtree/target_retaliate/bum/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	. = ..()
	controller.queue_behavior(/datum/ai_behavior/target_from_retaliate_list/bum, BB_BASIC_MOB_RETALIATE_LIST, target_key, targetting_datum_key, hiding_place_key)


/// Places a mob which you can see and who has recently attacked you into some 'run away from this' AI keys
/// Can use a different targetting datum than you use to select attack targets
/// Not required if fleeing is the only target behaviour or uses the same target datum
/datum/ai_planning_subtree/target_retaliate/to_flee
	targetting_datum_key = BB_FLEE_TARGETTING_DATUM
	target_key = BB_BASIC_MOB_FLEE_TARGET
	hiding_place_key = BB_BASIC_MOB_FLEE_TARGET_HIDING_LOCATION

/**
 * Picks a target from a provided list of atoms who have been pissing you off
 * You will probably need /datum/element/ai_retaliate to take advantage of this unless you're populating the blackboard yourself
 */
/datum/ai_behavior/target_from_retaliate_list
	action_cooldown = 2 SECONDS
	/// How far can we see stuff?
	var/vision_range = 8
	/// How long (from the last time the mob hit us) we remember them as enemies
	var/remember_retaliate_time = 2 MINUTES

/datum/ai_behavior/target_from_retaliate_list/perform(seconds_per_tick, datum/ai_controller/controller, shitlist_key, target_key, targetting_datum_key, hiding_location_key)
	. = ..()
	var/mob/living/living_mob = controller.pawn
	var/datum/targetting_datum/targetting_datum = controller.blackboard[targetting_datum_key]
	if(!targetting_datum)
		CRASH("No target datum was supplied in the blackboard for [controller.pawn]")

	var/list/enemies_list = controller.blackboard[shitlist_key]
	if (!length(enemies_list))
		finish_action(controller, succeeded = FALSE)
		return

	if(!can_attack_target(living_mob, controller.blackboard[target_key], targetting_datum))
		controller.clear_blackboard_key(target_key)

	if (controller.blackboard[target_key] in enemies_list) // Don't bother changing
		finish_action(controller, succeeded = FALSE)
		return

	// Clears enemies from enemies_list
	for(var/mob/living/living_target as anything in enemies_list)
		if(enemies_list[living_target] + remember_retaliate_time < world.time)
			enemies_list -= living_target
	if(!length(enemies_list))
		finish_action(controller, succeeded = FALSE)
		return

	var/list/potential_targets = enemies_list.Copy()
	for(var/mob/living/living_target in potential_targets)
		if(can_attack_target(living_mob, living_target, targetting_datum))
			continue
		var/extra_chance = (living_mob.health <= living_mob.maxHealth * 50) ? 30 : 0 // if we're below half health, we're way more alert
		if(living_mob.npc_detect_sneak(living_target, extra_chance))
			continue
		potential_targets -= living_target

	if(!length(potential_targets))
		finish_action(controller, succeeded = FALSE)
		return

	var/atom/new_target = pick_final_target(controller, potential_targets)
	controller.set_blackboard_key(target_key, new_target)

	var/atom/potential_hiding_location = targetting_datum.find_hidden_mobs(living_mob, new_target)

	if(potential_hiding_location) //If they're hiding inside of something, we need to know so we can go for that instead initially.
		controller.set_blackboard_key(hiding_location_key, potential_hiding_location)

	finish_action(controller, succeeded = TRUE)

/// Returns true if this target is valid for attacking based on current conditions
/datum/ai_behavior/target_from_retaliate_list/proc/can_attack_target(mob/living/living_mob, atom/target, datum/targetting_datum/targetting_datum)
	if (!target)
		return FALSE
	if (target == living_mob)
		return FALSE
	if (!can_see(living_mob, target, vision_range))
		return FALSE
	return targetting_datum.can_attack(living_mob, target)

/// Returns the desired final target from the filtered list of enemies
/datum/ai_behavior/target_from_retaliate_list/proc/pick_final_target(datum/ai_controller/controller, list/enemies_list)
	return pick(enemies_list)

/datum/ai_behavior/target_from_retaliate_list/bum/finish_action(datum/ai_controller/controller, succeeded, ...)
	. = ..()
	if(succeeded)
		var/mob/living/pawn = controller.pawn
		pawn.say(pick(GLOB.bum_aggro))
