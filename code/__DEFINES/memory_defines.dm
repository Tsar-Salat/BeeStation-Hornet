///name of the file that has all the memory strings
#define MEMORY_FILE "memories.json"

///moodlet set if the creature with the memory doesn't use mood (doesn't include mood line)
#define MOODLESS_MEMORY "nope"

// How cool a story is!
/// This is a key memory and isn't really cool but is important. Shows a key icon.
#define STORY_VALUE_KEY -1
/// This memory is not very good. It's very common. Shows a poo icon.
#define STORY_VALUE_SHIT 0
/// This memory is relatively normal and common. Neutral face icon.
#define STORY_VALUE_NONE 1
/// This memory is pretty decent. Shows a bronze star.
#define STORY_VALUE_MEH 2
/// This memory is alright. Shows a silver star.
#define STORY_VALUE_OKAY 3
/// This memory is outstanding, and will stick with you forever. Shows a gold star.
#define STORY_VALUE_AMAZING 4
/// This memory is insanely good, and can't get obtained just normally. Platinum star.
#define STORY_VALUE_LEGENDARY 5

//Flags for memories
///this memory doesn't have a location, omit that
#define MEMORY_FLAG_NOLOCATION (1<<0)
///this memory's protagonist for one reason or another doesn't have a mood, omit that
#define MEMORY_FLAG_NOMOOD (1<<1)
///this memory shouldn't include the station name (example: revolution memory)
#define MEMORY_FLAG_NOSTATIONNAME (1<<2)
/// Really shouldn't be saved in persistence, or engraved. Use for stuff like quirk memories.
#define MEMORY_FLAG_NOPERSISTENCE (1<<3)
/// This memory has already been engraved, and cannot be selected for engraving again.
#define MEMORY_FLAG_ALREADY_USED (1<<4)
/// A blind mob cannot experience this memory.
#define MEMORY_CHECK_BLINDNESS (1<<5)
/// A deaf mob cannot experience this memory.
#define MEMORY_CHECK_DEAFNESS (1<<6)
/// A mob which is currently unconscious can experience this memory.
#define MEMORY_SKIP_UNCONSCIOUS (1<<7)
/// This memory can't be selected for tattoo-ing or engraving at all.
#define MEMORY_NO_STORY (1<<8)

//These defines are for what the story is for, they should be defined as what part of the json file they interact with
///changeling memory reading
#define STORY_CHANGELING_ABSORB "changeling_absorb"

//These defines are story flags for including special bits on the generated story.
///include a date this event happened
#define STORY_FLAG_DATED (1<<0)
/// Don't style this story
#define STORY_FLAG_NO_STYLE (1<<1)
