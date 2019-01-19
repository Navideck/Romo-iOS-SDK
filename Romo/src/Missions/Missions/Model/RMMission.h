//
//  RMMission.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMProgressManager.h"

@class RMUnlockable;
@class RMAction;
@class RMActionRuntime;
@class RMEvent;

@protocol RMMissionDelegate;

typedef enum {
    /** The mission wasn't failed */
    RMMissionFailureReasonNone       = 0,
    RMMissionFailureReasonWrongInput = 1,
    RMMissionFailureReasonUndocked   = 2,
    RMMissionFailureReasonTurning    = 3,
    RMMissionFailureReasonTilting    = 4,
    RMMissionFailureReasonFlipped    = 5,
    RMMissionFailureReasonTimedOut   = 6,
} RMMissionFailureReason;

@interface RMMission : NSObject

/** The chapter this mission is in */
@property (nonatomic, readonly) RMChapter chapter;

/** The index into the chapter that this mission is */
@property (nonatomic, readonly) NSInteger index;

/** A delegate to receive runtime messages */
@property (nonatomic, weak) id<RMMissionDelegate> delegate;

/** List of events added to the mission */
@property (nonatomic, strong) NSMutableArray *events;

/** Array of action scripts, ordered to match events */
@property (nonatomic, strong) NSMutableArray *inputScripts;

/** Array of action scripts, ordered to match events, influence by real-world events */
@property (nonatomic, strong) NSMutableArray *outputScripts;

/** How many times an event occured */
@property (nonatomic, strong) NSMutableArray *eventTriggerCounts;

/** Whether or not the mission is executing */
@property (nonatomic, getter = isRunning) BOOL running;

/** The runtime that missions execute in */
@property (nonatomic, strong) RMActionRuntime *actionRuntime;

/** The vision modules needed to run the current mission */
@property (nonatomic, readonly) NSSet *visionModules;

/** Runs the script for this event */
- (void)runScriptForEvent:(RMEvent *)event;

/** Expands nested scripts inside this script to make an entirely flat array of actions */
+ (NSArray *)flattenedScript:(NSArray *)script;

/**
 Merges neighboring actions with the same values if possible
 e.g. "Turn clockwise 40°" then "Turn clockwise 50°" merges into "Turn clockwise 90°"
 */
+ (NSArray *)mergedScript:(NSArray *)script;

/** If available, loads the saved user-defined solution from disk */
- (void)loadSolutionFromDisk:(NSString *)name;

/** Saves the input to disk */
- (void)saveSolutionToDisk:(NSString *)name;

/**
 Returns how many starts the solution earns for this Mission
 0 -> incorrect
 1,2,3 -> correct
 */
@property (nonatomic, readonly) int starCount;

/**
 The reason the user failed the mission
 If the user didn't fail, this will be RMMissionFailureReasonNone
 */
@property (nonatomic) RMMissionFailureReason reasonForFailing;

/**
 If the user earned one star, this is the reason they didn't get two stars
 If the user earned two stars, this is the reason they didn't get three stars
 Otherwise, this will be RMMissionFailureReasonNone
 */
@property (nonatomic) RMMissionFailureReason reasonForImperfectSolution;

/**
 The status of the Mission, automatically saved when set.
 If a Mission already had Successful status, setting it to Failed does nothing.
 Missions cannot be set to Locked or New; these values are set automatically based on Progress Manager
 Upon successful status setting, the user's solution is written to disk
 */
@property (nonatomic) RMMissionStatus status;

/** These properties are set automatically by mission dictionaries */
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *briefing;
@property (nonatomic, readonly) NSString *failureDebriefing;
@property (nonatomic, readonly) NSString *successDebriefing;
@property (nonatomic, readonly) NSString *congratsDebriefing;
@property (nonatomic, readonly) NSString *promptToPlay;
@property (nonatomic, readonly) NSInteger maximumActionCount;
@property (nonatomic, readonly) BOOL allowsAddingEvents;
@property (nonatomic, readonly) BOOL allowsEditingParameters;
@property (nonatomic, readonly) BOOL allowsAddingActions;
@property (nonatomic, readonly) BOOL allowsDeletingActions;
@property (nonatomic, readonly) NSArray *availableEvents;
@property (nonatomic, readonly) NSArray *availableActions;
@property (nonatomic, readonly) NSArray *lockedActions;
@property (nonatomic, readonly) BOOL allowsViewingEvents;
@property (nonatomic, readonly) BOOL glowActionViews;
@property (nonatomic, readonly) BOOL skipCollapseScripts;
@property (nonatomic, readonly) BOOL disableFlipDetection;
@property (nonatomic, readonly) BOOL allowsRepeat;
@property (nonatomic, readonly) BOOL allowsEditingRepeat;
@property (nonatomic, readonly) BOOL lightInitiallyOff;
@property (nonatomic, readonly) int duration;

@property (nonatomic, readonly) BOOL skipBriefing;
@property (nonatomic, readonly) BOOL skipDebriefing;

/** An array of unlocked achievements when the mission is accomplished */
@property (nonatomic, readonly) NSArray *unlockables;

/**
 Mission-X-Y.plist:
 X = chapter
 Y = index
 
 The file should be a dictionary with the following options:

 "title" -> String title of the mission

 "briefing" -> goal of the mission
 
 "failure debriefing" -> explanation of why the user might have failed
 
 "success debriefing" -> explanation of how the user can get three stars

 "congrats debriefing" -> shown when the user earns three stars
 
 "prompt" -> a prompt said by Romo asking the user to play this mission

 "adding events" -> whether or not users can add events, BOOL

 "editing parameters" -> whether or not the user can edit parameters of actions, BOOL

 "adding actions" -> whether or not the user can add new actions, BOOL, defaults to YES

 "deleting actions" -> whether or not the user can delete actions, BOOL, defaults to YES

 "actions" -> available actions for a user to add, an array of actions, if not provided, all actions will be available

 "max action count" -> max number of actions allowed in a script, NSNumber, optional, defaults to -1

 "mission" -> a dictionary representation of the mission
 
 "unlockables" -> an array of unlockable dictionary representations
 
 "x star solution" (x = {1,2,3}) -> a dictionary for each event, with rules and properties defined
 
 "glow action views" -> a BOOL indicating if newly added action views should have a pulsing glow
 
 "skip collapse scripts" -> a BOOL indicating if, when checking against solutions, user's scripts should be collapsed
 
 "disable flip detection" -> a BOOL that ignores flip events for this mission
 
 "allows repeat" -> a BOOL that states if repeat is allowed, defaults to NO

 "editing repeat" -> a BOOL that states if editing repeat for events is allowed, defaults to YES
 
 "duration" -> an int duration that the mission will be forced to run for, without this, the mission expires after all events occur
 
 */
- (id)initWithChapter:(RMChapter)chapter index:(NSInteger)index;

- (void)incrementAvailableCountForAction:(RMAction *)action;
- (void)decrementAvailableCountForAction:(RMAction *)action;

/** Duplicates the action's parameters to all available actions of this type */
- (void)updateAvailableActionsToMatchAction:(RMAction *)action;

/** Duplicates the inputScript into outputScript */
- (void)prepareToRun;

@end

@protocol RMMissionDelegate <NSObject>

- (void)mission:(RMMission *)mission eventDidOccur:(RMEvent *)event;
- (void)mission:(RMMission *)mission scriptForEventDidFinish:(RMEvent *)event;
- (void)missionFinishedRunningAllScripts:(RMMission *)mission;

@end

extern NSString *const savedSolutionKey;
