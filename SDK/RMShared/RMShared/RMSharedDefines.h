//
//  RMSharedDefines.h
//  RMShared
//

// Put all your debugging/testing flags here, and comment what they do!

#ifdef DEBUG

//#define FORCE_FIRMWARE_UPDATE //there will always be a firmware update available
//#define DEBUG_FIRMWARE_UPDATING //enable logging of firmware updating stuff
//#define DEBUG_CONNECTION //enable logging of robot connection/disconnection
//#define DEBUG_DATA_TRANSPORT //enable logging of general data transport stuff
//#define DEBUG_COMMUNICATION //enable logging of various communication things
//#define DEBUG_ROBOT_CONTROLLER //enable logging of transitions of robot controllers
//#define DEBUG_EXPRESSIONS //enable logging of expression stuff
//#define DEBUG_ROMOSAY //echo what romo is saying to the log
//#define DEBUG_LINE_DETECT //echo line detection module stuff to the log
//#define DEBUG_VIDEO_MODULE // Outputs status messages from video module

//#define DEBUG_WEBSOCKET //enable logging of websocket stuff
//#define DEBUG_TELEPRESENCE_HOST //enable logging of RMTelepresenceHostController

//#define USE_SIMULATED_ROBOT //enables a simulated robot
//#define RESET_PROGRESS //resets the progress of the app
//#define UNLOCK_EVERYTHING //unlocks everything

//#define FAST_MISSIONS // Speeds up the compiling screen, debriefing, etc.
//#define CREATURE_DEBUG //enables debugging of creature behaviors / vision
//#define INTERACTION_SCRIPT_DEBUG //print out interaction scripts step-by-step
//#define ALWAYS_REVEAL_STORY_ELEMENT //reveals the story element every time the creature controller becomes active
//#define ROMO_MEMORY_DEBUG //prints out memory debugging statements when loading, saving, reading, or writing
//#define SKIP_MISSION_PASS // Skips the mission when you hit the banner and returns to the creature
//#define ALWAYS_THREE_STAR_MISSION // Always gives the user a three-star for the last mission
//#define EXPLORE_DEBUG // Displays debuggin info on screen, console, and through DDLog
//#define DEBUG_MOTIVATIONAL_SYSTEM // Prints out detailed motivational information
//#define DEBUG_TRACKER // Prints out debugging information from the object tracker
//#define VISUAL_STASIS_DEBUG // display processed image on screen

//#define CAPTURE_DEBUG_DATA_BUTTON // displays a button on Romo's face to capture & record debugging data

//#define VISION_DEBUG // Logs RMVision events (init/teardown, modules)
//#define SOUND_DEBUG // Plays sounds at full volume (even in DEBUG scheme)
//#define RECORD_AUDIO_ALL_DEVICES // Enables sound recording from RMVideoModule, even on slow devices

#endif
