//
//  RMTimeInput.m
//  Romo
//

#import "RMTimeInput.h"
#import "RMScrollingInput.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMTimeInput () <RMScrollingInputDelegate>

@property (nonatomic, strong) RMScrollingInput *hours;
@property (nonatomic, strong) RMScrollingInput *minutes;
@property (nonatomic, strong) RMScrollingInput *amPm;

@end

@implementation RMTimeInput

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _hours = [[RMScrollingInput alloc] initWithFrame:CGRectMake(8, 0, 44, 200)];
        self.hours.inputDelegate = self;
        self.hours.centerY = self.height / 2;
        self.hours.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.hours];

        NSMutableArray *minutes = [NSMutableArray arrayWithCapacity:60];
        for (int i = 0; i < 60; i++) {
            [minutes addObject:[NSString stringWithFormat:@"%@%d", i < 10 ? @"0" : @"", i]];
        }

        _minutes = [[RMScrollingInput alloc] initWithFrame:CGRectMake(50, 0, 66, 200)];
        self.minutes.values = minutes;
        self.minutes.inputDelegate = self;
        self.minutes.centerY = self.height / 2;
        self.minutes.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.minutes];
        
        _amPm = [[RMScrollingInput alloc] initWithFrame:CGRectMake(114, 0, 68, 200)];
        self.amPm.values = @[NSLocalizedString(@"Time-Input-AM", @"AM"),NSLocalizedString(@"Time-Input-PM", @"PM")];
        self.amPm.inputDelegate = self;
        self.amPm.centerY = self.height / 2;
        self.amPm.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.amPm];

        UILabel *colon = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, 10, 32)];
        colon.backgroundColor = [UIColor clearColor];
        colon.text = @":";
        colon.textColor = [UIColor whiteColor];
        colon.font = [UIFont fontWithSize:32];
        colon.centerY = self.height / 2 - 4;
        colon.shadowColor = [UIColor blackColor];
        colon.shadowOffset = CGSizeMake(0, -1);
        colon.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:colon];

        UIImageView *selected = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"inputDigitSelected.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 17, 0, 18)]];
        selected.frame = CGRectMake(0, self.height / 2 - 25, self.width, 50);
        selected.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
        [self insertSubview:selected atIndex:0];
    }
    return self;
}

#pragma mark - Public Properties

- (void)setValue:(NSString *)value
{
    super.value = value;
    
    NSRange colonRange = [value rangeOfString:@":"];
    NSRange spaceRange = [value rangeOfString:@" "];
    BOOL hasAmPm = spaceRange.length;

    if (hasAmPm) {
        self.hours.values = @[@"12",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"10",@"11"];
        self.amPm.value = [value substringFromIndex:spaceRange.location + 1];
        [self addSubview:self.amPm];
    } else {
        self.hours.values = @[@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"10",@"11",@"12",@"13",@"14",@"15",@"16",@"17",@"18",@"19",@"20",@"21",@"22",@"23"];
        self.amPm.value = nil;
        [self.amPm removeFromSuperview];
    }
    
    self.hours.value = [value substringToIndex:colonRange.location];
    self.minutes.value = [value substringWithRange:NSMakeRange(colonRange.location + 1, 2)];
}

#pragma mark - Duration Input Digit Delegate

- (void)digit:(RMScrollingInput *)digit didChangeToValue:(NSString *)value
{
    if (self.amPm.value) {
        super.value = [NSString stringWithFormat:@"%@:%@ %@", self.hours.value, self.minutes.value, self.amPm.value];
    } else {
        super.value = [NSString stringWithFormat:@"%@:%@", self.hours.value, self.minutes.value];
    }
    [self.delegate input:self didChangeValue:self.value];
}

@end
