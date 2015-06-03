//
//  RMActivityBanner.m
//  Romo
//

#import "RMActivityMotivation.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMMissionToken.h"
#import "RMGradientLabel.h"
#import "RMMission.h"

static const int indexOfChapterTwoTheLabUnlocked = 3;

typedef enum {
    /** Prompts the user to play the next sequential mission */
    RMActivityMotivationNextMission,
    /** Asks to play a comet activity */
    RMActivityMotivationComet,
    /** Asks to play The Lab */
    RMActivityMotivationTheLab,
    /** Challenges to replay a mission */
    RMActivityMotivationRetryMission,
    /** Special: very first mission */
    RMActivityMotivationLearnToDrive,
} RMActivityMotivationType;

@interface RMActivityMotivation ()

@end

@implementation RMActivityMotivation

#pragma mark - Private Methods

+ (NSDictionary *)currentMotivation
{
    NSMutableDictionary *currentMotivation = [NSMutableDictionary dictionaryWithCapacity:3];

    NSDictionary *motivationTypeInfo = self.currentMotivationType;
    RMActivityMotivationType motivationType = [motivationTypeInfo[@"motivation"] intValue];
    RMChapter chapter = [motivationTypeInfo[@"chapter"] intValue];
    int index = [motivationTypeInfo[@"index"] intValue];

    switch (motivationType) {
        case RMActivityMotivationNextMission: {
            RMMission *mission = [[RMMission alloc] initWithChapter:chapter index:index];
            NSString *title = mission.title;
            NSString *question = nil;

            NSString *prompt = mission.promptToPlay;
            NSString *defaultEmptyMissionPrompt = [NSString stringWithFormat:@"Mission-%i-%i-prompt", chapter, index];

            // Choose a random question
            int seed = arc4random() % 3;
             // Add revised safe guard to missions without prompts to play
            if (![prompt isEqualToString:defaultEmptyMissionPrompt] && seed != 0) {
                // Favor mission-specifc prompts a good amount of the time
                question = prompt;
            } else {
                int seed = arc4random() % 6;
                if (seed < 1) {
                    question = [NSString stringWithFormat:NSLocalizedString(@"Mission-Motivation-Prompt-1", @"New Mission!\nLet's play \"%@\"!"),title];
                } else if (seed < 2) {
                    question = [NSString stringWithFormat:NSLocalizedString(@"Mission-Motivation-Prompt-2",@"Wanna try\n\"%@\"?"), title];
                } else if (seed < 3) {
                    question = [NSString stringWithFormat:NSLocalizedString(@"Mission-Motivation-Prompt-3",@"Next Mission:\n\"%@\""), title];
                } else if (seed < 4) {
                    question = NSLocalizedString(@"Mission-Motivation-Prompt-4", @"Let's keep\ntraining!");
                } else if (seed < 5) {
                    question = NSLocalizedString(@"Mission-Motivation-Prompt-5",@"Let's play\nanother mission!");
                } else {
                    question = NSLocalizedString(@"Mission-Motivation-Prompt-6", @"Wanna play\nthe next mission?");
                }
            }
            currentMotivation[@"question"] = question;
            currentMotivation[@"yes"] = NSLocalizedString(@"Mission-Motivation-Yes", @"Play Mission");
            currentMotivation[@"no"] = NSLocalizedString(@"Mission-Motivation-No", @"No");
            currentMotivation[@"mission"] = mission;
            break;
        }

        case RMActivityMotivationComet:
            switch (chapter) {
                case RMCometFavoriteColor:
                    currentMotivation[@"question"] = NSLocalizedString(@"FavColor-Motivation-Prompt", @"Wanna guess my\nfavorite color?");
                    currentMotivation[@"yes"] =  NSLocalizedString(@"FavColor-Motivation-Yes", @"Play Game");
                    currentMotivation[@"no"] = NSLocalizedString(@"FavColor-Motivation-No", @"Not Now");
                    currentMotivation[@"chapter"] = @(chapter);
                    break;
                    
                case RMCometChase: {
                    NSString *question = nil;
                    
                    // Randomize prompts for Chase
                    int seed = arc4random() % 5;
                    if (seed < 1) {
                        question = NSLocalizedString(@"Chase-Motivation-Prompt-1", @"Let's run around and\nchase something!");
                    } else if (seed < 2) {
                        question = NSLocalizedString(@"Chase-Motivation-Prompt-2", @"I wanna play\nCHASE!");
                    } else if (seed < 3) {
                        question = NSLocalizedString(@"Chase-Motivation-Prompt-3", @"I wanna\nCHASE something!");
                    } else if (seed < 4) {
                        question = NSLocalizedString(@"Chase-Motivation-Prompt-4", @"Can we PLEASE\nplay chase?!");
                    } else {
                        question = NSLocalizedString(@"Chase-Motivation-Prompt-5", @"It's time for\nchase!");
                    }

                    currentMotivation[@"question"] = question;
                    currentMotivation[@"yes"] = NSLocalizedString(@"Chase-Motivation-Yes", @"Play Chase");
                    currentMotivation[@"no"] = NSLocalizedString(@"Chase-Motivation-No", @"Not Now");
                    currentMotivation[@"chapter"] = @(chapter);
                    break;
                }
                    
                case RMCometLineFollow: {
                    NSString *question = nil;
                    
                    // Randomize prompts for Line Follow
                    int seed = arc4random() % 5;
                    if (seed < 1) {
                        question = NSLocalizedString(@"LineFollow-Motivation-Prompt-1", @"Let's follow\na path!");
                    } else if (seed < 2) {
                        question = NSLocalizedString(@"LineFollow-Motivation-Prompt-2", @"I wanna\nfollow a line!");
                    } else if (seed < 3) {
                        question = NSLocalizedString(@"LineFollow-Motivation-Prompt-3", @"I wanna\nrace around a track!");
                    } else if (seed < 4) {
                        question = NSLocalizedString(@"LineFollow-Motivation-Prompt-4", @"Can we\nbuild a path?!");
                    } else {
                        question = NSLocalizedString(@"LineFollow-Motivation-Prompt-5", @"Build me a path\nto follow!");
                    }
                    
                    currentMotivation[@"question"] = question;
                    currentMotivation[@"yes"] = NSLocalizedString(@"LineFollow-Motivation-Yes", @"Line Follow");
                    currentMotivation[@"no"] = NSLocalizedString(@"LineFollow-Motivation-No", @"Not Now");
                    currentMotivation[@"chapter"] = @(chapter);
                    break;
                }

                default: break;
            }
            break;

        case RMActivityMotivationTheLab: {
            NSString *question = nil;

            // Randomize prompts for The Lab
            int seed = arc4random() % 5;
            if (seed < 1) {
                question = NSLocalizedString(@"Lab-Motivation-Prompt-1", @"Let's build something\nin The Lab!");
            } else if (seed < 2) {
                question = NSLocalizedString(@"Lab-Motivation-Prompt-2", @"Let's play with\nThe Lab!");
            } else if (seed < 3) {
                question = NSLocalizedString(@"Lab-Motivation-Prompt-3", @"Let's take a break\nand play with The Lab!");
            } else if (seed < 4) {
                question = NSLocalizedString(@"Lab-Motivation-Prompt-4", @"Teach me to do something\ncool in The Lab!");
            } else {
                question = NSLocalizedString(@"Lab-Motivation-Prompt-5", @"The Lab is a\ngreat place to train!");
            }

            currentMotivation[@"question"] = question;
            currentMotivation[@"yes"] = NSLocalizedString(@"Lab-Motivation-Yes", @"Enter The Lab");
            currentMotivation[@"no"] = NSLocalizedString(@"Lab-Motivation-No", @"Not Now");
            currentMotivation[@"chapter"] = @(RMChapterTheLab);
            break;
        }

        case RMActivityMotivationRetryMission: {
            RMMission *mission = [[RMMission alloc] initWithChapter:chapter index:index];
            NSString *question = nil;

            // Randomize prompts for The Lab
            int seed = arc4random() % 4;
            if (seed < 1) {
                question = [NSString stringWithFormat:NSLocalizedString(@"RetryMission-Motivation-Prompt-1", @"Try Mission %d-%d\nfor three stars?"), chapter, index];
            } else if (seed < 2) {
                question = [NSString stringWithFormat:NSLocalizedString(@"RetryMission-Motivation-Prompt-2", @"We can do better on\nMission %d-%d!"), chapter, index];
            } else if (seed < 3) {
                question = [NSString stringWithFormat:NSLocalizedString(@"RetryMission-Motivation-Prompt-3", @"Let's play Mission %d-%d\nfor three stars!"), chapter, index];
            } else {
                question = [NSString stringWithFormat:NSLocalizedString(@"RetryMission-Motivation-Prompt-4", @"Let's earn three stars\non Mission %d-%d!"), chapter, index];
            }

            currentMotivation[@"question"] = question;
            currentMotivation[@"yes"] = NSLocalizedString(@"RetryMission-Motivation-Yes", @"Try Again");
            currentMotivation[@"no"] = NSLocalizedString(@"RetryMission-Motivation-No", @"No");
            currentMotivation[@"mission"] = mission;
            break;
        }

        case RMActivityMotivationLearnToDrive:
            currentMotivation[@"question"] = NSLocalizedString(@"LearnDrive-Motivation-Prompt-1", @"Teach me how\nto drive!");
            currentMotivation[@"yes"] = NSLocalizedString(@"LearnDrive-Motivation-Yes", @"Start Training");
            currentMotivation[@"no"] = NSLocalizedString(@"LearnDrive-Motivation-No", @"No");
            currentMotivation[@"mission"] = [[RMMission alloc] initWithChapter:chapter index:index];
            break;

        default:
            break;
    }

    return currentMotivation;
}

