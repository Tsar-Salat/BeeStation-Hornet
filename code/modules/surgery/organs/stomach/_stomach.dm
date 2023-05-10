//The contant in the rate of reagent transfer on life ticks
#define STOMACH_METABOLISM_CONSTANT 0.5

/obj/item/organ/stomach
	name = "stomach"
	icon_state = "stomach"
	w_class = WEIGHT_CLASS_SMALL
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_STOMACH
	attack_verb = list("gored", "squished", "slapped", "digested")
	desc = "Onaka ga suite imasu."

	healing_factor = STANDARD_ORGAN_HEALING
	decay_factor = STANDARD_ORGAN_DECAY * 1.15 // ~13 minutes, the stomach is one of the first organs to die

	low_threshold_passed = "<span class='info'>Your stomach flashes with pain before subsiding. Food doesn't seem like a good idea right now.</span>"
	high_threshold_passed = "<span class='warning'>Your stomach flares up with constant pain- you can hardly stomach the idea of food right now!</span>"
	high_threshold_cleared = "<span class='info'>The pain in your stomach dies down for now, but food still seems unappealing.</span>"
	low_threshold_cleared = "<span class='info'>The last bouts of pain in your stomach have died out.</span>"

	//This is a reagent user and needs more then the 10u from edible component
	reagent_vol = 1000

	///The rate that disgust decays
	var/disgust_metabolism = 1

	///The rate that the stomach will transfer reagents to the body
	var/metabolism_efficiency = 0.05 // the lowest we should go is 0.025

/obj/item/organ/stomach/Initialize(mapload)
	. = ..()
	//Non-edible organs do not get a reagent holder by default
	if(!reagents)
		create_reagents(reagent_vol)

/obj/item/organ/stomach/on_life(delta_time, times_fired)
	. = ..()

	//Manage species digestion
	if(istype(owner))
		var/mob/living/carbon/human/humi = owner
		if(!(organ_flags & ORGAN_FAILING))
			handle_hunger(humi, delta_time, times_fired)

	var/mob/living/carbon/body = owner

	// digest food, sent all reagents that can metabolize to the body
	for(var/datum/reagent/bit as anything in reagents.reagent_list)

		// If the reagent does not metabolize then it will sit in the stomach
		// This has an effect on items like plastic causing them to take up space in the stomach
		if(bit.metabolization_rate <= 0)
			continue

		//Ensure that the the minimum is equal to the metabolization_rate of the reagent if it is higher then the STOMACH_METABOLISM_CONSTANT
		var/rate_min = max(bit.metabolization_rate, STOMACH_METABOLISM_CONSTANT)
		//Do not transfer over more then we have
		var/amount_max = bit.volume

		//If the reagent is part of the food reagents for the organ
		//prevent all the reagents form being used leaving the food reagents
		var/amount_food = food_reagents[bit.type]
		if(amount_food)
			amount_max = max(amount_max - amount_food, 0)

		// Transfer the amount of reagents based on volume with a min amount of 1u
		var/amount = min((round(metabolism_efficiency * amount_max, 0.05) + rate_min) * delta_time, amount_max)

		if(!(amount > 0))
			continue

		// transfer the reagents over to the body at the rate of the stomach metabolim
		// this way the body is where all reagents that are processed and react
		// the stomach manages how fast they are feed in a drip style
		reagents.trans_id_to(body, bit.type, amount=amount)

	//Handle disgust
	if(body)
		handle_disgust(body)

	//If the stomach is not damage exit out
	if(damage < low_threshold)
		return

	//We are checking if we have nutriment in a damaged stomach.
	var/datum/reagent/nutri = locate(/datum/reagent/consumable/nutriment) in reagents.reagent_list
	//No nutriment found lets exit out
	if(!nutri)
		return

	// remove the food reagent amount
	var/nutri_vol = nutri.volume
	var/amount_food = food_reagents[nutri.type]
	if(amount_food)
		nutri_vol = max(nutri_vol - amount_food, 0)

	// found nutriment was stomach food reagent
	if(!(nutri_vol > 0))
		return

	//The stomach is damage has nutriment but low on theshhold, lo prob of vomit
	if(DT_PROB(0.0125 * damage * nutri_vol * nutri_vol, delta_time))
		body.vomit(damage)
		to_chat(body, "<span class='warning'>Your stomach reels in pain as you're incapable of holding down all that food!</span>")
		return

	// the change of vomit is now high
	if(damage > high_threshold && DT_PROB(0.05 * damage * nutri_vol * nutri_vol, delta_time))
		body.vomit(damage)
		to_chat(body, "<span class='warning'>Your stomach reels in pain as you're incapable of holding down all that food!</span>")

