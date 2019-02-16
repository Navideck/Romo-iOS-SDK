#import "RMSpaceScene.h"
#import "UIView+Additions.h"
#import "RMSpaceStar.h"
#import <Romo/RMMath.h>
#import "RMChapterPlanet.h"
#import <Romo/UIDevice+Romo.h>

static const CGFloat numberOfStarsForFastDevice = 72;
static const CGFloat numberOfStarsForSlowDevice = 0;

static const CGFloat universeScale = 3.0;

@interface RMSpaceScene ()

@property (nonatomic, readwrite, strong) NSMutableArray *mutableSpaceObjects;

@property (nonatomic, strong) RMSpaceObject *comet;
@property (nonatomic, strong) NSTimer *cometTimer;

@property (nonatomic, strong) NSArray *shootingStars;
@property (nonatomic, strong) NSTimer *shootingStarsTimer;

@property (nonatomic, strong) UIImageView *backgroundImageView;

/** Animating from initial to final camera location */
@property (nonatomic) CGFloat animationDuration;
@property (nonatomic) RMPoint3D initialCameraLocation;
@property (nonatomic) RMPoint3D finalCameraLocation;
@property (nonatomic, getter=isAnimating, readwrite) BOOL animating;
@property (nonatomic) float animationProgress;
@property (nonatomic) double lastTime;
@property (nonatomic) dispatch_source_t animationTimerSource;
@property (nonatomic, copy) void (^completion)(void);

@end

@implementation RMSpaceScene

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        self.frame = frame;
        [self addSubview:self.backgroundImageView];

        int numberOfStars = [UIDevice currentDevice].isFastDevice ? numberOfStarsForFastDevice : numberOfStarsForSlowDevice;

        self.mutableSpaceObjects = [NSMutableArray arrayWithCapacity:numberOfStars];
        NSMutableArray *stars = [NSMutableArray arrayWithCapacity:numberOfStars];
        for (int i = 0; i < numberOfStars; i++) {
            [stars addObject:[RMSpaceStar randomStar]];
        }
        [self addSpaceObjects:stars];

        self.animationTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        double timerIntervalInNanoseconds = 1.0E9/30.0;
        dispatch_source_set_timer(self.animationTimerSource, dispatch_time(DISPATCH_TIME_NOW, 0), timerIntervalInNanoseconds, (0.05 * timerIntervalInNanoseconds));
      
        __weak RMSpaceScene *weakSelf = self;
        dispatch_source_set_event_handler(self.animationTimerSource, ^{
            [weakSelf animate];
        });

        if ([UIDevice currentDevice].isFastDevice) {
            float randomInterval = ((float)(arc4random() % 3) + 4.0);
            self.cometTimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(fireComet) userInfo:nil repeats:NO];

            randomInterval = ((float)(arc4random() % 16) + 16.0);
            self.shootingStarsTimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(fireShootingStars) userInfo:nil repeats:NO];
        }
    }
    return self;
}

- (void)dealloc
{
    if (self.isAnimating) {
        dispatch_suspend(self.animationTimerSource);
    }
    dispatch_resume(self.animationTimerSource);
    dispatch_source_cancel(self.animationTimerSource);
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    if (!self.superview) {
        [self.shootingStarsTimer invalidate];
        [self.cometTimer invalidate];
        self.shootingStarsTimer = nil;
        self.cometTimer = nil;
    }
}

#pragma mark - Public Properties

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];

    self.backgroundImageView.frame = self.bounds;

    if (self.backgroundImageView.width <= 320) {
        self.backgroundImageView.contentMode = UIViewContentModeTop;
    } else {
        self.backgroundImageView.contentMode = UIViewContentModeScaleToFill;
    }
}

- (NSArray *)spaceObjects
{
    return self.mutableSpaceObjects;
}

#pragma mark - Private Properties

- (UIImageView *)backgroundImageView
{
    if (!_backgroundImageView) {
        _backgroundImageView = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"spaceBackground.png"]];
    }
    
    return _backgroundImageView;
}

#pragma mark - Public Methods

- (void)setCameraLocation:(RMPoint3D)cameraLocation
{
    if (!self.animating) {
        _cameraLocation = cameraLocation;
        [self layout];
    }
}

- (void)setCameraLocation:(RMPoint3D)cameraLocation animatedWithDuration:(float)duration completion:(void (^)(void))completion
{
    if (!self.animating) {
        if (duration > 0) {
            self.animating = YES;
            self.animationDuration = duration;
            self.completion = completion;
            
            _initialCameraLocation = _cameraLocation;
            _finalCameraLocation = cameraLocation;
            _cameraLocation = cameraLocation;
            
            self.lastTime = currentTime();
            dispatch_resume(self.animationTimerSource);
        } else {
            self.cameraLocation = cameraLocation;
        }
    }
}

