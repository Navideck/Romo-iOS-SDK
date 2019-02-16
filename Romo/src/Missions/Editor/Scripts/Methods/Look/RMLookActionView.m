//
//  RMLookActionView.m
//  Romo
//

#import "RMLookActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import <Romo/RMMath.h>

@interface RMLookActionView ()
@property (nonatomic, strong) UIView *eyesView;

@property (nonatomic, strong) UIView *leftPupil;
@property (nonatomic, strong) UIView *rightPupil;

@property (nonatomic) CGPoint lookAtPoint;

@end

@implementation RMLookActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _eyesView = [[UIView alloc] initWithFrame:self.contentView.bounds];
        [self.contentView addSubview:self.eyesView];
        
        UIImageView *eyes = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"lookEyes.png"]];
        eyes.frame = self.eyesView.bounds;
        eyes.top = 14;
        eyes.contentMode = UIViewContentModeCenter;
        [self.eyesView addSubview:eyes];

        _leftPupil = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 23, 23)];
        self.leftPupil.layer.cornerRadius = self.leftPupil.width / 2;
        self.leftPupil.backgroundColor = [UIColor blackColor];
        [self.eyesView addSubview:self.leftPupil];

        _rightPupil = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 23, 23)];
        self.rightPupil.layer.cornerRadius = self.rightPupil.width / 2;
        self.rightPupil.backgroundColor = [UIColor blackColor];
        [self.eyesView addSubview:self.rightPupil];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterLookPoint) {
            NSString *value = parameter.value;
            NSRange comma = [value rangeOfString:@", "];
            CGFloat x = [[value substringToIndex:comma.location] floatValue];
            CGFloat y = [[value substringFromIndex:comma.location + comma.length] floatValue];
            self.lookAtPoint = CGPointMake(x, y);
        }
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;

    if (editing) {
        [self.contentView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        self.eyesView.transform = CGAffineTransformMakeScale(1.3, 1.3);
        self.eyesView.center = CGPointMake(self.contentView.width / 2, 3.0 * self.contentView.height / 7.0);
    } else {
        for (UIGestureRecognizer *gesture in self.contentView.gestureRecognizers) {
            if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
                [self.contentView removeGestureRecognizer:gesture];
            }
        }
        self.eyesView.transform = CGAffineTransformIdentity;
        self.eyesView.origin = CGPointZero;
    }
}

#pragma mark - Private Methods

- (void)setLookAtPoint:(CGPoint)lookAtPoint
{
    CGFloat distance = sqrtf(powf(lookAtPoint.x - _lookAtPoint.x, 2) + powf(lookAtPoint.y - _lookAtPoint.y, 2));
    
    _lookAtPoint = lookAtPoint;

    CGPoint leftCenter = [self locationForPupilWithCenter:lookAtPoint left:YES scale:0.8];
    CGPoint rightCenter = [self locationForPupilWithCenter:lookAtPoint left:NO scale:0.8];

    if (distance > 0.4) {
        [UIView animateWithDuration:0.1
                         animations:^{
                             self.leftPupil.center = leftCenter;
                             self.rightPupil.center = rightCenter;
                         }];
    } else {
        self.leftPupil.center = leftCenter;
        self.rightPupil.center = rightCenter;
    }
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterLookPoint) {
            parameter.value = [NSString stringWithFormat:@"%f, %f", lookAtPoint.x, lookAtPoint.y];
        }
    }
    
    BOOL isUpOrDown = ABS(lookAtPoint.y) > 0.13;
    BOOL isLeftOrRight = ABS(lookAtPoint.x) > 0.13;
    NSString *verticalWord = lookAtPoint.y < 0 ? NSLocalizedString(@"Action-Look-Direction-up", @"up") : NSLocalizedString(@"Action-Look-Direction-down", @"down");;
    NSString *horizontalWord = lookAtPoint.x < 0 ? NSLocalizedString(@"Action-Look-Direction-left", @"left") : NSLocalizedString(@"Action-Look-Direction-right", @"right");
    if (isUpOrDown || isLeftOrRight) {
        self.subtitle = [NSString stringWithFormat:@"%@%@%@",
                         isUpOrDown ? [verticalWord capitalizedString] : @"",
                         isUpOrDown && isLeftOrRight ? @" & " : @"",
                         isLeftOrRight ? (isUpOrDown ? horizontalWord : [horizontalWord capitalizedString]) : @""];
    } else {
        self.subtitle = NSLocalizedString(@"Action-Look-Direction-Ahead", @"Ahead");
    }
}

- (CGPoint)locationForPupilWithCenter:(CGPoint)center left:(BOOL)left scale:(CGFloat)scale
{
    CGPoint defaultCenter = CGPointMake(left ? 102 : 183, 80);

    CGFloat r = 20 * scale;
    CGFloat z = 0.6;
    CGFloat x = (center.x * 64 * scale) + (scale * 12.0 * (0.9 - z) * (left ? 1.0 : -1.0));
    CGFloat y = (center.y * 44 * scale);

    CGFloat dist = sqrtf(x*x + y*y);
    if (dist > r) {
        CGFloat theta = -atan2f(y, x);
        x = cosf(theta) * r;
        y = - sinf(theta) * r;
    }
    x += defaultCenter.x;
    y += defaultCenter.y;
    return CGPointMake(x,y);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.isEditing) {
        CGPoint panLocation = [[touches anyObject] locationInView:self.contentView];
        
        CGFloat x = (panLocation.x - (self.contentView.width / 2)) / (0.75 * self.contentView.width / 2);
        CGFloat y = (panLocation.y - (self.contentView.height / 2)) / (0.65 * self.contentView.height / 2);
        
        self.lookAtPoint = CGPointMake(CLAMP(-1.0, x, 1.0), CLAMP(-1.0, y, 1.0));
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    CGPoint panLocation = [pan locationInView:pan.view];
    
    CGFloat x = (panLocation.x - (pan.view.width / 2)) / (0.75 * pan.view.width / 2);
    CGFloat y = (panLocation.y - (pan.view.height / 2)) / (0.65 * pan.view.height / 2);
    
    self.lookAtPoint = CGPointMake(CLAMP(-1.0, x, 1.0), CLAMP(-1.0, y, 1.0));
}

@end
