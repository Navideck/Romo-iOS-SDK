//
//  RMDpad.m
//  RMRomoteDriveVC
//

#import "RMDpad.h"
#import "UIView+Additions.h"

@interface RMDpad() {
    CGSize _centerSize;
    RMDpadSector _currentSector;
}

@property (nonatomic, strong) UIImageView *dpadImageView;
@property (nonatomic, strong) NSString *imageName;

- (CGPoint)processTouchAtPoint:(CGPoint)touchPoint;
- (void)adjustBackgroundPositionWithSector:(RMDpadSector)sector;
- (RMDpadSector)sectorAtTouchPoint:(CGPoint)touchPoint;

@end

@implementation RMDpad

- (id)initWithFrame:(CGRect)frame imageName:(NSString*)imageName centerSize:(CGSize)centerSize
{
    self = [super initWithFrame:frame];
    if (self) {
        _centerSize = centerSize;
        _imageName = imageName;

        _dpadImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.dpadImageView.image = [UIImage imageNamed:imageName];
        self.dpadImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.dpadImageView.alpha = 0.45;
        [self addSubview:self.dpadImageView];
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint currentTouchPoint = [self processTouchAtPoint:[[touches anyObject] locationInView:self]];
    int sector = [self sectorAtTouchPoint:currentTouchPoint];
    if (sector != _currentSector && sector != RMDpadSectorNone) {
        _currentSector = sector;
        [self adjustBackgroundPositionWithSector:sector];
        [self.delegate dPad:self didTouchSector:sector];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_delegate dPadTouchEnded:self];
    _currentSector = RMDpadSectorNone;
    [self adjustBackgroundPositionWithSector:RMDpadSectorCenter];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void)adjustBackgroundPositionWithSector:(RMDpadSector)sector
{       
    self.dpadImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@-active",self.imageName]];
    
    switch(sector) {
        case RMDpadSectorUp:
            self.dpadImageView.transform = CGAffineTransformIdentity;
            break;
            
        case RMDpadSectorLeft:
            self.dpadImageView.transform = CGAffineTransformMakeRotation(-M_PI/2);
            break;
            
        case RMDpadSectorRight:
            self.dpadImageView.transform = CGAffineTransformMakeRotation(M_PI/2);
            break;
            
        case RMDpadSectorDown:
            self.dpadImageView.transform = CGAffineTransformMakeRotation(M_PI);
            break;
            
        default:
            self.dpadImageView.image = [UIImage imageNamed:self.imageName];
            self.dpadImageView.transform = CGAffineTransformIdentity;
            break;
    }
}

- (RMDpadSector)sectorAtTouchPoint:(CGPoint)touchPoint
{
    float errPadding = 5;
    
    if (touchPoint.x < -1 * _centerSize.width / 2) {
        if ((touchPoint.y > (-1 * _centerSize.height / 2 - errPadding)) && (touchPoint.y < (_centerSize.height / 2 + errPadding)))
            return RMDpadSectorLeft;
    } else if ((touchPoint.x > -1 * _centerSize.width / 2) && (touchPoint.x < _centerSize.width / 2)) {
        if (touchPoint.y < (-1 * _centerSize.height / 2 + errPadding)) {
            return RMDpadSectorDown;
        } else if ((touchPoint.y > (-1 * _centerSize.height / 2 + errPadding)) && (touchPoint.y < (_centerSize.height / 2 - errPadding))) {
            return RMDpadSectorCenter;
        } else if (touchPoint.y > (_centerSize.height / 2 - errPadding)) {
            return RMDpadSectorUp;
        }
    } else if (touchPoint.x > _centerSize.width / 2) {
        if ((touchPoint.y > (-1 * _centerSize.height / 2 - errPadding)) && (touchPoint.y < (_centerSize.height / 2) + errPadding)) {
            return RMDpadSectorRight;
        }
    }
    return RMDpadSectorNone;
}

- (CGPoint)processTouchAtPoint:(CGPoint)touchPoint
{
    if (touchPoint.x > self.bounds.size.width) {
        touchPoint.x = self.bounds.size.width;
    } else if (touchPoint.x < 0) {
        touchPoint.x = 0;
    }
        
    if (touchPoint.y > self.bounds.size.height) {
        touchPoint.y = self.bounds.size.height;
    } else if (touchPoint.y < 0) {
        touchPoint.y = 0;
    }
    
    CGPoint normPoint = CGPointMake(touchPoint.x - self.width/2, (-1 * (touchPoint.y - self.height/2)));
    
    return normPoint;
}

@end
