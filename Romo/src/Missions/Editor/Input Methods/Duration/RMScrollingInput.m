//
//  RMDurationInputDigit.m
//  Romo
//

#import "RMScrollingInput.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMScrollingInput () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableArray *valueLabels;

/** If there are enough inputs, they should wrap around and infinitely scroll */
@property (nonatomic) BOOL wraps;

@end

@implementation RMScrollingInput

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.decelerationRate = UIScrollViewDecelerationRateFast;
        self.showsVerticalScrollIndicator = NO;
        self.delegate = self;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
        [self addGestureRecognizer:tap];

        _valueLabels = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Properties

- (void)setValues:(NSArray *)values
{
    _values = [NSArray arrayWithArray:values];

    self.wraps = (values.count >= 6);

    for (UILabel *valueLabel in self.valueLabels) {
        [valueLabel removeFromSuperview];
    }
    [self.valueLabels removeAllObjects];

    for (int i = 0; i < values.count; i++) {
        UILabel *digit = [[UILabel alloc] initWithFrame:CGRectZero];
        digit.backgroundColor = [UIColor clearColor];
        digit.textColor = [UIColor whiteColor];
        digit.text = [NSString stringWithFormat:@"%@",values[i]];
        digit.font = [UIFont fontWithSize:32];
        digit.shadowOffset = CGSizeMake(0, -1);
        digit.shadowColor = [UIColor blackColor];
        digit.width = [digit.text sizeWithFont:digit.font].width;
        digit.height = 38.0;
        digit.centerX = self.width/2;
        if (self.wraps) {
            digit.centerY = self.contentOffset.y + (((i + 5) % (int)(values.count)) - 5) * 38.0 + self.height / 2;
        } else {
            digit.centerY = 38.0 * i + self.height / 2;
        }
        [self addSubview:digit];
        [self.valueLabels addObject:digit];
    }

    if (self.wraps) {
        self.contentSize = CGSizeMake(self.width, self.height * 2 * values.count);
        self.contentOffset = CGPointMake(0, self.height * values.count);
    } else {
        self.contentSize = CGSizeMake(self.width, ((values.count - 1) * 38.0) + self.height);
    }

    [self scrollViewDidScroll:self];
}

#pragma mark - UIScrollViewDelegate

- (BOOL)scrollsToTop
{
    return NO;
}

// Reposition any labels that flowed off the screen so the scrolling seems continuous & infinite
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat top = self.contentOffset.y;
    CGFloat bottom = top + self.height;

    for (int i = 0; i < self.values.count; i++) {
        UILabel *digit = self.valueLabels[i];

        if (self.wraps) {
            if (digit.top > bottom) {
                digit.top -= digit.height * self.values.count;
            } else if (digit.bottom < top) {
                digit.top += digit.height * self.values.count;
            }
        }

        digit.alpha = 1.0 - ABS((digit.centerY - top) - (self.height / 2)) / (self.height / 2);
    }

    if (self.wraps) {
        if (top < self.height) {
            self.contentOffset = CGPointMake(0, self.contentOffset.y + ((UIView *)(self.valueLabels[0])).height * self.values.count);
        } else if (bottom > self.contentSize.height - self.height) {
            self.contentOffset = CGPointMake(0, self.contentOffset.y - ((UIView *)(self.valueLabels[0])).height * self.values.count);
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // We want to force the scrollView to end scrolling perfectly centered on a value

    // This is where the scrollView wants to end decelerating, so we'll find the closest digit
    CGFloat y = (*targetContentOffset).y + self.height / 2;
    CGFloat y0 = y;

    // Since our digits wrap around, they might actually be in the wrong direction, so we need to search accounting for this
    while (1) {
        for (int i = 0; i < self.values.count; i++) {
            UILabel *digit = self.valueLabels[i];
            if (digit.top < y && y <= digit.bottom) {
                (*targetContentOffset).y = digit.centerY - self.height / 2 + (y0 - y);
                // Update the ivar, but not the property because we don't want the custom setter
                // to scroll us to that value. Let the scrollView do it naturally.
                _value = digit.text;
                return;
            }
        }
        // If we didn't find a digit at the target offset, we need to look in the opposite direction
        // of the velocity (where the numbers were), then account for this modulo later
        CGFloat jump = self.values.count * ((UIView *)(self.valueLabels[0])).height;
        y += (velocity.y > 0) ? -jump : jump;
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

// When the scrollView stops, we want to use the property setter to notify our delegate
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (self.wraps) {
        self.value = _value;
    } else {
        [self.inputDelegate digit:self didChangeToValue:_value];
    }
}

#pragma mark - Gesture Recognizer

// Scroll to whichever value they tapped
- (void)didTap:(UITapGestureRecognizer *)tap
{
    CGFloat y = [tap locationInView:self].y;

    for (int i = 0; i < self.values.count; i++) {
        UILabel *digit = self.valueLabels[i];
        if (digit.top < y && y <= digit.bottom) {
            self.value = digit.text;
        }
    }
}

// Scroll to the value
- (void)setValue:(NSString *)value
{
    for (int i = 0; i < self.values.count; i++) {
        UILabel *digit = self.valueLabels[i];
        if ([digit.text isEqualToString:value]) {
            [self setContentOffset:CGPointMake(0, digit.centerY - self.height / 2) animated:(_value != nil)];
        }
    }

    _value = value;

    [self.inputDelegate digit:self didChangeToValue:value];
}

@end