- (void)animate
{
    if (self.animationProgress < 1.0) {
        CGFloat b = 0.5 - cosf(self.animationProgress * M_PI)/2;
        CGFloat a = 1.0 - b;
        CGFloat x = (a * _initialCameraLocation.x) + (b * _finalCameraLocation.x);
        CGFloat y = (a * _initialCameraLocation.y) + (b * _finalCameraLocation.y);
        CGFloat z = (a * _initialCameraLocation.z) + (b * _finalCameraLocation.z);
        
        _cameraLocation = RMPoint3DMake(x, y, z);
        [self layout];
        [self.delegate spaceScene:self didAnimateCameraLocation:_cameraLocation withRatio:b];

        double currentTime = CACurrentMediaTime();
        self.animationProgress += (currentTime - self.lastTime) / self.animationDuration;
        self.lastTime = currentTime;
    } else {
        dispatch_suspend(self.animationTimerSource);
        self.animationProgress = 0.0;
        self.initialCameraLocation = self.cameraLocation;
        self.animating = NO;
        self.cameraLocation = self.finalCameraLocation;
        [self.delegate spaceScene:self didAnimateCameraLocation:self.cameraLocation withRatio:1.0];
        
        if (self.completion) {
            self.completion();
        }
    }
}

- (void)addSpaceObject:(RMSpaceObject *)spaceObject
{
    [self.mutableSpaceObjects addObject:spaceObject];
    [self sort];
    [self layout];
}

- (void)addSpaceObjects:(NSArray *)spaceObjects
{
    [self.mutableSpaceObjects addObjectsFromArray:spaceObjects];
    [self sort];
    [self layout];
}

- (void)removeSpaceObject:(RMSpaceObject *)spaceObject
{
    [spaceObject removeFromSuperview];
    [self.mutableSpaceObjects removeObject:spaceObject];
}

- (void)removeSpaceObjects:(NSArray *)spaceObjects
{
    for (RMSpaceObject *spaceObject in spaceObjects) {
        [spaceObject removeFromSuperview];
    }
    [self.mutableSpaceObjects removeObjectsInArray:spaceObjects];
}

#pragma mark - Private Methods

/** Correctly stacks the z-indeces of all subviews so further objects are occluded by closer ones */
- (void)sort
{
    NSArray *sorted = [self.mutableSpaceObjects sortedArrayWithOptions:0
                                                       usingComparator:^NSComparisonResult(RMSpaceObject *obj1, RMSpaceObject *obj2) {
                                                           return obj1.location.z > obj2.location.z ? NSOrderedAscending : NSOrderedDescending;
                                                       }];
    self.mutableSpaceObjects = [NSMutableArray arrayWithArray:sorted];
    for (RMSpaceObject *spaceObject in self.mutableSpaceObjects) {
        [self addSubview:spaceObject];
    }
}

/** Lays out all subviews to follow the 3D Euclidean geometries of the scene */
- (void)layout
{
    CGFloat w = self.width / 2;
    CGFloat h = self.height / 2;
    
    for (RMSpaceObject *spaceObject in self.mutableSpaceObjects) {
        RMPoint3D relative = RMPoint3DMake(universeScale * (spaceObject.location.x - self.cameraLocation.x),
                                           universeScale * (spaceObject.location.y - self.cameraLocation.y),
                                           universeScale * (spaceObject.location.z - self.cameraLocation.z));
        
        CGFloat x = w + (w * relative.x) / relative.z;
        CGFloat y = h + (h * relative.y) / relative.z;
        spaceObject.center = CGPointMake(x, y);
        
        CGFloat spanRadius = 5.0 * MAX(w + spaceObject.width, h + spaceObject.height);
        CGFloat centerToCenterDistance = sqrtf(powf(x - w, 2) + powf(y - h, 2));
        
        // if it's within the span radius, it's at zero distance
        centerToCenterDistance = MAX(0.0, centerToCenterDistance - spanRadius);
        CGFloat distance = sqrtf(powf(centerToCenterDistance, 2) + powf(relative.z, 2));
        CGFloat size = 1.0 / distance;
        
        spaceObject.transform = CGAffineTransformMakeScale(size, size);
        spaceObject.alpha = CLAMP(0.15, (1.0 + sqrtf(1.2 * size)) / 2, 1.0);
        spaceObject.hidden = relative.z <= 0;
    }
}

#pragma mark - Comet

