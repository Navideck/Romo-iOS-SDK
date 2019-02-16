//
//  RMProgressManager.m
//  Romo
//

#import "RMProgressManager.h"
#import <Romo/RMCharacter.h>
#import <Romo/RMMath.h>
#import <Romo/RMPictureModule.h>
#import "RMMission.h"
#import "RMUnlockable.h"
#import "RMAction.h"
#import "RMEvent.h"
#import "RMActionRuntime.h"
#import "RMParameter.h"

#import "RMChaseRobotController.h"
#import "RMFavoriteColorRobotController.h"
#import "RMLineFollowRobotController.h"

static const int currentVersion = 4;
static const int noChapter = -99999;

static const int maximumStoredPhotoCapacity = 6;

NSString *initializedVersionKey = @"progress-version";

NSString *chapterStatusKey = @"chapter-%d-status";
NSString *missionStatusKey = @"mission-%d-%d-status";

NSString *unlockedActionsKey = @"unlocked-methods";
NSString *unlockedEventsKey = @"unlocked-events";
NSString *expressionStatusKey = @"expression-%d-status";
NSString *emotionStatusKey = @"emotion-%d-status";

NSString *chapterPlaytimeKey = @"chapter-%d-playtime-sec";
NSString *missionPlaytimeKey = @"chapter-%d-%d-playtime-sec";

@interface RMProgressManager ()

@property (nonatomic) double chapterStartTime;
@property (nonatomic) RMChapter chapterBeforeBackground;

@property (nonatomic) double missionStartTime;

@property (nonatomic, strong) NSMutableArray *cachedUnlockedChapters;
@property (nonatomic, strong) NSMutableArray *cachedOrderedChapters;
@property (nonatomic, strong) NSMutableArray *cachedUnlockedExpressions;

@property (nonatomic, readwrite, strong) NSMutableArray *capturedPhotos;

@end

@implementation RMProgressManager

+ (instancetype)sharedInstance
{
    static RMProgressManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RMProgressManager alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSInteger initializedVersion = [[NSUserDefaults standardUserDefaults] integerForKey:initializedVersionKey];
        if (initializedVersion < currentVersion) {
            [self reinitializeFromVersionToCurrentVersion:initializedVersion];
        }
#ifdef RESET_PROGRESS
        [self reinitializeFromVersionToCurrentVersion:0];
#endif
        
        [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenUnlock forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterRomoControl]];
        
        _currentChapter = noChapter;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePhotoModuleCapturedNewPhoto:)
                                                     name:RMPictureModuleDidTakePictureNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleLowMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Properties

- (NSArray *)chapters
{
    if (!_cachedOrderedChapters) {
        NSArray *orderedChapters = @[
                                     @(RMChapterOne),
                                     @(RMCometFavoriteColor),
                                     @(RMChapterTwo),
                                     @(RMChapterThree),
                                     @(RMChapterTheEnd)
                                     ];
        
        _cachedOrderedChapters = [NSMutableArray arrayWithCapacity:orderedChapters.count];
        _cachedUnlockedChapters = [NSMutableArray arrayWithCapacity:orderedChapters.count];
        
        // Load in all unlocked chapters in order, except for The Lab...

        for (NSNumber *chapterValue in orderedChapters) {
            RMChapter chapter = chapterValue.intValue;
            RMChapterStatus chapterStatus = [self statusForChapter:chapter];
            if (chapterStatus != RMChapterStatusLocked) {
                [_cachedUnlockedChapters addObject:chapterValue];
            }
        }
        
        // ...Then add in the locked chapters, ordered
        [_cachedOrderedChapters addObjectsFromArray:_cachedUnlockedChapters];
        [orderedChapters enumerateObjectsUsingBlock:^(id chapter, NSUInteger idx, BOOL *stop) {
            if (![self->_cachedOrderedChapters containsObject:chapter]) {
                [self->_cachedOrderedChapters addObject:chapter];
            }
        }];
    }
    return [_cachedOrderedChapters copy];
}

- (NSArray *)unlockedChapters
{
    // Loading chapters also loads unlocked chapters
    [self chapters];
    
    return [_cachedUnlockedChapters copy];
}

