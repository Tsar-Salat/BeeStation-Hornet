#define REPORT_WAIT_TIME_MINIMUM 600
#define REPORT_WAIT_TIME_MAXIMUM 1500

PROCESSING_SUBSYSTEM_DEF(station)
	name = "Station"
	init_order = INIT_ORDER_STATION
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME
	wait = 5 SECONDS

	///A list of currently active station traits
	var/list/station_traits
	///Assoc list of trait type || assoc list of traits with weighted value. Used for picking traits from a specific category.
	var/list/selectable_traits_by_types
	///Currently active announcer. Starts as a type but gets initialized after traits are selected
	var/datum/centcom_announcer/announcer = /datum/centcom_announcer/default

/datum/controller/subsystem/processing/station/Initialize()

	station_traits = list()
	selectable_traits_by_types = list(STATION_TRAIT_POSITIVE = list(), STATION_TRAIT_NEUTRAL = list(), STATION_TRAIT_NEGATIVE = list(), STATION_TRAIT_EXCLUSIVE = list())

	//If doing unit tests we don't do none of that trait shit ya know?
	#ifndef UNIT_TESTS
	if(CONFIG_GET(flag/station_traits))
		SetupTraits()
		prepare_report()
	#endif

	announcer = new announcer() //Initialize the station's announcer datum

	return SS_INIT_SUCCESS

///Rolls for the amount of traits and adds them to the traits list
/datum/controller/subsystem/processing/station/proc/SetupTraits()
	if (fexists(FUTURE_STATION_TRAITS_FILE))
		var/forced_traits_contents = file2text(FUTURE_STATION_TRAITS_FILE)
		fdel(FUTURE_STATION_TRAITS_FILE)

		var/list/forced_traits_text_paths = json_decode(forced_traits_contents)
		forced_traits_text_paths = SANITIZE_LIST(forced_traits_text_paths)

		for (var/trait_text_path in forced_traits_text_paths)
			var/station_trait_path = text2path(trait_text_path)
			if (!ispath(station_trait_path, /datum/station_trait) || station_trait_path == /datum/station_trait)
				var/message = "Invalid station trait path [station_trait_path] was requested in the future station traits!"
				log_game(message)
				message_admins(message)
				continue

			setup_trait(station_trait_path)

		return

	for(var/i in subtypesof(/datum/station_trait))
		var/datum/station_trait/trait_typepath = i

		// If forced, (probably debugging), just set it up now, keep it out of the pool.
		if(initial(trait_typepath.force))
			setup_trait(trait_typepath)
			continue

		if(initial(trait_typepath.trait_flags) & STATION_TRAIT_ABSTRACT)
			continue //Dont add abstract ones to it

		if(!(initial(trait_typepath.trait_flags) & STATION_TRAIT_PLANETARY) && SSmapping.is_planetary()) // we're on a planet but we can't do planet ;_;
			continue

		if(!(initial(trait_typepath.trait_flags) & STATION_TRAIT_SPACE_BOUND) && !SSmapping.is_planetary()) //we're in space but we can't do space ;_;
			continue

		selectable_traits_by_types[initial(trait_typepath.trait_type)][trait_typepath] = initial(trait_typepath.weight)

	var/positive_trait_count = pick(20;0, 5;1, 1;2)
	var/neutral_trait_count = pick(10;0, 10;1, 3;2)
	var/negative_trait_count = pick(20;0, 5;1, 1;2)

	var/possible_types = list(STATION_TRAIT_POSITIVE, STATION_TRAIT_NEUTRAL, STATION_TRAIT_NEGATIVE, STATION_TRAIT_EXCLUSIVE)
	while(length(possible_types))
		var/picked = pick_n_take(possible_types)
		switch(picked)
			if(STATION_TRAIT_POSITIVE)
				pick_traits(STATION_TRAIT_POSITIVE, positive_trait_count)
			if(STATION_TRAIT_NEUTRAL)
				pick_traits(STATION_TRAIT_NEUTRAL, neutral_trait_count)
			if(STATION_TRAIT_NEGATIVE)
				pick_traits(STATION_TRAIT_NEGATIVE, negative_trait_count)
			if(STATION_TRAIT_EXCLUSIVE)
				adds_exclusive_traits()

///Picks traits of a specific category (e.g. bad or good) and a specified amount, then initializes them and adds them to the list of traits.
/datum/controller/subsystem/processing/station/proc/pick_traits(trait_sign, amount)
	if(!amount)
		return
	for(var/iterator in 1 to amount)
		var/datum/station_trait/trait_type = pick_weight(selectable_traits_by_types[trait_sign]) //Rolls from the table for the specific trait type
		setup_trait(trait_type)

///Creates a given trait of a specific type, while also removing any blacklisted ones from the future pool.
/datum/controller/subsystem/processing/station/proc/setup_trait(datum/station_trait/trait_type)
	if(locate(trait_type) in station_traits)
		return
	var/datum/station_trait/trait_instance = new trait_type()
	station_traits += trait_instance
	selectable_traits_by_types[initial(trait_instance.trait_type)] -= trait_instance.type //No rolling twice
	log_game("Station Trait: [trait_instance.name] chosen for this round.")
	if(!trait_instance.blacklist)
		return
	for(var/i in trait_instance.blacklist)
		var/datum/station_trait/trait_to_remove = i
		selectable_traits_by_types[initial(trait_to_remove.trait_type)] -= trait_to_remove

///Adds exclusive station trait based on each weight regardless of count
/datum/controller/subsystem/processing/station/proc/adds_exclusive_traits()
	for(var/datum/station_trait/each_trait as() in selectable_traits_by_types[STATION_TRAIT_EXCLUSIVE])
		if(!prob(initial(each_trait.weight)))
			continue
		each_trait = new each_trait()
		station_traits += each_trait
		if(!each_trait.blacklist)
			continue
		for(var/i in each_trait.blacklist)
			var/datum/station_trait/trait_to_remove = i
			selectable_traits_by_types[initial(trait_to_remove.trait_type)] -= trait_to_remove

/datum/controller/subsystem/processing/station/proc/prepare_report()
	if(!station_traits.len)		//no active traits why bother
		return

	var/report = "<b><i>Central Command Divergency Report</i></b><hr>"

	for(var/datum/station_trait/trait as() in station_traits)
		if(trait.trait_flags & STATION_TRAIT_ABSTRACT)
			continue
		if(!trait.report_message || !trait.show_in_report)
			continue
		report += "[trait.get_report()]<BR><hr>"

	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(print_command_report), report, "Central Command Divergency Report", FALSE), rand(REPORT_WAIT_TIME_MINIMUM, REPORT_WAIT_TIME_MAXIMUM))

#undef REPORT_WAIT_TIME_MINIMUM
#undef REPORT_WAIT_TIME_MAXIMUM