#pragma mark - Private Methods

+ (NSDictionary *)currentMotivationType
{
    RMChapter newestChapter = [RMProgressManager sharedInstance].newestChapter;
    int indexOfNewestMission = [RMProgressManager sharedInstance].newestMission;

    switch (newestChapter) {
        case RMChapterOne: {
            BOOL veryFirstMission = (indexOfNewestMission == 1);
            if (veryFirstMission) {
                return @{ @"motivation" : @(RMActivityMotivationLearnToDrive), @"chapter" : @(RMChapterOne), @"index" : @(1) };
            } else {
                return @{ @"motivation" : @(RMActivityMotivationNextMission), @"chapter" : @(newestChapter), @"index" : @(indexOfNewestMission) };
            }
            break;
        }

        case RMCometFavoriteColor: {
            return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometFavoriteColor) };
        }

        case RMChapterTwo: {
            RMChapterStatus theLabStatus = [[RMProgressManager sharedInstance] statusForChapter:RMChapterTheLab];
            BOOL justUnlockedTheLab = (indexOfNewestMission == indexOfChapterTwoTheLabUnlocked) && (theLabStatus == RMChapterStatusSeenCutscene || theLabStatus == RMChapterStatusNew);
            BOOL hasUnlockedTheLab = (indexOfNewestMission >= indexOfChapterTwoTheLabUnlocked);
            int seed = arc4random() % 10;
            if (justUnlockedTheLab || (hasUnlockedTheLab && seed == 0)) {
                return @{ @"motivation" : @(RMActivityMotivationTheLab) };
            } else {
                return @{ @"motivation" : @(RMActivityMotivationNextMission), @"chapter" : @(newestChapter), @"index" : @(indexOfNewestMission) };
            }
        }

        case RMCometChase: {
            return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometChase) };
        }
            
        case RMChapterThree: {
            return @{ @"motivation" : @(RMActivityMotivationNextMission), @"chapter" : @(newestChapter), @"index" : @(indexOfNewestMission) };
        }
            
        case RMCometLineFollow: {
            return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometLineFollow) };
        }
            
        case RMChapterTheEnd: {
            int seed = arc4random() % 100;
            BOOL motivateToChase = (seed < 40);
            BOOL motivateToLinefollow = (seed < 65);
            BOOL motivateToRetryMission = (seed < 80);
            BOOL motivateToPlayFavoriteColor = (seed < 82);
            
            NSDictionary *mission = self.missionWithoutThreeStars;
            if (motivateToChase) {
                // Favor playing Chase
                return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometChase) };
            } else if (motivateToLinefollow) {
                // Suggest line follow
                return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometLineFollow) };
            } else if (mission && motivateToRetryMission) {
                // Suggest a past mission to retry
                return @{ @"motivation" : @(RMActivityMotivationRetryMission), @"chapter" : mission[@"chapter"], @"index" : mission[@"index"]};
            } else if (motivateToPlayFavoriteColor) {
                // Suggest Favorite Color again
                return @{ @"motivation" : @(RMActivityMotivationComet), @"chapter" : @(RMCometFavoriteColor) };
            } else {
                // Suggest The Lab
                return @{ @"motivation" : @(RMActivityMotivationTheLab) };
            }
        }

        default: break;
    }

    return nil;
}

+ (NSDictionary *)missionWithoutThreeStars
{
    NSArray *unlockedChapters = [RMProgressManager sharedInstance].unlockedChapters;
    for (NSNumber *chapterValue in unlockedChapters) {
        RMChapter chapter = chapterValue.intValue;
        int missionCount = [[RMProgressManager sharedInstance] missionCountForChapter:chapter];
        for (int i = 1; i <= missionCount; i++) {
            RMMissionStatus missionStatus = [[RMProgressManager sharedInstance] statusForMissionInChapter:chapter index:i];
            if (missionStatus != RMMissionStatusThreeStar) {
                return @{ @"chapter" : @(chapter), @"index" : @(i) };
            }
        }
    }
    return nil;
}

@end