- (RMChapter)newestChapter
{
    RMChapterStatus statusOfTheEnd = [self statusForChapter:RMChapterTheEnd];
    if (statusOfTheEnd != RMChapterStatusLocked) {
        // If they've unlocked this chapter, that means they've gotten to the end of the story
        return RMChapterTheEnd;
    } else {
        RMChapter newestChapter = [self.chapters[0] intValue];
        for (NSNumber *chapterValue in self.chapters) {
            RMChapter chapter = chapterValue.intValue;
            RMChapterStatus status = [self statusForChapter:chapter];
            if (status != RMChapterStatusLocked && status != RMChapterStatusComplete && chapter != RMChapterTheLab && chapter != RMChapterRomoControl) {
                newestChapter = chapter;
            }
        }
        return newestChapter;
    }
}

- (int)newestMission
{
    int mission = 1;
    for (int i = 1; i <= [self missionCountForChapter:self.newestChapter]; i++) {
        RMMissionStatus status = [self statusForMissionInChapter:self.newestChapter index:i];
        if (status != RMMissionStatusLocked) {
            mission = i;
        }
    }
    return mission;
}

- (void)setCurrentChapter:(RMChapter)currentChapter
{
    if (currentChapter != _currentChapter) {
        int previousChapter = _currentChapter;
        _currentChapter = currentChapter;
        
        double previousChapterEndTime = currentTime();
        
        if (previousChapter != noChapter) {
            double playTimeInSeconds = previousChapterEndTime - self.chapterStartTime;
            
            [self logPlayTime:playTimeInSeconds forChapter:previousChapter];
        }
        
        self.chapterStartTime = previousChapterEndTime;
    }
}

- (NSArray *)unlockedExpressions
{
    if (!_cachedUnlockedExpressions) {
        _cachedUnlockedExpressions = [NSMutableArray arrayWithCapacity:[RMCharacter numberOfExpressions]];
        
        for (RMCharacterExpression expression = 1; expression <= [RMCharacter numberOfExpressions]; expression++) {
            NSString *expressionKey = [NSString stringWithFormat:expressionStatusKey, expression];
            BOOL unlocked = [[NSUserDefaults standardUserDefaults] boolForKey:expressionKey];
            if (unlocked) {
                [_cachedUnlockedExpressions addObject:@(expression)];
            }
        }
    }
    return [NSArray arrayWithArray:_cachedUnlockedExpressions];
}

