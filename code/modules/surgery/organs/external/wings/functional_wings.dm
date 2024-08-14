///hud action for starting and stopping flight
/datum/action/innate/flight
	name = "Toggle Flight"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_IMMOBILE
	icon_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "flight"

/datum/action/innate/flight/Activate()
	var/mob/living/carbon/human/human = owner
	var/obj/item/organ/external/wings/functional/wings = human.getorganslot(ORGAN_SLOT_EXTERNAL_WINGS)
	if(wings && wings.can_fly(human))
		wings.toggle_flight(human)
		if(!(human.movement_type & FLYING))
			to_chat(human, span_notice("You settle gently back onto the ground..."))
		else
			to_chat(human, span_notice("You beat your wings and begin to hover gently above the ground..."))
			human.set_resting(FALSE, TRUE)

///The true wings that you can use to fly and shit (you cant actually shit with them, but it does wing stuff)
/obj/item/organ/external/wings/functional
	///The flight action object
	var/datum/action/innate/flight/fly

	///The preference type for opened wings
	var/wings_open_preference = "wingsopen"
	///The preference type for closed wings
	var/wings_closed_preference = "wings"

	///Are our wings open or closed?
	var/wings_open = FALSE

/obj/item/organ/external/wings/functional/Destroy()
	QDEL_NULL(fly)
	return ..()

/obj/item/organ/external/wings/functional/Insert(mob/living/carbon/reciever, special, drop_if_replaced)
	. = ..()

	if(isnull(fly))
		fly = new
		fly.Grant(reciever)

/obj/item/organ/external/wings/functional/Remove(mob/living/carbon/organ_owner, special)
	. = ..()
	fly?.Remove(organ_owner)

/obj/item/organ/external/wings/functional/on_life(delta_time, times_fired)
	. = ..()
	handle_flight(owner)

///Called on_life(). Handle flight code and check if we're still flying
/obj/item/organ/external/wings/functional/proc/handle_flight(mob/living/carbon/human/human)
	if(human.movement_type & ~FLYING)
		return FALSE
	if(!can_fly(human))
		toggle_flight(human)
		return FALSE
	return TRUE

///Check if we're still eligible for flight (wings covered, atmosphere too thin, etc)
/obj/item/organ/external/wings/functional/proc/can_fly(mob/living/carbon/human/human)
	if(human.stat || human.body_position == LYING_DOWN)
		return FALSE
	//Jumpsuits have tail holes, so it makes sense they have wing holes too
	if(human.wear_suit && ((human.wear_suit.flags_inv & HIDEJUMPSUIT) && (!human.wear_suit.species_exception || !is_type_in_list(src, human.wear_suit.species_exception))))
		to_chat(human, span_warning("Your suit blocks your wings from extending!"))
		return FALSE
	var/turf/location = get_turf(human)
	if(!location)
		return FALSE

	var/datum/gas_mixture/environment = location.return_air()
	if(environment && !(environment.return_pressure() > 30))
		to_chat(human, span_warning("The atmosphere is too thin for you to fly!"))
		return FALSE
	else
		return TRUE

///Slipping but in the air?
/obj/item/organ/external/wings/functional/proc/fly_slip(mob/living/carbon/human/human)
	var/obj/buckled_obj
	if(human.buckled)
		buckled_obj = human.buckled

	to_chat(human, span_notice("Your wings spazz out and launch you!"))

	playsound(human.loc, 'sound/misc/slip.ogg', 50, TRUE, -3)

	for(var/obj/item/choking_hazard in human.held_items)
		human.accident(choking_hazard)

	var/olddir = human.dir

	human.stop_pulling()
	if(buckled_obj)
		buckled_obj.unbuckle_mob(human)
		step(buckled_obj, olddir)
	else
		new /datum/forced_movement(human, get_ranged_target_turf(human, olddir, 4), 1, FALSE, CALLBACK(human, /mob/living/carbon/.proc/spin, 1, 1))
	return TRUE

