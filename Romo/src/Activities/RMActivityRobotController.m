//
//  RMActivityRobotController.m
//  Romo
//

#import "RMActivityRobotController.h"
#import "RMActivityRobotControllerView.h"

/**
 The duration of time that Romo stays attentive without interaction before returning to his play
 (seconds)
 */
static const float attentionSpan = 8.0;

/** Touches that move further than this aren't considered taps */
static const CGFloat maximumDragDistance = 22.0;

@interface RMActivityRobotController ()

@property (nonatomic, strong) RMActivityRobotControllerView *view;

@property (nonatomic) CGPoint initialTouchLocation;

@property (nonatomic, strong) NSTimer *attentionSpanTimer;

@end

@implementation RMActivityRobotController

@dynamic view;

@dynamic title;

- (void)loadView
{
    self.view = [[RMActivityRobotControllerView alloc] initWithFrame:[UIScreen mainScreen].bounds];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.showsSpaceButton = self.showsSpaceButton;
    self.view.showsHelpButton = self.showsHelpButton;
}

- (void)controllerWillBecomeActive
{
    [super controllerWillBecomeActive];
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    [RMProgressManager sharedInstance].currentChapter = self.chapter;
    self.attentive = YES;
}

- (void)controllerWillResignActive
{
    [super controllerWillResignActive];
    [RMProgressManager sharedInstance].currentChapter = [RMProgressManager sharedInstance].newestChapter;
}

- (void)controllerDidResignActive
{
    [super controllerDidResignActive];
    
    self.attentive = NO;
    [self.attentionSpanTimer invalidate];
}

#pragma mark - Class Methods

+ (double)activityProgress
{
    NSAssert(NO, @"This method must be overridden");
    return NAN;
}

#pragma mark - Public Properties

- (RMChapter)chapter
{
    NSAssert(NO, @"This method must be overridden");
    return 0;
}

- (NSString *)title
{
    NSAssert(NO, @"This method must be overridden");
    return nil;
}

- (void)setAttentive:(BOOL)attentive
{
    if (attentive != _attentive) {
        _attentive = attentive;
        
        if (attentive) {
            self.view.titleLabel.text = self.title;
            [self.Romo.vitals wakeUp];
            
            self.view.showsSpaceButton = self.showsSpaceButton;
            self.view.showsHelpButton = self.showsHelpButton;
            
            [self renewAttention];
            [self.view layoutForAttentive];
        
            if (self.showsSpaceButton) {
                [self.view.spaceButton addTarget:self action:@selector(handleSpaceButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
            }
            
            if (self.showsHelpButton) {
                [self.view.helpButton addTarget:self action:@selector(handleHelpButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
            }
        } else {
            [self loseAttention];
            [self.view layoutForInattentive];
        }
    }
}

- (BOOL)showsHelpButton
{
    return YES;
}

- (BOOL)showsSpaceButton
{
    return YES;
}

#pragma mark - Public Methods

- (void)userAskedForHelp
{
    NSAssert(NO, @"This method must be overridden");
}

/**
 Resets a timer for Romo's attention span
 */
- (void)renewAttention
{
    if (self.isAttentive) {
        [self.attentionSpanTimer invalidate];
        self.attentionSpanTimer = [NSTimer scheduledTimerWithTimeInterval:attentionSpan
                                                                   target:self
                                                                 selector:@selector(loseAttention)
                                                                 userInfo:nil
                                                                  repeats:NO];
    }
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.initialTouchLocation = [[touches anyObject] locationInView:self.view];
    [self renewAttention];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    // check to see if the touch moved too far to be considered a tap
    CGPoint touchLocation = [[touches anyObject] locationInView:self.view];
    CGFloat translation = sqrtf(powf(self.initialTouchLocation.x - touchLocation.x, 2) +
                                powf(self.initialTouchLocation.y - touchLocation.y, 2));
    
    if (translation > maximumDragDistance && self.initialTouchLocation.x >= 0) {
        // if so, flag the touch as cancelled
        self.initialTouchLocation = CGPointMake(-1, -1);
    }
    
    [self renewAttention];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    // if the touch is considered a tap, toggle attentive state
    if (self.initialTouchLocation.x >= 0) {
        self.initialTouchLocation = CGPointMake(-1, -1);
        
        if (!self.view.isAnimating) {
            self.attentive = !self.isAttentive;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.initialTouchLocation = CGPointMake(-1, -1);
}

#pragma mark - Private Methods

/**
 Sets attentive to NO when called by the attention span timer
 */
- (void)loseAttention
{
    [self.attentionSpanTimer invalidate];
    self.attentionSpanTimer = nil;
    
    if (self.isAttentive) {
        self.attentive = NO;
    }
}

- (void)handleSpaceButtonTouch:(id)sender
{
    if (sender == self.view.spaceButton) {
        [self.delegate activityDidFinish:self];
    }
}

- (void)handleHelpButtonTouch:(id)sender
{
    if (sender == self.view.helpButton) {
        [self userAskedForHelp];
    }
}

@end
