//
//  RMDoodle.h
//  Romo
//

#import <Foundation/Foundation.h>

#define midPoint(p1,p2) (CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5))
#define distance(p1,p2) sqrt(pow(p1.x - p2.x,2) + pow(p1.y - p2.y,2))

@interface RMDoodle : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *points;

/**
 An array of Doodle Drive Action dictionaries
 each index will be either a Forward or Turn command:
 e.g. @{@"forward" : @YES, @"distance" : @2.0}, distance in meters
 e.g. @{@"turn" : @YES, @"angle" : @60.0, @"radius" : @1.5, @"clockwise" : @NO}, angle in degrees
 */
@property (nonatomic, strong, readonly) NSArray *driveActions;

/**
 The complexity of the Doodle in {0,1,2,3}
 0 is an empty path
 1 is a basic path
 2 is a normal path
 3 is a complicated path
 */
@property (nonatomic) int complexity;

- (id)initWithSerialization:(NSString *)serialization;
- (void)simplify;
- (void)computeDriveActions;

- (NSString *)serialization;

@end
