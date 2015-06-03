//
//  RMDurationInput.m
//  Romo
//

#import "RMDurationInput.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMScrollingInput.h"

@interface RMDurationInput () <RMScrollingInputDelegate>

@property (nonatomic, strong) RMScrollingInput *input;

@end

@implementation RMDurationInput

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:60];
        for (int i = 0; i < 60; i++) {
            [values addObject:[NSString stringWithFormat:@"%@%d",i < 10 ? @"0" : @"",i]];
        }
        _input = [[RMScrollingInput alloc] initWithFrame:CGRectMake(0, 0, 90, 200)];
        self.input.values = values;
        self.input.inputDelegate = self;
        [self addSubview:self.input];

        UIImageView *selected = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"inputDigitSelected.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 17, 0, 18)]];
        selected.frame = CGRectMake(0, self.height / 2 - 25, self.width, 50);
        [self insertSubview:selected atIndex:0];

        UILabel *seconds = [[UILabel alloc] initWithFrame:CGRectZero];
        seconds.backgroundColor = [UIColor clearColor];
        seconds.textColor = [UIColor whiteColor];
        seconds.text = NSLocalizedString(@"Time-Duration-Input-Unit", @"seconds");
        seconds.font = [UIFont fontWithSize:32];
        seconds.shadowOffset = CGSizeMake(0, -1);
        seconds.shadowColor = [UIColor blackColor];
        seconds.width = [seconds.text sizeWithFont:seconds.font].width;
        seconds.height = 38.0;
        seconds.right = self.width - 28;
        seconds.centerY = self.height / 2;
        [self addSubview:seconds];
    }
    return self;
}

#pragma mark - Public Properties

- (void)setValue:(NSString *)value
{
    super.value = value;
    self.input.value = value;
}

#pragma mark - Duration Input Digit Delegate

- (void)digit:(RMScrollingInput *)digit didChangeToValue:(NSString *)value
{
    super.value = value;
    [self.delegate input:self didChangeValue:self.value];
}

@end
