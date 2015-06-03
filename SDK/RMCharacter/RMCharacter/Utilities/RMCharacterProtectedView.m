//
//  RMCharacterProtectedView.m
//  RMCharacter
//

#import "RMCharacterProtectedView.h"

@implementation RMCharacterProtectedView

- (id)initWithFrame:(CGRect)frame backgroundColor:(UIColor *)backgroundColor subview:(UIView *)subview
{
    self = [super initWithFrame:frame];
    if (self) {
        super.frame = frame;
        [super setUserInteractionEnabled:NO];
        [super setBackgroundColor:backgroundColor];
        [super addSubview:subview];
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {}
- (void)setFrame:(CGRect)frame {}
- (void)setBounds:(CGRect)bounds {}
- (void)setCenter:(CGPoint)center {}
- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {}
- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)siblingSubview {}
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index {}
- (void)insertSubview:(UIView *)view belowSubview:(UIView *)siblingSubview {}
- (void)addSubview:(UIView *)view {}
- (void)bringSubviewToFront:(UIView *)view { }
- (void)setTransform:(CGAffineTransform)transform {}
- (void)setTag:(NSInteger)tag {}
- (void)setAlpha:(CGFloat)alpha {}
- (void)setAutoresizingMask:(UIViewAutoresizing)autoresizingMask {}
- (void)setContentMode:(UIViewContentMode)contentMode {}
- (void)setExclusiveTouch:(BOOL)exclusiveTouch {}
- (void)setGestureRecognizers:(NSArray *)gestureRecognizers {}
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {}
- (void)addConstraint:(NSLayoutConstraint *)constraint {}
- (void)addConstraints:(NSArray *)constraints {}
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {}
- (void)setContentScaleFactor:(CGFloat)contentScaleFactor {}
- (void)setHidden:(BOOL)hidden {}
- (void)setNeedsDisplay {}
- (void)setNeedsLayout {}
- (void)setNeedsUpdateConstraints {}
- (void)setOpaque:(BOOL)opaque {}
- (void)setTranslatesAutoresizingMaskIntoConstraints:(BOOL)flag {}
- (void)setValuesForKeysWithDictionary:(NSDictionary *)keyedValues {}
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {}
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {}
- (void)setValue:(id)value forKey:(NSString *)key {}
- (void)setNilValueForKey:(NSString *)key {}
- (void)setMultipleTouchEnabled:(BOOL)multipleTouchEnabled {}
- (void)setContentCompressionResistancePriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis {}
- (void)setContentHuggingPriority:(UILayoutPriority)priority forAxis:(UILayoutConstraintAxis)axis {}
- (void)setClearsContextBeforeDrawing:(BOOL)clearsContextBeforeDrawing {}
- (void)setClipsToBounds:(BOOL)clipsToBounds {}
- (NSArray *)subviews { return nil; }
- (CGRect)frame { return CGRectZero; }
- (Class)class { return [UIView class]; }
- (CGPoint)center { return CGPointZero; }
- (CGFloat)alpha { return 0.0; }
- (CGRect)bounds { return CGRectZero; }
- (UIColor *)backgroundColor { return nil; }
- (BOOL)becomeFirstResponder { return NO; }

@end
