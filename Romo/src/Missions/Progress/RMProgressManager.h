
///
//  RMProgressManager.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCharacter.h>

@class RMMission;
@class RMUnlockable;

/**
 IMPORTANT - These int values cannot change
 1-digit numbers are regular chapters
 100's are Comets
 200's are Bonuses
 */
typedef enum {
    /** New Wheels */
    RMChapterOne          = 1,
    /** Favorite Color */
    RMCometFavoriteColor  = 101,
    /** Event Horizon */
    RMChapterTwo          = 2,
    /** Chase */
    RMCometChase          = 102,
    /** Exploration */
    RMChapterThree        = 3,
    /** Line Following */
    RMCometLineFollow     = 103,
    /** The Lab */
    RMChapterTheLab       = 201,
    /** Romo Control */
    RMChapterRomoControl  = 202,
    /** Once all chapters are beaten */
    RMChapterTheEnd  = 1000,
} RMChapter;

/**
 States an RMChapter can be in
 IMPORTANT - These int values cannot change
 */
typedef enum {
    RMChapterStatusNew          = 1,
    RMChapterStatusSeenCutscene = 2,
    RMChapterStatusSeenUnlock   = 6, // an animated unlocking
    RMChapterStatusComplete     = 4,
    RMChapterStatusLocked       = 5,
} RMChapterStatus;

/**
 States an RMMission can be in
 IMPORTANT - These int values cannot change
 */
typedef enum {
    RMMissionStatusNew       = 1,
    RMMissionStatusFailed    = 2,
    RMMissionStatusOneStar   = 3,
    RMMissionStatusTwoStar   = 4,
    RMMissionStatusThreeStar = 5,
    RMMissionStatusLocked    = 6,
} RMMissionStatus;

/**
 The status states for story elements
 IMPORTANT - These int values cannot change
 */
typedef enum {
    RMStoryStatusHidden      = 0,
    RMStoryStatusRevealed    = 1
} RMStoryStatus;

#define chapterIsComet(chapter) (100 < (chapter) && (chapter) < 200)

typedef NSString RMStoryElement;

@interface RMProgressManager : NSObject

/** Returns NSNumber-wrapped RMChapters */
@property (nonatomic, readonly) NSArray *chapters;

/** Returns NSNumber-wrapped RMChapters that have been unlocked */
@property (nonatomic, readonly) NSArray *unlockedChapters;

/**
 All expressions that the Romo has been trained
 */
@property (nonatomic, readonly) NSArray *unlockedExpressions;

/**
 All actions unlocked by the user
 */
@property (nonatomic, readonly) NSArray *unlockedActions;

/**
 All actions that are currently locked to the user
 */
@property (nonatomic, readonly) NSArray *lockedActions;

/**
 All events unlocked by the user
 */
@property (nonatomic, readonly) NSArray *unlockedEvents;

/**
 The newest linear chapter and mission in the storyline that the user has unlocked
 */
@property (nonatomic, readonly) RMChapter newestChapter;
@property (nonatomic, readonly) int newestMission;

/**
 Whenever the user is playing with a chapter, this flag should be set
 to that chapter to ensure we can track playtime-per-chapter analytics
 */
@property (nonatomic) RMChapter currentChapter;

/**
 Stores all photos captured by RMVision for this session
 Note - you can clear this cache and the cache is capped at 6 photos
 */
@property (nonatomic, readonly, strong) NSMutableArray *capturedPhotos;

+ (instancetype)sharedInstance;

/** Returns the total number of missions for a given chapter */
- (int)missionCountForChapter:(RMChapter)chapter;

/** The total number of stars the user has achieved in the given chapter */
- (int)starCountForChapter:(RMChapter)chapter;

/** 
 The percent complete for activities without stars
 This handles all the comets
 */
- (int)percentCompleteForChapter:(RMChapter)chapter;

/** The total number of successful (1, 2, or 3 star) mission in the given chapter */
- (int)successfulMissionCountForChapter:(RMChapter)chapter;

/** Whether or not the chapter has a cutscene at the beginning */
- (BOOL)chapterHasCutscene:(RMChapter)chapter;

/** Sets the storyline status for a given element */
- (BOOL)updateStoryElement:(RMStoryElement *)element
                withStatus:(RMStoryStatus)status;

/** Gets the story status for a given story element */
- (RMStoryStatus)storyStatusForElement:(RMStoryElement *)element;

/**
 Returns whether or not the status was changed
 Successful transitions:
 - Locked -> Any
 - New -> Cutscene or Unlock or Complete
 - Cutscene -> Unlock or Complete
 - Unlock -> Complete
 */
- (BOOL)setStatus:(RMChapterStatus)status forChapter:(RMChapter)chapter;
- (RMChapterStatus)statusForChapter:(RMChapter)chapter;

/**
 Returns whether or not the status was changed
 Successful transitions:
 - Locked -> Any
 - New -> Failed or (1,2,3) stars
 - Failed -> (1,2,3) stars
 - 1 star -> 2 stars
 - 2 stars -> 3 stars
 */
- (BOOL)setStatus:(RMMissionStatus)status forMissionInChapter:(RMChapter)chapter index:(NSInteger)index;
- (RMMissionStatus)statusForMissionInChapter:(RMChapter)chapter index:(NSInteger)index;

/**
 When a Mission is beaten and unlockables are achieved, save their status and unlock new items 
 Returns YES when the item was successfully unlocked, NO if the item had already been unlocked before
 */
- (BOOL)achieveUnlockable:(RMUnlockable *)unlockable;

/**
 Stores the total playtime (sec) for a specific mission
 */
- (void)incrementPlayTime:(double)playTime forMissionInChapter:(RMChapter)chapter index:(NSInteger)index;

#ifdef DEBUG
- (void)resetProgress;
/** 
 Unlocks everything through and including the provided chapter & index, e.g. 2-3 
 */
- (void)fastForwardThroughChapter:(RMChapter)chapter index:(NSInteger)index;
#endif

/**
 Unlocks every action or event when opening the lab
 */
- (void)unlockAllEventsandActions;

@end

extern NSString *initializedVersionKey;

extern NSString *chapterStatusKey;
extern NSString *missionStatusKey;

extern NSString *methodStatusKey;
extern NSString *expressionStatusKey;
extern NSString *emotionStatusKey;

extern NSString *chapterPlaytimeKey;
extern NSString *missionPlaytimeKey;

extern NSString *const characterScriptPrefix;
