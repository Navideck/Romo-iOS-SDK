//
//  RMMissionProperty.m
//  Romo
//

#import "RMMissionProperty.h"
#import "RMAction.h"

@interface RMMissionProperty ()

@property (nonatomic, readwrite) NSString *actionName;
@property (nonatomic, readwrite) NSString *library;
@property (nonatomic, readwrite) BOOL count;
@property (nonatomic, readwrite) int minimumCount;
@property (nonatomic, readwrite) int maximumCount;

@end

@implementation RMMissionProperty

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        self.actionName = dictionary[@"action"];
        self.library = dictionary[@"library"];
        
        if (dictionary[@"count"]) {
            self.count = [dictionary[@"count"] boolValue];
        }
        
        if (dictionary[@"minCount"]) {
            self.minimumCount = [dictionary[@"minCount"] intValue];
        } else {
            self.minimumCount = -1;
        }
        
        if (dictionary[@"maxCount"]) {
            self.maximumCount = [dictionary[@"maxCount"] intValue];
        } else {
            self.maximumCount = -1;
        }
    }
    return self;
}

- (BOOL)matchesActions:(NSArray *)actions
{
    if (self.actionName.length) {
        int matchingCount = 0;
        for (RMAction *action in actions) {
            if ([action.fullSelector isEqualToString:self.actionName]) {
                matchingCount++;
            }
        }
        return [self matchingCountIsInRange:matchingCount];
    } else if (self.library.length) {
        int matchingCount = 0;
        for (RMAction *action in actions) {
            if ([action.library isEqualToString:self.library]) {
                matchingCount++;
            }
        }
        return [self matchingCountIsInRange:matchingCount];
    } else if (self.count) {
        return [self matchingCountIsInRange:actions.count];
    }
    
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RMMissionProperty>(Must have between [%d, %d] %@ actions)",
            self.minimumCount >= 0 ? self.minimumCount : -999,
            self.maximumCount >= 0 ? self.maximumCount : 999,
            self.actionName.length ? self.actionName : self.library];
}

#pragma mark - Private Methods

- (BOOL)matchingCountIsInRange:(NSInteger)matchingCount
{    
    BOOL matchesLowerBound = (self.minimumCount == -1) || (self.minimumCount <= matchingCount);
    BOOL matchesUpperBound = (self.maximumCount == -1) || (matchingCount <= self.maximumCount);
    return matchesLowerBound && matchesUpperBound;
}

@end