/obj/item/organ/stomach/proc/handle_hunger(mob/living/carbon/human/human, delta_time, times_fired)
	if(HAS_TRAIT(human, TRAIT_NOHUNGER))
		return //hunger is for BABIES

	//The fucking TRAIT_FAT mutation is the dumbest shit ever. It makes the code so difficult to work with
	if(HAS_TRAIT_FROM(human, TRAIT_FAT, OBESITY))//I share your pain, past coder.
		if(human.overeatduration < (200 SECONDS))
			to_chat(human, "<span class='notice'>You feel fit again!</span>")
			REMOVE_TRAIT(human, TRAIT_FAT, OBESITY)
			human.remove_movespeed_modifier(MOVESPEED_ID_FAT)
			human.update_inv_w_uniform()
			human.update_inv_wear_suit()
	else
		if(human.overeatduration >= (200 SECONDS))
			to_chat(human, "<span class='danger'>You suddenly feel blubbery!</span>")
			ADD_TRAIT(human, TRAIT_FAT, OBESITY)
			human.add_movespeed_modifier(MOVESPEED_ID_FAT)
			human.update_inv_w_uniform()
			human.update_inv_wear_suit()

	// nutrition decrease and satiety
	if (human.nutrition > 0 && human.stat != DEAD)
		// THEY HUNGER
		var/hunger_rate = HUNGER_FACTOR
		var/datum/component/mood/mood = human.GetComponent(/datum/component/mood)
		if(mood && mood.sanity > SANITY_DISTURBED)
			hunger_rate *= max(1 - 0.002 * mood.sanity, 0.5) //0.85 to 0.75
		// Whether we cap off our satiety or move it towards 0
		if(human.satiety > MAX_SATIETY)
			human.satiety = MAX_SATIETY
		else if(human.satiety > 0)
			human.satiety--
		else if(human.satiety < -MAX_SATIETY)
			human.satiety = -MAX_SATIETY
		else if(human.satiety < 0)
			human.satiety++
			if(DT_PROB(round(-human.satiety/77), delta_time))
				human.Jitter(5)
			hunger_rate = 3 * HUNGER_FACTOR
		hunger_rate *= human.physiology.hunger_mod
		human.adjust_nutrition(-hunger_rate * delta_time)

	if(human.nutrition > NUTRITION_LEVEL_FULL)
		if(human.overeatduration < 20 MINUTES) //capped so people don't take forever to unfat
			human.overeatduration = min(human.overeatduration + (1 SECONDS * delta_time), 20 MINUTES)
	else
		if(human.overeatduration > 0)
			human.overeatduration = max(human.overeatduration - (2 SECONDS * delta_time), 0) //doubled the unfat rate

	//metabolism change
	if(human.nutrition > NUTRITION_LEVEL_FAT)
		human.metabolism_efficiency = 1
	else if(human.nutrition > NUTRITION_LEVEL_FED && human.satiety > 80)
		if(human.metabolism_efficiency != 1.25)
			to_chat(human, "<span class='notice'>You feel vigorous.</span>")
			human.metabolism_efficiency = 1.25
	else if(human.nutrition < NUTRITION_LEVEL_STARVING + 50)
		if(human.metabolism_efficiency != 0.8)
			to_chat(human, "<span class='notice'>You feel sluggish.</span>")
		human.metabolism_efficiency = 0.8
	else
		if(human.metabolism_efficiency == 1.25)
			to_chat(human, "<span class='notice'>You no longer feel vigorous.</span>")
		human.metabolism_efficiency = 1

	//Hunger slowdown for if mood isn't enabled
	if(CONFIG_GET(flag/disable_human_mood))
		handle_hunger_slowdown(human)

	switch(human.nutrition)
		if(NUTRITION_LEVEL_FULL to INFINITY)
			human.throw_alert("nutrition", /atom/movable/screen/alert/fat)
		if(NUTRITION_LEVEL_HUNGRY to NUTRITION_LEVEL_FULL)
			human.clear_alert("nutrition")
		if(NUTRITION_LEVEL_STARVING to NUTRITION_LEVEL_HUNGRY)
			human.throw_alert("nutrition", /atom/movable/screen/alert/hungry)
		if(0 to NUTRITION_LEVEL_STARVING)
			human.throw_alert("nutrition", /atom/movable/screen/alert/starving)