///UNSAFE PROC, should only be called through the Activate or other sources that check for CanFly
/obj/item/organ/external/wings/functional/proc/toggle_flight(mob/living/carbon/human/human)
	if(!HAS_TRAIT_FROM(human, TRAIT_MOVE_FLYING, SPECIES_FLIGHT_TRAIT))
		human.physiology.stun_mod *= 2
		ADD_TRAIT(human, TRAIT_NO_FLOATING_ANIM, SPECIES_FLIGHT_TRAIT)
		ADD_TRAIT(human, TRAIT_MOVE_FLYING, SPECIES_FLIGHT_TRAIT)
		passtable_on(human, SPECIES_TRAIT)
		open_wings()
	else
		human.physiology.stun_mod *= 0.5
		REMOVE_TRAIT(human, TRAIT_NO_FLOATING_ANIM, SPECIES_FLIGHT_TRAIT)
		REMOVE_TRAIT(human, TRAIT_MOVE_FLYING, SPECIES_FLIGHT_TRAIT)
		passtable_off(human, SPECIES_TRAIT)
		close_wings()

///SPREAD OUR WINGS AND FLLLLLYYYYYY
/obj/item/organ/external/wings/functional/proc/open_wings()
	preference = wings_open_preference
	wings_open = TRUE

	cache_key = generate_icon_cache() //we've changed preference to open, so we only need to update the key and ask for an update to change our sprite
	owner.update_body_parts()

///close our wings
/obj/item/organ/external/wings/functional/proc/close_wings()
	preference = wings_closed_preference
	wings_open = FALSE

	cache_key = generate_icon_cache()
	owner.update_body_parts()
	if(isturf(owner?.loc))
		var/turf/location = loc
		location.Entered(src, NONE)

///Bodypart overlay of function wings, including open and close functionality!
/datum/bodypart_overlay/mutant/wings/functional
	///Are our wings currently open? Change through open_wings or close_wings()
	VAR_PRIVATE/wings_open = FALSE
	///Feature render key for opened wings
	var/open_feature_key = "wingsopen"

/datum/bodypart_overlay/mutant/wings/functional/get_global_feature_list()
	if(wings_open)
		return GLOB.wings_open_list
	else
		return GLOB.wings_list

///Update our wingsprite to the open wings variant
/datum/bodypart_overlay/mutant/wings/functional/proc/open_wings()
	wings_open = TRUE
	feature_key = open_feature_key
	set_appearance_from_name(sprite_datum.name) //It'll look for the same name again, but this time from the open wings list

///Update our wingsprite to the closed wings variant
/datum/bodypart_overlay/mutant/wings/functional/proc/close_wings()
	wings_open = FALSE
	feature_key = initial(feature_key)
	set_appearance_from_name(sprite_datum.name)

/datum/bodypart_overlay/mutant/wings/functional/generate_icon_cache()
	. = ..()
	. += wings_open ? "open" : "closed"




///Wingtypes

///angel wings, which relate to humans. comes with holiness.
/obj/item/organ/external/wings/functional/angel
	name = "angel wings"
	desc = "Holier-than-thou attitude not included."
	sprite_accessory_override = /datum/sprite_accessory/wings_open/angel

	organ_traits = list(TRAIT_HOLY)

///dragon wings, which relate to lizards.
/obj/item/organ/external/wings/functional/dragon
	name = "dragon wings"
	desc = "Hey, HEY- NOT lizard wings. Dragon wings. Mighty dragon wings."
	sprite_accessory_override = /datum/sprite_accessory/wings/dragon

///skeletal wings, which relate to skeletal races.
/obj/item/organ/external/wings/functional/skeleton
	name = "skeletal wings"
	desc = "Powered by pure edgy-teenager-notebook-scribblings. Just kidding. But seriously, how do these keep you flying?!"
	sprite_accessory_override = /datum/sprite_accessory/wings/skeleton

///mothra wings, which relate to moths.
/obj/item/organ/external/wings/functional/moth/mothra
	name = "mothra wings"
	desc = "Fly like the mighty mothra of legend once did."
	sprite_accessory_override = /datum/sprite_accessory/wings/mothra

///megamoth wings, which relate to moths as an alternate choice. they're both pretty cool.
/obj/item/organ/external/wings/functional/moth/megamoth
	name = "megamoth wings"
	desc = "Don't get murderous."
	sprite_accessory_override = /datum/sprite_accessory/wings/megamoth

///fly wings, which relate to flies.
/obj/item/organ/external/wings/functional/fly
	name = "fly wings"
	desc = "Fly as a fly."
	sprite_accessory_override = /datum/sprite_accessory/wings/fly


