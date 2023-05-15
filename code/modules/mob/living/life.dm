/mob/living/proc/Life(delta_time, times_fired)
	set waitfor = FALSE
	set invisibility = 0

	SEND_SIGNAL(src, COMSIG_LIVING_LIFE, delta_time, times_fired)

	if((movement_type & FLYING) && !(movement_type & FLOATING))	//TODO: Better floating
		float(on = TRUE)

	if (notransform)
		return
	if(!loc)
		return

	if(!has_status_effect(STATUS_EFFECT_STASIS))

		if(stat != DEAD)
			//Mutations and radiation
			handle_mutations_and_radiation()

		if(stat != DEAD)
			//Breathing, if applicable
			handle_breathing(times_fired)

		handle_diseases()// DEAD check is in the proc itself; we want it to spread even if the mob is dead, but to handle its disease-y properties only if you're not.

		if (QDELETED(src)) // diseases can qdel the mob via transformations
			return

		if(stat != DEAD)
			//Random events (vomiting etc)
			handle_random_events()

		//Handle temperature/pressure differences between body and environment
		var/datum/gas_mixture/environment = loc.return_air()
		if(environment)
			handle_environment(environment)

		//Handle gravity
		var/gravity = has_gravity()
		update_gravity(gravity)

		if(gravity > STANDARD_GRAVITY)
			if(!get_filter("gravity"))
				add_filter("gravity",1,list("type"="motion_blur", "x"=0, "y"=0))
			handle_high_gravity(gravity)

		if(stat != DEAD)
			handle_traits(delta_time) // eye, ear, brain damages
			handle_status_effects(delta_time) //all special effects, stun, knockdown, jitteryness, hallucination, sleeping, etc

	handle_fire()

	if(machine)
		machine.check_eye(src)

	if(stat != DEAD)
		return 1

/mob/living/proc/handle_breathing(times_fired)
	return

/mob/living/proc/handle_mutations_and_radiation()
	radiation = 0 //so radiation don't accumulate in simple animals
	return

/mob/living/proc/handle_diseases()
	return

/mob/living/proc/handle_random_events()
	return

/mob/living/proc/handle_environment(datum/gas_mixture/environment)
	return

/mob/living/proc/handle_fire()
	if(fire_stacks < 0) //If we've doused ourselves in water to avoid fire, dry off slowly
		fire_stacks = min(0, fire_stacks + 1)//So we dry ourselves back to default, nonflammable.
	if(!on_fire)
		return TRUE //the mob is no longer on fire, no need to do the rest.
	if(fire_stacks > 0)
		adjust_fire_stacks(-0.1) //the fire is slowly consumed
	else
		ExtinguishMob()
		return TRUE //mob was put out, on_fire = FALSE via ExtinguishMob(), no need to update everything down the chain.
	var/datum/gas_mixture/G = loc.return_air() // Check if we're standing in an oxygenless environment
	if(G.get_moles(GAS_O2) < 1)
		ExtinguishMob() //If there's no oxygen in the tile we're on, put out the fire
		return TRUE
	var/turf/location = get_turf(src)
	location.hotspot_expose(700, 50, 1)

/**
 * Get the fullness of the mob
 *
 * This returns a value form 0 upwards to represent how full the mob is.
 * The value is a total amount of consumable reagents in the body combined
 * with the total amount of nutrition they have.
 * This does not have an upper limit.
 */
/mob/living/proc/get_fullness()
	var/fullness = nutrition
	// we add the nutrition value of what we're currently digesting
	for(var/bile in reagents.reagent_list)
		var/datum/reagent/consumable/bits = bile
		if(bits)
			fullness += bits.nutriment_factor * bits.volume / bits.metabolization_rate
	return fullness

/**
 * Check if the mob contains this reagent.
 *
 * This will validate the the reagent holder for the mob and any sub holders contain the requested reagent.
 * Vars:
 * * reagent (typepath) takes a PATH to a reagent.
 * * amount (int) checks for having a specific amount of that chemical.
 * * needs_metabolizing (bool) takes into consideration if the chemical is matabolizing when it's checked.
 */
/mob/living/proc/has_reagent(reagent, amount = -1, needs_metabolizing = FALSE)
	return reagents.has_reagent(reagent, amount, needs_metabolizing)

//this updates all special effects: knockdown, druggy, stuttering, etc..
/mob/living/proc/handle_status_effects(delta_time)
	if(confused)
		confused = max(0, confused - (1 * delta_time))

/mob/living/proc/handle_traits(delta_time)
	//Eyes
	if(eye_blind)			//blindness, heals slowly over time
		if(!stat && !(HAS_TRAIT(src, TRAIT_BLIND)))
			eye_blind = max(eye_blind - delta_time, 0)
			if(client && !eye_blind)
				clear_alert("blind")
				clear_fullscreen("blind")
			//Prevents healing blurryness while blind from normal means
			return
		else
			eye_blind = max(eye_blind - delta_time, 1)
	if(eye_blurry)			//blurry eyes heal slowly
		eye_blurry = max(eye_blurry - delta_time, 0)
		if(client)
			update_eye_blur()

/mob/living/proc/update_damage_hud()
	return

/mob/living/proc/handle_high_gravity(gravity)
	if(gravity >= GRAVITY_DAMAGE_TRESHOLD) //Aka gravity values of 3 or more
		var/grav_stregth = gravity - GRAVITY_DAMAGE_TRESHOLD
		adjustBruteLoss(min(grav_stregth,3))