///for when mood is disabled and hunger should handle slowdowns
/obj/item/organ/stomach/proc/handle_hunger_slowdown(mob/living/carbon/human/human)
	var/hungry = (500 - human.nutrition) / 5 //So overeat would be 100 and default level would be 80
	if(hungry >= 70)
		human.add_movespeed_modifier(MOVESPEED_ID_HUNGRY, multiplicative_slowdown = (hungry / 50))
	else
		human.remove_movespeed_modifier(MOVESPEED_ID_HUNGRY)

/obj/item/organ/stomach/proc/handle_disgust(mob/living/carbon/human/disgusted, delta_time, times_fired)
	var/old_disgust = disgusted.old_disgust
	var/disgust = disgusted.disgust

	if(disgust)
		var/pukeprob = 2.5 + (0.025 * disgust)
		if(disgust >= DISGUST_LEVEL_GROSS)
			if(DT_PROB(5, delta_time))
				disgusted.stuttering += 2
				disgusted.confused += 2
			if(DT_PROB(5, delta_time) && !disgusted.stat)
				to_chat(disgusted, "<span class='warning'>You feel kind of iffy...</span>")
			disgusted.jitteriness = max(disgusted.jitteriness - 3, 0)
		if(disgust >= DISGUST_LEVEL_VERYGROSS)
			if(DT_PROB(pukeprob, delta_time)) //iT hAndLeS mOrE ThaN PukInG
				disgusted.confused += 2.5
				disgusted.stuttering += 1
				disgusted.vomit(10, 0, 1, 0, 1, 0)
			disgusted.Dizzy(5)
		if(disgust >= DISGUST_LEVEL_DISGUSTED)
			if(DT_PROB(13, delta_time))
				disgusted.blur_eyes(3) //We need to add more shit down here

		disgusted.adjust_disgust(-0.25 * disgust_metabolism * delta_time)

	if(old_disgust == disgust)
		return

	disgusted.old_disgust = disgust
	switch(disgusted.disgust)
		if(0 to DISGUST_LEVEL_GROSS)
			disgusted.clear_alert("disgust")
			SEND_SIGNAL(disgusted, COMSIG_CLEAR_MOOD_EVENT, "disgust")
		if(DISGUST_LEVEL_GROSS to DISGUST_LEVEL_VERYGROSS)
			disgusted.throw_alert("disgust", /atom/movable/screen/alert/gross)
			SEND_SIGNAL(disgusted, COMSIG_ADD_MOOD_EVENT, "disgust", /datum/mood_event/gross)
		if(DISGUST_LEVEL_VERYGROSS to DISGUST_LEVEL_DISGUSTED)
			disgusted.throw_alert("disgust", /atom/movable/screen/alert/verygross)
			SEND_SIGNAL(disgusted, COMSIG_ADD_MOOD_EVENT, "disgust", /datum/mood_event/verygross)
		if(DISGUST_LEVEL_DISGUSTED to INFINITY)
			disgusted.throw_alert("disgust", /atom/movable/screen/alert/disgusted)
			SEND_SIGNAL(disgusted, COMSIG_ADD_MOOD_EVENT, "disgust", /datum/mood_event/disgusted)