- (NSArray *)unlockedActions
{
    NSArray *unlockedActionTitles = [[NSUserDefaults standardUserDefaults] objectForKey:unlockedActionsKey];
    NSArray *allActions = [RMActionRuntime allActions];
    
    // Filter the library's actions to only those who's title is contained in unlockedActionTitles
    NSArray *unlockedActions = [allActions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title IN %@", unlockedActionTitles]];
    
    return unlockedActions;
}

- (NSArray *)lockedActions
{
    NSArray *unlockedActionTitles = [[NSUserDefaults standardUserDefaults] objectForKey:unlockedActionsKey];
    NSArray *allActions = [RMActionRuntime allActions];
    
    // Filter the library's actions to only those who's title is not contained in unlockedActionTitles
    NSArray *lockedActions = [allActions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (title IN %@)", unlockedActionTitles]];
    
    return lockedActions;
}

- (NSArray *)unlockedEvents
{
    NSArray *unlockedEventNames = [[NSUserDefaults standardUserDefaults] objectForKey:unlockedEventsKey];
    NSMutableArray *unlockedEvents = [NSMutableArray arrayWithCapacity:unlockedEventNames.count];
    
    for (NSString *eventName in unlockedEventNames) {
        RMEvent *event = [[RMEvent alloc] initWithName:eventName];
        [unlockedEvents addObject:event];
    }
    
    return [NSArray arrayWithArray:unlockedEvents];
}

- (int)starCountForChapter:(RMChapter)chapter
{
    int starCount = 0;
    for (int i = 1; i <= [self missionCountForChapter:chapter]; i++) {
        RMMissionStatus missionStatus = [self statusForMissionInChapter:chapter index:i];
        switch (missionStatus) {
            case RMMissionStatusThreeStar: starCount += 3; break;
            case RMMissionStatusTwoStar: starCount += 2; break;
            case RMMissionStatusOneStar: starCount += 1; break;
            default: break;
        }
    }
    return starCount;
}

- (int)percentCompleteForChapter:(RMChapter)chapter
{
    float percentComplete = 0;
    switch (chapter) {
        case RMCometChase:
            percentComplete = [RMChaseRobotController activityProgress];
            break;
        case RMCometFavoriteColor:
            percentComplete = [RMFavoriteColorRobotController activityProgress];
            break;
        case RMCometLineFollow:
            percentComplete = [RMLineFollowRobotController activityProgress];
            break;
        default:
            break;
    }
    return (int)floor(percentComplete*100);
}

- (int)successfulMissionCountForChapter:(RMChapter)chapter
{
    int missionCount = 0;
    for (int i = 1; i <= [self missionCountForChapter:chapter]; i++) {
        RMMissionStatus missionStatus = [self statusForMissionInChapter:chapter index:i];
        switch (missionStatus) {
            case RMMissionStatusThreeStar:
            case RMMissionStatusTwoStar:
            case RMMissionStatusOneStar:
                missionCount++;
            default: break;
        }
    }
    return missionCount;
}

- (BOOL)chapterHasCutscene:(RMChapter)chapter
{
    switch (chapter) {
        case RMChapterOne: return YES;
        case RMCometChase: return YES;
        case RMChapterThree: return YES;
        case RMCometLineFollow: return YES;
        case RMChapterTheEnd: return YES;
        default: return NO;
    }
}

- (BOOL)updateStoryElement:(RMStoryElement *)element
                withStatus:(RMStoryStatus)status
{
    if (element && (status == RMStoryStatusRevealed)) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:element];
        return YES;
    } else {
        return NO;
    }
}

- (RMStoryStatus)storyStatusForElement:(RMStoryElement *)element
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:element]) {
        return RMStoryStatusHidden;
    } else {
        return RMStoryStatusRevealed;
    }
}

- (NSMutableArray *)capturedPhotos
{
    if (!_capturedPhotos) {
        _capturedPhotos = [NSMutableArray arrayWithCapacity:maximumStoredPhotoCapacity];
    }
    return _capturedPhotos;
}

#pragma mark - Public Methods

- (int)missionCountForChapter:(RMChapter)chapter
{
    switch (chapter) {
        case RMChapterOne:
            return 10;
            break;
            
        case RMChapterTwo:
            return 6;
            break;
            
        case RMChapterThree:
            return 6;
            break;
            
        default:
            return 0;
            break;
    }
}

- (RMChapterStatus)statusForChapter:(RMChapter)chapter
{
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:chapterStatusKey, chapter]];
}

