//
//  RMDoodle.m
//  Romo
//

#import "RMDoodle.h"
#import <Romo/RMMath.h>

#define p(i) ([self.points[i] CGPointValue])

/**
 Converts pixels of the drawing to real-world meters
 Higher values yield smaller drive distances
 */
static const float pixelsPerMeter = 400.0;

static const int simplePathComplexityCutoff = 10; // points
static const int normalPathComplexity = 20; // points

/** Points closer than this are merged */
static const float minimumNeighborDistance = 48.0; // pixels

/** Ignore angles smaller than this */
static const float minimumAngleToTurn = 12.0; // degrees

static NSString *const pointsEncodingKey = @"points";

@interface RMDoodle ()

@property (nonatomic, strong, readwrite) NSMutableArray *points;
@property (nonatomic, strong, readwrite) NSArray *driveActions;

@end

@implementation RMDoodle

- (id)initWithSerialization:(NSString *)serialization
{
    self = [super init];
    if (self) {
        // Unpack the serialized points
        NSArray *points = [serialization componentsSeparatedByString:@";"];
        _points = [NSMutableArray arrayWithCapacity:points.count];
        [points enumerateObjectsUsingBlock:^(NSString *pointString, NSUInteger idx, BOOL *stop) {
            if (pointString.length > 1) {
                // Each point is represented as "x,y"
                NSArray *pointComponents = [pointString componentsSeparatedByString:@","];
                CGPoint point = CGPointMake([pointComponents[0] floatValue], [pointComponents[1] floatValue]);
                [self.points addObject:[NSValue valueWithCGPoint:point]];
            }
        }];
    }
    return self;
}

- (id)copy
{
    RMDoodle *copiedDoodle = [[RMDoodle alloc] init];
    copiedDoodle.points = [self.points mutableCopy];
    return copiedDoodle;
}

#pragma mark - Public Properties

- (NSMutableArray *)points
{
    if (!_points) {
        static const int estimatedCapacity = 512;
        _points = [NSMutableArray arrayWithCapacity:estimatedCapacity];
    }
    return _points;
}

- (NSString *)serialization
{
    // We estimate the serialization to be 12 characters for each (x,y) point
    NSInteger estimatedSerializationCapacity = self.points.count * 12;
    NSMutableString *serialization = [NSMutableString stringWithCapacity:estimatedSerializationCapacity];
    [self.points enumerateObjectsUsingBlock:^(NSValue *pointValue, NSUInteger idx, BOOL *stop) {
        // Convert each point to a serialized string
        CGPoint point = [pointValue CGPointValue];
        [serialization appendFormat:@"%.1f,%.1f;", point.x, point.y];
    }];
    return [serialization copy];
}

#pragma mark - Public Methods

- (void)computeDriveActions
{
    if (!self.points.count) {
        self.driveActions = nil;
        return;
    }
    
    NSMutableArray *actions = [NSMutableArray arrayWithCapacity:self.points.count];
    
    // Throw out the first point so we start at i=1
    // and we can't use the last point because we need to look 1 ahead so we go to count - 2
    for (int i = 1; i < self.points.count - 2; i++) {
        CGPoint p = p(i); // the current point
        CGPoint p1 = p(i+1); // the next point
        CGPoint p2 = p(i+2); // once we're done with this segment, pivot to face this point
        
        // Add the straight line segment
        float d = distance(p, p1) / pixelsPerMeter;
        [actions addObject:[self actionForDrivingForwardWithDistance:d]];
        
        // Use the Law of Cosines to find the angle between a & b (gamma)
        // Then we take gamma's supplementary angle to figure out
        // how far we need to pivot from along "a" to along "b"
        float a = distance(p1, p2);
        float b = distance(p, p1);
        float c = distance(p, p2);
        float gamma = RAD2DEG(acosf(((a*a) + (b*b) - (c*c)) / (2 * a * b)));
        float gammaSupplementary = 180.0 - gamma;
        
        if (ABS(gammaSupplementary) > minimumAngleToTurn) {
            // Ignoring small angles, add a pivot action in the direction of the cross product
            CGPoint v1 = CGPointMake(p1.x - p.x, p1.y - p.y);
            CGPoint v2 = CGPointMake(p2.x - p1.x, p2.y - p1.y);
            float crossProduct = v1.x * v2.y - v2.x * v1.y;
            BOOL clockwise = crossProduct < 0 ? YES : NO;
            [actions addObject:[self actionForTurningByAngle:ABS(gammaSupplementary) radius:0.0 clockwise:clockwise]];
        }
    }
    
    // Throw in the straight-away to the last point since we know we're already facing this direction
    NSInteger count = self.points.count;
    float d = distance(p(count - 2), p(count - 1)) / pixelsPerMeter;
    [actions addObject:[self actionForDrivingForwardWithDistance:d]];
    
    self.driveActions = [actions copy];
}

/** Crawls along the path and merges points that are too close */
- (void)simplify
{
    if (self.points.count) {
        NSMutableArray *simplifiedPath = [NSMutableArray arrayWithCapacity:self.points.count];
        for (int i = 0; i < self.points.count; i++) {
            CGPoint currentPoint = p(i);
            if (i == 0 || i == self.points.count - 1) {
                // Always add the first & last points on the curve
                [simplifiedPath addObject:self.points[i]];
            } else {
                CGPoint averagedPoint = currentPoint;
                for (int j = i + 1; j < self.points.count; j++) {
                    CGPoint nextPoint = p(j);
                    float distance = distance(currentPoint, nextPoint);
                    if (distance >= minimumNeighborDistance) {
                        // If this point is far enough from the next point, add it...
                        [simplifiedPath addObject:[NSValue valueWithCGPoint:averagedPoint]];
                        [simplifiedPath addObject:self.points[j]];
                        i = j;
                        break;
                    } else {
                        // ...Otherwise, average this point & the next point together
                        averagedPoint = midPoint(currentPoint, nextPoint);
                    }
                }
            }
        }
        self.points = simplifiedPath;
    }
}

- (int)complexity
{
    if (!self.points.count) {
        return 0;
    } else if (self.points.count < simplePathComplexityCutoff) {
        return 1;
    } else if (self.points.count < normalPathComplexity) {
        return 2;
    } else {
        return 3;
    }
}

#pragma mark - Private Methods

- (NSDictionary *)actionForDrivingForwardWithDistance:(float)distance
{
    return @{@"forward" : @YES, @"distance" : @(distance)};
}

- (NSDictionary *)actionForTurningByAngle:(float)angle radius:(float)radius clockwise:(BOOL)clockwise
{
    return @{@"turn" : @YES, @"angle" : @(angle), @"radius" : @(radius), @"clockwise" : @(clockwise)};
}

@end
