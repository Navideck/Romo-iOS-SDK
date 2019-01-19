//
//  RMDoodleView.m
//  Romo
//

#import "RMDoodleView.h"
#import "RMDoodle.h"
#import "UIView+Additions.h"

static const int maximumPathLength = 4096;
static const int minimumPathLength = 128;

@interface RMDoodleView ()

/** Model */
@property (nonatomic) CGPoint previousPreviousPoint;
@property (nonatomic) CGPoint previousPoint;
@property (nonatomic) CGPoint currentPoint;
@property (nonatomic) float pathLength;

@property (nonatomic, strong) CAShapeLayer *doodleLayer;
@property (nonatomic) CGMutablePathRef doodlePath;

@end

@implementation RMDoodleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = NO;
        self.contentMode = UIViewContentModeScaleAspectFit;
        self.userInteractionEnabled = YES;
        
        [self.layer addSublayer:self.doodleLayer];
    }
    return self;
}

- (void)layoutSubviews
{
    // Transform the doodle layer so it fits nicely & proportionally in our view
    // e.g. make it shorter as our view shrinks vertically
    // Then make sure it is centered
    CGSize s = [UIScreen mainScreen].bounds.size;
    float horizontalScale = self.width / s.width;
    float verticalScale = self.height / s.height;
    float smallerScale = MIN(horizontalScale, verticalScale);
    self.doodleLayer.transform = CATransform3DMakeScale(smallerScale, smallerScale, 1.0);
    self.doodleLayer.frame = CGRectMake((self.width - s.width * smallerScale) / 2.0, (self.height - s.height * smallerScale) / 2.0, s.width * smallerScale, s.height * smallerScale);
}

#pragma mark - Public Properties

- (void)setDoodle:(RMDoodle *)doodle
{
    _doodle = nil;
    [self clearCanvas];
    
    _doodle = doodle;
    [self redrawCanvas];
}

#pragma mark - Drawing

- (void)clearCanvas
{
    [self.doodle.points removeAllObjects];
    self.pathLength = 0.0;
    self.doodlePath = nil;
    self.doodleLayer.path = nil;
}

- (void)updateCanvas
{
    self.pathLength += distance(self.currentPoint, self.previousPoint);
    
    CGPoint mid1 = midPoint(self.previousPoint, self.previousPreviousPoint);
    CGPoint mid2 = midPoint(self.currentPoint, self.previousPoint);
    
    CGPathMoveToPoint(self.doodlePath, NULL, mid1.x, mid1.y);
    CGPathAddQuadCurveToPoint(self.doodlePath, NULL, self.previousPoint.x, self.previousPoint.y, mid2.x, mid2.y);
    CGPathRef path = CGPathCreateCopy(self.doodlePath);
    self.doodleLayer.path = path;
    CGPathRelease(path);
}

- (void)redrawCanvas
{
    if (self.doodle.points.count) {
        CGPoint point = [self.doodle.points[0] CGPointValue];
        self.previousPreviousPoint = point;
        self.previousPoint = point;
        self.currentPoint = point;
        
        [self.doodle.points enumerateObjectsUsingBlock:^(NSValue *pointValue, NSUInteger idx, BOOL *stop) {
            CGPoint point = pointValue.CGPointValue;
            self.previousPreviousPoint = self.previousPoint;
            self.previousPoint = self.currentPoint;
            self.currentPoint = point;
            [self updateCanvas];
        }];
    }
}

#pragma mark - Touches

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    return point.y > 80 && [super pointInside:point withEvent:event];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint point = [[touches anyObject] locationInView:self];
    self.previousPreviousPoint = point;
    self.previousPoint = point;
    self.currentPoint = point;
    
    [self clearCanvas];
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.pathLength < maximumPathLength) {
        self.previousPreviousPoint = self.previousPoint;
        self.previousPoint = self.currentPoint;
        self.currentPoint = [[touches anyObject] locationInView:self];
        [self.doodle.points addObject:[NSValue valueWithCGPoint:self.currentPoint]];
        
        [self updateCanvas];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.pathLength < minimumPathLength) {
        [self clearCanvas];
    } else {
        [self.doodle simplify];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

#pragma mark - Private Properties

- (CAShapeLayer *)doodleLayer
{
    if (!_doodleLayer) {
        _doodleLayer = [CAShapeLayer layer];
        _doodleLayer.frame = [UIScreen mainScreen].bounds;
        _doodleLayer.strokeColor = [UIColor whiteColor].CGColor;
        _doodleLayer.fillColor = [UIColor clearColor].CGColor;
        _doodleLayer.lineWidth = 8.0;
        _doodleLayer.lineCap = kCALineCapRound;
    }
    return _doodleLayer;
}

- (CGMutablePathRef)doodlePath
{
    if (!_doodlePath) {
        _doodlePath = CGPathCreateMutable();
    }
    return _doodlePath;
}

@end