/obj/item/organ/stomach/Remove(mob/living/carbon/stomach_owner, special = 0)
	if(ishuman(stomach_owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.clear_alert("disgust")
		SEND_SIGNAL(human_owner, COMSIG_CLEAR_MOOD_EVENT, "disgust")
		human_owner.clear_alert("nutrition")

	return ..()

/obj/item/organ/stomach/bone
	desc = "You have no idea what this strange ball of bones does."
	metabolism_efficiency = 0.025 //very bad

/obj/item/organ/stomach/bone/on_life()
	var/datum/reagent/consumable/milk/milk = locate(/datum/reagent/consumable/milk) in reagents.reagent_list
	if(milk)
		var/mob/living/carbon/body = owner
		if(milk.volume > 10)
			reagents.remove_reagent(milk.type, milk.volume - 10)
			to_chat(owner, "<span class='warning'>The excess milk is dripping off your bones!</span>")
		body.heal_bodypart_damage(1.5,0, 0)
		/*
		for(var/i in body.all_wounds)
			var/datum/wound/iter_wound = i
			iter_wound.on_xadone(2)
		*/
		reagents.remove_reagent(milk.type, milk.metabolization_rate)
	return ..()

/obj/item/organ/stomach/fly
	name = "insectoid stomach"
	icon_state = "stomach-x" //xenomorph liver? It's just a black liver so it fits.
	desc = "A mutant stomach designed to handle the unique diet of a flyperson."

/obj/item/organ/stomach/fly/on_life()
	for(var/bile in reagents.reagent_list)
		if(!istype(bile, /datum/reagent/consumable))
			continue
		var/datum/reagent/consumable/chunk = bile
		if(chunk.nutriment_factor <= 0)
			continue
		var/mob/living/carbon/body = owner
		var/turf/pos = get_turf(owner)
		body.vomit(reagents.total_volume, FALSE, FALSE, 2, TRUE)
		playsound(pos, 'sound/effects/splat.ogg', 50, TRUE)
		body.visible_message("<span class='danger'>[body] vomits on the floor!</span>", \
					"<span class='userdanger'>You throw up on the floor!</span>")
	return ..()

/obj/item/organ/stomach/plasmaman
	name = "digestive crystal"
	icon_state = "stomach-p"
	desc = "A strange crystal that is responsible for metabolizing the unseen energy force that feeds plasmamen."
	metabolism_efficiency = 0.12

/obj/item/organ/stomach/plasmaman/on_life()
	var/datum/reagent/consumable/milk/milk = locate(/datum/reagent/consumable/milk) in reagents.reagent_list
	if(milk)
		var/mob/living/carbon/body = owner
		if(milk.volume > 10)
			reagents.remove_reagent(milk.type, milk.volume - 10)
			to_chat(owner, "<span class='warning'>The excess milk is dripping off your bones!</span>")
		body.heal_bodypart_damage(1.5,0, 0)
		/*
		for(var/i in body.all_wounds)
			var/datum/wound/iter_wound = i
			iter_wound.on_xadone(2)
		*/
		reagents.remove_reagent(milk.type, milk.metabolization_rate)
	return ..()

/obj/item/organ/stomach/cybernetic
	name = "basic cybernetic stomach"
	icon_state = "stomach-c"
	desc = "A basic device designed to mimic the functions of a human stomach"
	organ_flags = ORGAN_SYNTHETIC
	maxHealth = STANDARD_ORGAN_THRESHOLD * 0.5
	var/emp_vulnerability = 80 //Chance of permanent effects if emp-ed.
	metabolism_efficiency = 0.7 // not as good at digestion

/obj/item/organ/stomach/cybernetic/upgraded
	name = "cybernetic stomach"
	icon_state = "stomach-c-u"
	desc = "An electronic device designed to mimic the functions of a human stomach. Handles disgusting food a bit better."
	maxHealth = 1.5 * STANDARD_ORGAN_THRESHOLD
	disgust_metabolism = 2
	emp_vulnerability = 40
	metabolism_efficiency = 0.14

/obj/item/organ/stomach/cybernetic/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(!COOLDOWN_FINISHED(src, severe_cooldown)) //So we cant just spam emp to kill people.
		owner.vomit(stun = FALSE)
		COOLDOWN_START(src, severe_cooldown, 10 SECONDS)
	if(prob(emp_vulnerability/severity)) //Chance of permanent effects
		organ_flags |= ORGAN_FAILING //Starts organ failure - gonna need replacing soon.


#undef STOMACH_METABOLISM_CONSTANT