- (BOOL)setStatus:(RMChapterStatus)status forChapter:(RMChapter)chapter
{
    RMChapterStatus currentStatus = [self statusForChapter:chapter];
    
    BOOL validTransition = currentStatus != status;
    
    switch (currentStatus) {
        case RMChapterStatusNew:
            validTransition &= (status == RMChapterStatusSeenCutscene) || (status == RMChapterStatusSeenUnlock) || (status == RMChapterStatusComplete);
            break;
            
        case RMChapterStatusSeenCutscene:
            validTransition &= (status == RMChapterStatusSeenUnlock) || (status == RMChapterStatusComplete);
            break;
            
        case RMChapterStatusSeenUnlock:
            validTransition &= (status == RMChapterStatusComplete);
            break;
            
        case RMChapterStatusComplete:
            validTransition = NO;
            break;
            
        default: break;
    }
    
    if (validTransition) {
        [[NSUserDefaults standardUserDefaults] setInteger:status forKey:[NSString stringWithFormat:chapterStatusKey, chapter]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    return NO;
}

- (RMMissionStatus)statusForMissionInChapter:(RMChapter)chapter index:(NSInteger)index
{
    return (int )[[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:missionStatusKey, chapter, index]];
}

- (BOOL)setStatus:(RMMissionStatus)status forMissionInChapter:(RMChapter)chapter index:(NSInteger)index
{
    RMMissionStatus currentStatus = [self statusForMissionInChapter:chapter index:index];
    
    BOOL validTransition = currentStatus != status;
    
    switch (currentStatus) {
        case RMMissionStatusNew:
            validTransition &= (status == RMMissionStatusFailed) || (status == RMMissionStatusOneStar) || (status == RMMissionStatusTwoStar) || (status == RMMissionStatusThreeStar);
            break;
            
        case RMMissionStatusFailed:
            validTransition &= (status == RMMissionStatusOneStar) || (status == RMMissionStatusTwoStar) || (status == RMMissionStatusThreeStar);
            break;
            
        case RMMissionStatusOneStar:
            validTransition &= (status == RMMissionStatusTwoStar) || (status == RMMissionStatusThreeStar);
            break;
            
        case RMMissionStatusTwoStar:
            validTransition &= (status == RMMissionStatusThreeStar);
            break;
            
        case RMMissionStatusThreeStar:
            validTransition = NO;
            break;
            
        default: break;
    }
    
    if (validTransition) {
        [[NSUserDefaults standardUserDefaults] setInteger:status forKey:[NSString stringWithFormat:missionStatusKey, chapter, index]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    return NO;
}

- (BOOL)achieveUnlockable:(RMUnlockable *)unlockable
{
    BOOL newlyUnlocked = NO;
    switch (unlockable.type) {
        case RMUnlockableMission: {
            NSString *unlockedMission = unlockable.value;
            
            NSInteger splitIndex = [unlockedMission rangeOfString:@"-"].location;
            
            int unlockedChapter = [[unlockedMission substringToIndex:splitIndex] intValue];
            int unlockedIndex = [[unlockedMission substringFromIndex:splitIndex + 1] intValue];
            newlyUnlocked = [self setStatus:RMMissionStatusNew forMissionInChapter:unlockedChapter index:unlockedIndex];
            break;
        }
            
        case RMUnlockableChapter: {
            int unlockedChapter = [unlockable.value intValue];
            newlyUnlocked = [self setStatus:RMChapterStatusNew forChapter:unlockedChapter];
            
            // Force the chapters to be re-ordered
            if (newlyUnlocked) {
                self.cachedUnlockedChapters = nil;
                self.cachedOrderedChapters = nil;
            }
            break;
        }
            
        case RMUnlockableAction: {
            RMAction *action = unlockable.value;
            NSArray *unlockedActions = [[NSUserDefaults standardUserDefaults] objectForKey:unlockedActionsKey];
            newlyUnlocked = ![unlockedActions containsObject:action.title];
            
            if (newlyUnlocked) {
                NSArray *appendedUnlockedActions = nil;
                if (!unlockedActions) {
                    appendedUnlockedActions = @[ action.title ];
                } else {
                    appendedUnlockedActions = [unlockedActions arrayByAddingObject:action.title];
                }
                [[NSUserDefaults standardUserDefaults] setObject:appendedUnlockedActions forKey:unlockedActionsKey];
            }
            
            break;
        }
            
        case RMUnlockableEvent: {
            RMEvent *event = unlockable.value;
            NSString *name = [RMEvent nameForEventType:event.type];
            NSArray *unlockedEvents = [[NSUserDefaults standardUserDefaults] objectForKey:unlockedEventsKey];
            newlyUnlocked = ![unlockedEvents containsObject:name];
            
            if (newlyUnlocked && name.length) {
                NSArray *appendedUnlockedEvents = nil;
                if (!unlockedEvents) {
                    appendedUnlockedEvents = @[ name ];
                } else {
                    appendedUnlockedEvents = [unlockedEvents arrayByAddingObject:name];
                }
                [[NSUserDefaults standardUserDefaults] setObject:appendedUnlockedEvents forKey:unlockedEventsKey];
            }
            
            break;
        }
            
        case RMUnlockableExpression: {
            NSString *expressionKey = [NSString stringWithFormat:expressionStatusKey, [unlockable.value intValue]];
            newlyUnlocked = ![[NSUserDefaults standardUserDefaults] boolForKey:expressionKey];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:expressionKey];
            
            if (newlyUnlocked) {
                [self.cachedUnlockedExpressions addObject:unlockable.value];
            }
            break;
        }
            
        case RMUnlockableOther: {
            newlyUnlocked = ![[NSUserDefaults standardUserDefaults] boolForKey:unlockable.value];
            if (newlyUnlocked) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:unlockable.value];
            }
            break;
        }
            
        default:
            break;
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return newlyUnlocked;
}

- (void)incrementPlayTime:(double)playTime forMissionInChapter:(RMChapter)chapter index:(NSInteger)index
{
    NSString *key = [NSString stringWithFormat:missionPlaytimeKey, chapter, index];
    double totalPlayTimeForMission = playTime + [[NSUserDefaults standardUserDefaults] doubleForKey:key];
    [[NSUserDefaults standardUserDefaults] setDouble:totalPlayTimeForMission forKey:key];
}

#pragma mark - Private Methods

- (void)reinitializeFromVersionToCurrentVersion:(NSInteger)version
{
    // First initialization (introduced in 2.5)
    if (version < 1) {
        // Lock all Chapters & Missions, reset all playtime
        for (NSNumber *chapterValue in self.chapters) {
            RMChapter chapter = chapterValue.intValue;
            [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusLocked forKey:[NSString stringWithFormat:chapterStatusKey, chapter]];
            
            int missionCount = [self missionCountForChapter:chapter];
            for (int mission = 1; mission <= missionCount; mission++) {
                [[NSUserDefaults standardUserDefaults] setInteger:RMMissionStatusLocked forKey:[NSString stringWithFormat:missionStatusKey, chapter, mission]];
            }
            
            [[NSUserDefaults standardUserDefaults] setDouble:0 forKey:[NSString stringWithFormat:chapterPlaytimeKey, chapter]];
        }
        // Reset all story elements
        for (NSString* key in [NSUserDefaults standardUserDefaults].dictionaryRepresentation) {
            if ([key hasPrefix:characterScriptPrefix]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
            }
        }
        
        // Lock all Methods
        [[NSUserDefaults standardUserDefaults] setObject:@[] forKey:unlockedActionsKey];
        
        // Lock the rating unlockable
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:RMRomoRateAppKey];
        
        // Then unlock Chapter 1
        [self setStatus:RMChapterStatusNew forChapter:1];
    }
    
    // Migrate users to 2.6+
    if (version < 2) {
        // Update to say they've seen Chapter 1 if they are in a no-longer-valid state
        if ([[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:chapterStatusKey, RMChapterOne]] == 3) {
            [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenUnlock forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterOne]];
        }
        
        // Lock all chapters except chapter 1, since the order of chapters has changed
        for (NSNumber *chapterValue in self.chapters) {
            RMChapter chapter = chapterValue.intValue;
            if (chapter != RMChapterOne) {
                [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusLocked forKey:[NSString stringWithFormat:chapterStatusKey, chapter]];
                
                int missionCount = [self missionCountForChapter:chapter];
                for (int mission = 1; mission <= missionCount; mission++) {
                    [[NSUserDefaults standardUserDefaults] setInteger:RMMissionStatusLocked forKey:[NSString stringWithFormat:missionStatusKey, chapter, mission]];
                }
            }
        }
        
        // Romotion Tango: if the user beat the old 1-10 but not the old 1-12 (Romotion Tango), reset 1-10 to force them to create their Romotion Tango
        RMMissionStatus statusForOneTen = [self statusForMissionInChapter:RMChapterOne index:10];
        RMMissionStatus statusForOneTwelve = [self statusForMissionInChapter:RMChapterOne index:12];
        BOOL didBeatOneTen = (statusForOneTen == RMMissionStatusOneStar || statusForOneTen == RMMissionStatusTwoStar || statusForOneTen == RMMissionStatusThreeStar);
        BOOL didBeatOneTwelve = (statusForOneTwelve == RMMissionStatusOneStar || statusForOneTwelve == RMMissionStatusTwoStar || statusForOneTwelve == RMMissionStatusThreeStar);
        BOOL didUnlockOneTen = (statusForOneTen != RMMissionStatusLocked);
        if (didBeatOneTen && !didBeatOneTwelve && didUnlockOneTen) {
            // If we do reset 1-10, decide whether we should lock it or not based on the old status
            [[NSUserDefaults standardUserDefaults] setInteger:RMMissionStatusNew forKey:[NSString stringWithFormat:missionStatusKey, RMChapterOne, 10]];
        }
        
        // If they're in Chapter 1, make sure we don't reshow the unlocking of Chapter 1
        if ([self statusForChapter:RMChapterOne] == RMChapterStatusSeenCutscene) {
            [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenUnlock forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterTwo]];
        }
        
        // Lock all Emotions excepts defaults
        NSArray *initiallyUnlockedEmotions = @[
                                               @(RMCharacterEmotionCurious),
                                               @(RMCharacterEmotionExcited),
                                               @(RMCharacterEmotionHappy),
                                               @(RMCharacterEmotionSad),
                                               @(RMCharacterEmotionScared),
                                               @(RMCharacterEmotionSleepy),
                                               @(RMCharacterEmotionSleeping),
                                               ];
        
        for (RMCharacterEmotion emotion = 1; emotion <= [RMCharacter numberOfEmotions]; emotion++) {
            BOOL initiallyUnlocked = [initiallyUnlockedEmotions containsObject:@(emotion)];
            [[NSUserDefaults standardUserDefaults] setBool:initiallyUnlocked forKey:[NSString stringWithFormat:emotionStatusKey, emotion]];
        }
        
        // Lock all Expressions excepts defaults
        NSArray *initiallyUnlockedExpressions = @[
                                                  @(RMCharacterExpressionCurious),
                                                  @(RMCharacterExpressionSad),
                                                  @(RMCharacterExpressionLove),
                                                  @(RMCharacterExpressionLaugh),
                                                  @(RMCharacterExpressionExcited),
                                                  ];
        // Lock all Expressions
        for (RMCharacterExpression expression = 1; expression <= [RMCharacter numberOfExpressions]; expression++) {
            BOOL initiallyUnlocked = [initiallyUnlockedExpressions containsObject:@(expression)];
            [[NSUserDefaults standardUserDefaults] setBool:initiallyUnlocked forKey:[NSString stringWithFormat:expressionStatusKey, expression]];
        }
        
        // Initially unlock the on start event. This is the main entry point for programs.
        [[NSUserDefaults standardUserDefaults] setObject:@[[RMEvent nameForEventType:RMEventMissionStart]] forKey:unlockedEventsKey];
        
        // Initially unlock some actions that the user might not unlock if they played through Chapter 1 already
        NSMutableArray *initiallyUnlockedActions = [NSMutableArray arrayWithObjects:@"Drive backward", @"Pause", @"Tilt", nil];
        [self.unlockedActions enumerateObjectsUsingBlock:^(RMAction *action, NSUInteger idx, BOOL *stop) {
            [initiallyUnlockedActions addObject:action.title];
        }];
        [[NSUserDefaults standardUserDefaults] setObject:initiallyUnlockedActions forKey:unlockedActionsKey];
    }
    
    if (version < 3) {
        [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusLocked forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterTheEnd]];

        int chapterThreeMissionCount = [self missionCountForChapter:RMChapterThree];
        for (int mission = 2; mission <= chapterThreeMissionCount; mission++) {
            // Lock all Chapter 3 missions except 3-1
            [[NSUserDefaults standardUserDefaults] setInteger:RMMissionStatusLocked forKey:[NSString stringWithFormat:missionStatusKey, RMChapterThree, mission]];
        }
    }

    if (version < 4) {
        // Unlock Chase, Line Follow, and The Lab
        [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenCutscene forKey:[NSString stringWithFormat:chapterStatusKey, RMCometChase]];
        [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenCutscene forKey:[NSString stringWithFormat:chapterStatusKey, RMCometLineFollow]];
        [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenCutscene forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterTheLab]];
    }

    // Update the persistent version number
    [[NSUserDefaults standardUserDefaults] setInteger:currentVersion forKey:initializedVersionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 Logs total playtime for this chapter to disk,
 allows the analytics to asynchronously read that value
 */
- (void)logPlayTime:(double)playTime forChapter:(RMChapter)chapter
{
    NSString *key = [NSString stringWithFormat:chapterPlaytimeKey, chapter];
    double totalPlaytimeForChapter = playTime + [[NSUserDefaults standardUserDefaults] doubleForKey:key];
    [[NSUserDefaults standardUserDefaults] setDouble:totalPlaytimeForChapter forKey:key];
}

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    self.chapterBeforeBackground = self.currentChapter;
    self.currentChapter = noChapter;
}

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    self.currentChapter = self.chapterBeforeBackground;
    self.chapterBeforeBackground = noChapter;
}

