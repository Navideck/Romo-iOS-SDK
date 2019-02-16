//
//  RMExploreActionView.m
//  Romo
//

#import "RMExploreActionView.h"
#import "UIView+Additions.h"
#import <Romo/RMDispatchTimer.h>
#import <Romo/RMMath.h>

@interface RMExploreActionView ()

@property (nonatomic, strong) UIImageView *robot;
@property (nonatomic, strong) RMDispatchTimer *animationTimer;
@property (nonatomic) double previousStepTime;

@end

@implementation RMExploreActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoDriveForward1.png"]];
        self.robot.contentMode = UIViewContentModeCenter;
        self.robot.frame = CGRectMake(0, 0, 200, 200);
        self.robot.transform = CGAffineTransformMakeScale(0.45, 0.45);
        self.robot.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 5);
        [self.contentView addSubview:self.robot];
    }
    return self;
}

- (void)startAnimating
{
    [self.animationTimer startRunning];
}

- (void)stopAnimating
{
    [self.animationTimer stopRunning];
}

- (void)dealloc
{
    [self.animationTimer stopRunning];
}

#pragma mark - Animation

- (void)step
{
    // How quickly Romo turns back and forth
    static const float oscillationSpeed = 0.9;
    
    // How much Romo oscillates up and down
    static const float scurryVerticalAmount = 10.0;
    
    // How quickly Romo zips across the view
    static const float scurryHorizontalSpeed = 80.0; // pixels per second
    
    // The default image asset for driving forward
    static const int turnImageAssetBase = 24;
    // turnImageAssetBase ± turnImageAssetVary
    static const int turnImageAssetVary = 4;
    
    double time = currentTime();
    if (self.previousStepTime) {
        if (self.isStopping) {
            static const float timeWarp = 0.72;
            time = timeWarp * time;
            
            // If we're animating to show the end of exploring, only scurry halfway across the screen
            // Here, we check if we're past halfway...
            float halfwayPoint = (self.contentView.width + self.robot.width) / 2.0;

            BOOL pastHalfwayPoint = (int)(time * scurryHorizontalSpeed) % (int)(self.contentView.width + self.robot.width) > halfwayPoint;
            if (pastHalfwayPoint) {
                // ...If so, just stay at the previous position
                time = self.previousStepTime;
            }
        }
        
        // Animate Romo scurrying across the view
        float animationStep = sinf((2 * M_PI * time) * oscillationSpeed);
        float oscillationStep = -cosf((2 * M_PI * time) * oscillationSpeed);
        float horizontalPosition = (int)(time * scurryHorizontalSpeed) % (int)(self.contentView.width + self.robot.width);
        int imageNumber = turnImageAssetBase + (int)(turnImageAssetVary * animationStep);
        
        self.robot.image = [UIImage smartImageNamed:[NSString stringWithFormat:@"romoTurn%d.png",imageNumber]];
        self.robot.centerY = (self.contentView.height / 2 + 5) + oscillationStep * scurryVerticalAmount / 2.0;
        self.robot.right = horizontalPosition;
    }
    self.previousStepTime = time;
}

#pragma mark - Private Properties

- (RMDispatchTimer *)animationTimer
{
    if (!_animationTimer) {
        __weak RMExploreActionView *weakSelf = self;
        _animationTimer = [[RMDispatchTimer alloc] initWithQueue:dispatch_get_main_queue() frequency:30.0];
        _animationTimer.eventHandler = ^{
            [weakSelf step];
        };
    }
    return _animationTimer;
}

@end
