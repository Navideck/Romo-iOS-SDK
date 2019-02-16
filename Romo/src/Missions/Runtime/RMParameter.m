//
//  RMParameter.m
//  Romo
//

#import "RMParameter.h"
#import <Romo/RMCharacter.h>
#import "RMProgressManager.h"
#import "RMFaceActionView.h"
#import "RMDoodle.h"

@implementation RMParameter

- (RMParameter *)initWithType:(RMParameterType)type
{
    self = [super init];
    if (self) {
        _type = type;
        _value = [self defaultValueForType:type];
    }
    return self;
}

- (RMParameter *)initFromString:(NSString *)string
{
    RMParameter *parameter = [self initWithType:[self typeFromString:string]];
    parameter->_name = [self nameFromString:string];
    return parameter;
}

#pragma mark - Public Properties

- (NSString *)units
{
    switch (self.type) {
        case RMParameterDuration:
            return NSLocalizedString(@"Action-Parameter-Time-Unit", @" sec");
            
        case RMParameterSpeed:
        case RMParameterLightBrightness:
            return NSLocalizedString(@"Action-Parameter-Percent-Unit", @"%");

        case RMParameterDistance:
            return NSLocalizedString(@"Action-Parameter-Distance-Unit", @" cm");

        default:
            return nil;
    }
}

- (NSArray *)valueOptions
{
    switch (self.type) {
        case RMParameterRomoPoke:
            return @[ @"forehead", @"eye", @"nose", @"chin" ];
            break;
            
        case RMParameterRomoTickle:
            return @[ @"forehead", @"nose", @"chin" ];
            break;
            
        default:
            return nil;
            break;
    }
}

- (id)appropriateValueExcludingValues:(NSArray *)values
{
    NSMutableSet *remainingValueOptions = [NSMutableSet setWithArray:self.valueOptions];
    [remainingValueOptions minusSet:[NSSet setWithArray:values]];
    return [remainingValueOptions anyObject];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@",self.value ? self.value : @"--"];
}

#pragma mark - Private Methods

- (RMParameterType)typeFromString:(NSString *)string
{
    if ([string hasPrefix:@"(duration)"]) {
        return RMParameterDuration;
    } else if ([string hasPrefix:@"(speed)"]) {
        return RMParameterSpeed;
    } else if ([string hasPrefix:@"(expression)"]) {
        return RMParameterExpression;
    } else if ([string hasPrefix:@"(emotion)"]) {
        return RMParameterEmotion;
    } else if ([string hasPrefix:@"(romoPoke)"]) {
        return RMParameterRomoPoke;
    } else if ([string hasPrefix:@"(romoTickle)"]) {
        return RMParameterRomoTickle;
    } else if ([string hasPrefix:@"(time)"]) {
        return RMParameterTime;
    } else if ([string hasPrefix:@"(text)"]) {
        return RMParameterText;
    } else if ([string hasPrefix:@"(distance)"]) {
        return RMParameterDistance;
    } else if ([string hasPrefix:@"(lightBrightness)"]) {
        return RMParameterLightBrightness;
    } else if ([string hasPrefix:@"(song)"]) {
        return RMParameterSong;
    } else if ([string hasPrefix:@"(direction)"]) {
        return RMParameterTurnDirection;
    } else if ([string hasPrefix:@"(angle)"]) {
        return RMParameterAngle;
    } else if ([string hasPrefix:@"(pointValue)"]) {
        return RMParameterLookPoint;
    } else if ([string hasPrefix:@"(radius)"]) {
        return RMParameterRadius;
    } else if ([string hasPrefix:@"(doodle)"]) {
        return RMParameterDoodle;
    } else if ([string hasPrefix:@"(color)"]) {
        return RMParameterColor;
    } else {
        return -1;
    }
}

- (NSString *)nameFromString:(NSString *)string
{
    return [string substringFromIndex:[string rangeOfString:@")"].location + 1];
}

- (id)defaultValueForType:(RMParameterType)type
{
    switch (type) {
        case RMParameterDuration: return @(4.0); break;
        case RMParameterSpeed: return @(50.0); break;
        case RMParameterText: return NSLocalizedString(@"Paramter-Say-Default-Value", @"Hello, Earth"); break;
        case RMParameterExpression: return [self randomExpression]; break;
        case RMParameterEmotion: return [self randomEmotion]; break;
        case RMParameterSong: return nil; break;
        case RMParameterDistance: return @(25); break;
        case RMParameterLightBrightness: return @(100.0); break;
        case RMParameterTurnDirection: return @(YES); break;
        case RMParameterLookPoint: return @"-1, 0"; break;
        case RMParameterAngle: return @(60); break;
        case RMParameterTime: {
            NSDateFormatter *currentTime = [[NSDateFormatter alloc] init];
            currentTime.dateFormat = @"hh:mm a";
             NSString *currentTimeString = [currentTime stringFromDate:[NSDate date]];
            if ([currentTimeString characterAtIndex:0] == '0') {
                currentTimeString = [currentTimeString substringFromIndex:1];
            }
            return currentTimeString;
            break;
        }
        case RMParameterRadius: return @(10); break;
        case RMParameterRomoPoke: return @"eye";
        case RMParameterRomoTickle: return @"chin";
        case RMParameterDoodle: return [[RMDoodle alloc] init];
        case RMParameterColor: return [UIColor colorWithHue:0.233 saturation:1.0 brightness:1.0 alpha:1.0];
        default: return nil; break;
    }
}

#pragma mark - Private Methods

- (NSNumber *)randomEmotion
{
    NSSet *randomEmotions = [RMFaceActionView allowedEmotions];
    return randomEmotions.allObjects[arc4random() % randomEmotions.count];
}

- (NSNumber *)randomExpression
{
    // Grab the allowed emotion options in Missions
    NSSet *randomExpression = [NSSet setWithArray:@[
                                                    @(RMCharacterExpressionCurious),
                                                    @(RMCharacterExpressionSad),
                                                    @(RMCharacterExpressionLove),
                                                    @(RMCharacterExpressionLaugh),
                                                    @(RMCharacterExpressionExcited),
                                                    ]];
    
    return [self randomObjectFromSet:randomExpression];
}

/** Pulls a random object from the provided set */
- (id)randomObjectFromSet:(NSSet *)set
{
    int randomIndex = arc4random() % set.count;
    __block int currentIndex = 0;
    __block id selectedObject = nil;
    [set enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        if (randomIndex == currentIndex) {
            selectedObject = obj; *stop = YES;
        } else {
            currentIndex++;
        }
    }];
    
    return selectedObject;
}

@end
