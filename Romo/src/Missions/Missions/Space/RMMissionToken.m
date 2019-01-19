//
//  RMMissionToken.m
//  Romo
//

#import "RMMissionToken.h"
#import "UIView+Additions.h"
#import "UIImage+Tint.h"
#import "UIFont+RMFont.h"

@interface RMMissionToken ()

@property (nonatomic, readwrite) NSInteger index;
@property (nonatomic, readwrite) RMMissionStatus status;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIImageView *pulse;
@property (nonatomic, strong) UILabel *indexLabel;

@property (nonatomic) RMChapter chapter;

@property (nonatomic) BOOL wasAnimatingBeforeBackgrounding;

@end

@implementation RMMissionToken

- (id)initWithChapter:(RMChapter)chapter index:(NSInteger)index status:(RMMissionStatus)status
{
    self = [super initWithFrame:CGRectMake(0, 0, 77, 77)];
    if (self) {
        _chapter = chapter;
        _index = index;
        _status = status;
        
        self.clipsToBounds = NO;
        
        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.contentView];
        
        UIImageView *glow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenGlow.png"]];
        glow.frame = self.bounds;
        [self.contentView addSubview:glow];
        
        UIImageView *token = [[UIImageView alloc] initWithFrame:CGRectMake(12.5, 12.5, 52, 52)];
        token.image = [UIImage imageNamed:[NSString stringWithFormat:@"missionTokenUnlocked%d.png", chapter]];
        [self.contentView addSubview:token];

        self.indexLabel.center = token.center;
        [self.contentView addSubview:self.indexLabel];

        int numberOfStars = 0;

        switch (status) {
            case RMMissionStatusLocked: {
                glow.alpha = 0.65;
                token.image = [UIImage imageNamed:@"missionTokenLocked.png"];
                [self.indexLabel removeFromSuperview];
                
#ifdef DEBUG
                UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOrbDoubleTap:)];
                doubleTap.numberOfTapsRequired = 2;
                [self addGestureRecognizer:doubleTap];
#endif
                break;
            }
                
            case RMMissionStatusNew:
            case RMMissionStatusFailed: {
                UIImageView *newBorder = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenNew.png"]];
                newBorder.frame = self.bounds;
                [self.contentView addSubview:newBorder];
                break;
            }

            case RMMissionStatusThreeStar: numberOfStars++;
            case RMMissionStatusTwoStar: numberOfStars++;
            case RMMissionStatusOneStar: numberOfStars++;
            {
                for (int i = 1; i <= 3; i++) {
                    UIImageView *star = nil;
                    if (i <= numberOfStars) {
                        star = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenStar.png"]];
                    } else {
                        star = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenNoStar.png"]];
                    }
                    CGFloat y = token.bottom + 2 - (i % 2) * 4.5;
                    star.center = CGPointMake(self.contentView.width / 2 - 17.5 + 17.5*(i-1), y);
                    [self.contentView addSubview:star];
                }
            }
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillEnterForegroundNotification:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    if (!self.superview) {
        [self stopAnimating];
    }
}

- (void)startAnimating
{
    // Float in space
    float sign = self.index % 2 ? 1 : -1;
    CAKeyframeAnimation *circlePathAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    circlePathAnimation.calculationMode = kCAAnimationPaced;
    circlePathAnimation.duration = 2.0 + (sign * (float)(arc4random() % 50)/100.0);
    circlePathAnimation.repeatCount = HUGE_VALF;

    CGFloat c = self.width / 2.0;
    CGFloat r = 3.5 + (sign / 2.0);
    CGPathRef circularPath = CGPathCreateWithEllipseInRect(CGRectMake(c - r, c - r, 2*r, 2*r), NULL);
    circlePathAnimation.path = circularPath;
    CGPathRelease(circularPath);

    [self.contentView.layer addAnimation:circlePathAnimation forKey:nil];

    // If we're not accomplished, send a pulse every so often
    if (self.status == RMMissionStatusNew || self.status == RMMissionStatusFailed) {
        [self sendPulse];
    }
    
    self.wasAnimatingBeforeBackgrounding = YES;
}

- (void)stopAnimating
{
    [self.contentView.layer removeAllAnimations];
    self.wasAnimatingBeforeBackgrounding = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint location = [[touches anyObject] locationInView:self];
    if (CGRectContainsPoint(self.bounds, location)) {
        [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.contentView.transform = CGAffineTransformMakeScale(1.3, 1.3);
                         } completion:nil];
    } else {
        [self touchesEnded:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.contentView.transform = CGAffineTransformIdentity;
                     } completion:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private Methods

- (UILabel *)indexLabel
{
    if (!_indexLabel) {
        _indexLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _indexLabel.backgroundColor = [UIColor clearColor];
        _indexLabel.textColor = [UIColor whiteColor];
        _indexLabel.text = [NSString stringWithFormat:@"%ld",(long)self.index];
        _indexLabel.font = [UIFont fontWithSize:36];
        _indexLabel.size = [_indexLabel.text sizeWithFont:_indexLabel.font];
        _indexLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        _indexLabel.layer.shadowOffset = CGSizeMake(0.5, 1.5);
        _indexLabel.layer.shadowOpacity = 1.0;
        _indexLabel.layer.shadowRadius = 2.0;
        _indexLabel.layer.rasterizationScale = 2.0;
        _indexLabel.layer.shouldRasterize = YES;
        _indexLabel.clipsToBounds = NO;
    }
    return _indexLabel;
}

- (void)sendPulse
{
    self.pulse.alpha = 1.0;
    self.pulse.frame = CGRectMake(self.contentView.centerX - 20, self.contentView.centerY - 20, 40, 40);
    [UIView animateWithDuration:3.0 delay:0.5 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.pulse.frame = CGRectMake(self.contentView.centerX - 64, self.contentView.centerY - 64, 128, 128);
                         self.pulse.alpha = 0.0;
                     } completion:^(BOOL finished) {
                         if (finished && self.superview) {
                             [self sendPulse];
                         }
                     }];
}

- (UIImageView *)pulse
{
    if (!_pulse) {
        _pulse = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"missionTokenNewPulse.png"]];
        _pulse.contentMode = UIViewContentModeScaleToFill;
        [self.contentView insertSubview:_pulse atIndex:0];
    }
    return _pulse;
}

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    if (self.wasAnimatingBeforeBackgrounding) {
        [self startAnimating];
    }
}

#ifdef DEBUG
- (void)handleOrbDoubleTap:(UITapGestureRecognizer *)doubleTap
{
    [[RMProgressManager sharedInstance] fastForwardThroughChapter:self.chapter index:self.index];
}
#endif

@end
