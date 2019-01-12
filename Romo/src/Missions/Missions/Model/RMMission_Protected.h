//
//  RMMission_Protected.h
//  Romo
//

#import "RMMission.h"

@interface RMMission ()

@property (nonatomic, strong) RMProgressManager *progressManager;

@property (nonatomic, readwrite) RMChapter chapter;
@property (nonatomic, readwrite) NSInteger index;

@property (nonatomic, strong) RMEvent *currentEvent;
@property (nonatomic, strong) NSArray *currentScript;
@property (nonatomic) NSInteger indexOfCurrentScript;

@property (nonatomic) int currentMethodIndex;
@property (nonatomic) int completedMethodCount;
@property (nonatomic, copy) __block void (^completion)(BOOL finished);

@property (nonatomic, strong, readwrite) NSMutableSet *visionModules;

/**
 Whenever a script is fully ran, a BOOL flag is set at the index of that script
 When all scripts are completed, a message is passed to the delegate
 */
@property (nonatomic, strong) NSMutableDictionary *completedScripts;

/**
 @"rules" -> An array of Rule arrays
 @"properties" -> An array of Property sets
 @"events" -> An array of Events
 */
@property (nonatomic, strong) NSDictionary *oneStarSolution;
@property (nonatomic, strong) NSDictionary *twoStarSolution;
@property (nonatomic, strong) NSDictionary *threeStarSolution;

@property (nonatomic, readwrite, getter=isValid) BOOL valid;
@property (nonatomic, readwrite, strong) NSArray *unlockables;

@property (nonatomic, strong, readwrite) NSString *title;
@property (nonatomic, strong, readwrite) NSString *briefing;
@property (nonatomic, strong, readwrite) NSString *failureDebriefing;
@property (nonatomic, strong, readwrite) NSString *successDebriefing;
@property (nonatomic, strong, readwrite) NSString *congratsDebriefing;
@property (nonatomic, strong, readwrite) NSString *promptToPlay;
@property (nonatomic, readwrite) NSInteger maximumActionCount;
@property (nonatomic, readwrite) BOOL allowsAddingEvents;
@property (nonatomic, readwrite) BOOL allowsEditingParameters;
@property (nonatomic, readwrite) BOOL allowsAddingActions;
@property (nonatomic, readwrite) BOOL allowsDeletingActions;
@property (nonatomic, strong, readwrite) NSArray *availableEvents;
@property (nonatomic, strong, readwrite) NSArray *availableActions;
@property (nonatomic, strong, readwrite) NSArray *lockedActions;
@property (nonatomic, readwrite) BOOL allowsViewingEvents;
@property (nonatomic, readwrite) BOOL glowActionViews;
@property (nonatomic, readwrite) BOOL skipCollapseScripts;
@property (nonatomic, readwrite) BOOL skipBriefing;
@property (nonatomic, readwrite) BOOL skipDebriefing;
@property (nonatomic, readwrite) BOOL disableFlipDetection;
@property (nonatomic, readwrite) BOOL allowsRepeat;
@property (nonatomic, readwrite) BOOL allowsEditingRepeat;
@property (nonatomic, readwrite) BOOL lightInitiallyOff;
@property (nonatomic, readwrite) int duration;

@end