- (void)resetProgress
{
    [self reinitializeFromVersionToCurrentVersion:0];
}

- (void)fastForwardThroughChapter:(RMChapter)chapter index:(NSInteger)index
{
    // start fresh
    [self resetProgress];
    
    if (chapter == RMChapterTheLab) {
        // For The Lab, unlock through 2-2
        chapter = RMChapterTwo;
        index = 2;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:RMChapterStatusSeenUnlock forKey:[NSString stringWithFormat:chapterStatusKey, RMChapterRomoControl]];
    
    // loop through chapters until we get to desired chapter & index
    for (NSNumber *chapterValue in self.chapters) {
        RMChapter otherChapter = chapterValue.intValue;
        
        [self setStatus:RMChapterStatusSeenUnlock forChapter:otherChapter];
        
        for (int i = 1; i <= [self missionCountForChapter:otherChapter]; i++) {
            BOOL reachedTheEnd = (chapter == otherChapter && i > index);
            if (!reachedTheEnd) {
                // unlock the mission with random star count
                RMMissionStatus status = (arc4random() % 3 == 0) ? RMMissionStatusOneStar : (arc4random() % 2 == 0) ? RMMissionStatusTwoStar : RMMissionStatusThreeStar;
                [self setStatus:status forMissionInChapter:otherChapter index:i];
                
                // unlock all items in each mission in each chapter
                RMMission *mission = [[RMMission alloc] initWithChapter:otherChapter index:i];
                for (RMUnlockable *unlockable in mission.unlockables) {
                    [self achieveUnlockable:unlockable];
                }
            } else {
                // reached the end
                return;
            }
        }
        
        // edge case hit when index is last mission in chapter
        if (chapter == otherChapter) {
            return;
        }
    }
}
- (void)unlockAllEventsandActions
{
    if (self.newestChapter != RMChapterTheEnd) {
        // The user has not made it to the end and we have to
        // manually unlock all events and actions
        // also check a user default flag so we don't have to do the
        // unlocking process everytime we open the lab
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"hasUnlockedActionsAndEvents"]) {
            for (NSNumber *chapterValue in self.chapters) {
                RMChapter currentChapter = chapterValue.intValue;
                for (int i = 1; i <= [self missionCountForChapter:currentChapter]; i++) {
                    RMMission *mission = [[RMMission alloc] initWithChapter:currentChapter index:i];
                    for (RMUnlockable *unlockable in mission.unlockables) {
                        if (unlockable.type == RMUnlockableAction || unlockable.type == RMUnlockableEvent) {
                            [self achieveUnlockable:unlockable];
                        }
                    }
                }
            }
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasUnlockedActionsAndEvents"];
        }
        
    }
}

- (void)handlePhotoModuleCapturedNewPhoto:(NSNotification *)notification
{
    UIImage *photo = notification.userInfo[@"photo"];
    if (photo) {
        while (self.capturedPhotos.count >= maximumStoredPhotoCapacity) {
            [self.capturedPhotos removeObjectAtIndex:0];
        }
        [self.capturedPhotos addObject:photo];
    }
}

- (void)handleLowMemoryWarning
{
    self.capturedPhotos = nil;
}

NSString *const characterScriptPrefix = @"Character-Script-";

@end