- (void)fireComet
{
    CGFloat randomZ = (float)(arc4random() % 60)/100.0 + 0.4;
    self.comet.alpha = (1.0 + sqrtf(randomZ))/2.0;

    BOOL fromLeft = arc4random() % 2;
    if (fromLeft) {
        self.comet.transform = CGAffineTransformMakeScale(-randomZ, randomZ);
        self.comet.right = 0;
    } else {
        self.comet.transform = CGAffineTransformMakeScale(randomZ, randomZ);
        self.comet.left = self.width;
    }
    CGFloat randomY = 80 + (arc4random() % (int)(self.height - 200));
    self.comet.top = randomY;

    [self insertSubview:self.comet atIndex:1];
    [self.comet startAnimating];

    CGFloat randomDuration = 8.0 + (arc4random() % 8);
    [UIView animateWithDuration:randomDuration delay:0.0 options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         if (fromLeft) {
                             self.comet.origin = CGPointMake(self.width, self.comet.top + 100 * randomZ);
                         } else {
                             self.comet.origin = CGPointMake(-self.comet.width, self.comet.top + 100 * randomZ);
                         }
                     } completion:^(BOOL finished) {
                         [self.comet removeFromSuperview];
                         [self.comet stopAnimating];

                         if (finished && self.superview) {
                             float randomInterval = ((float)(arc4random() % 8) + 12.0);
                             self.cometTimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(fireComet) userInfo:nil repeats:NO];
                         } else {
                             self.cometTimer = nil;
                         }
                     }];
}

- (void)fireShootingStars
{
    __block CGFloat angle = ((float)(arc4random() % 700) / 10.0) - 35.0;
    BOOL fromLeft = arc4random() % 2;
    CGFloat randomY = 80 + (arc4random() % (int)(self.height - 200));
    for (RMSpaceObject *star in self.shootingStars) {
        CGFloat offsetAngle = 0;
        if (fromLeft) {
            star.right = - (float)(arc4random() % 32);
            offsetAngle = DEG2RAD(180.0);
        } else {
            star.left = self.width + (arc4random() % 32);
        }
        star.top = randomY - 16.0 + (arc4random() % 32);
        star.transform = CGAffineTransformMakeRotation(DEG2RAD(-angle) + offsetAngle);
        [self insertSubview:star atIndex:1];
    }

    CGFloat randomDuration = 2.5 + (arc4random() % 1);
    [UIView animateWithDuration:randomDuration delay:0.0 options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         angle = fromLeft ? angle : -angle;
                         for (RMSpaceObject *star in self.shootingStars) {
                             CGPoint endPoint;
                             if (fromLeft) {
                                 endPoint.x = self.width + 20.0 + (arc4random() % 16);
                             } else {
                                 endPoint.x = -20.0 - (float)(arc4random() % 16);
                             }
                             endPoint.y = star.top + self.width * sinf(DEG2RAD(-angle)) - 8.0 + (arc4random() % 16);
                             star.center = endPoint;
                         }
                     } completion:^(BOOL finished) {
                         for (RMSpaceObject *star in self.shootingStars) {
                             [star removeFromSuperview];
                         }
                         self.shootingStars = nil;

                         if (finished && self.superview) {
                             float randomInterval = ((float)(arc4random() % 16) + 16.0);
                             self.shootingStarsTimer = [NSTimer scheduledTimerWithTimeInterval:randomInterval target:self selector:@selector(fireShootingStars) userInfo:nil repeats:NO];
                         } else {
                             self.shootingStarsTimer = nil;
                         }
                     }];
}

- (RMSpaceObject *)comet
{
    if (!_comet) {
        _comet = [[RMSpaceObject alloc] initWithFrame:CGRectMake(0, 0, 265, 88)];
        _comet.animationImages = @[[UIImage imageNamed:@"spaceComet1.png"],
                                   [UIImage imageNamed:@"spaceComet2.png"],
                                   [UIImage imageNamed:@"spaceComet3.png"],
                                   [UIImage imageNamed:@"spaceComet2.png"],
                                   ];
        _comet.animationDuration = 0.25;
    }
    return _comet;
}

- (NSArray *)shootingStars
{
    if (!_shootingStars) {
        int count = 1 + arc4random() % 3;
        NSMutableArray *shootingStars = [NSMutableArray arrayWithCapacity:count];

        for (int i = 0; i < count; i++) {
            CGFloat randomSize = 8 + (arc4random() % 14);
            RMSpaceObject *star = [[RMSpaceObject alloc] initWithFrame:CGRectMake(0, 0, randomSize, randomSize)];
            star.image = [UIImage imageNamed:@"shootingStar.png"];
            star.contentMode = UIViewContentModeScaleAspectFit;

            CGFloat alpha = 0.45 + (float)(arc4random() % 650) / 1000.0;
            CABasicAnimation *twinkleAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            twinkleAnimation.duration = 0.06 + (float)(arc4random() % 6) / 100;
            twinkleAnimation.repeatCount = HUGE_VALF;
            twinkleAnimation.fromValue = @(alpha);
            twinkleAnimation.toValue = @(0.75 * alpha);
            twinkleAnimation.autoreverses = YES;
            [star.layer addAnimation:twinkleAnimation forKey:nil];

            [shootingStars addObject:star];
        }

        _shootingStars = [NSArray arrayWithArray:shootingStars];
    }
    return _shootingStars;
}

@end
