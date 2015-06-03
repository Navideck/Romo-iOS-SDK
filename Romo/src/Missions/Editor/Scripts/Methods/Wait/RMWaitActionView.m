//
//  RMTurnActionView.m
//  Romo
//

#import "RMWaitActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMScrollingInput.h"

@interface RMWaitActionView () <RMScrollingInputDelegate>

@property (nonatomic, strong) UIImageView *timerBackground;
@property (nonatomic, strong) UILabel *durationLabel;

/** Duration in seconds to pause for */
@property (nonatomic) double duration;

/** Displayed when editing */
@property (nonatomic, strong) RMScrollingInput *onesInput;
@property (nonatomic, strong) UIView *decimalDot;
@property (nonatomic, strong) RMScrollingInput *decimalInput;
@property (nonatomic, strong) UILabel *durationInputLabel;

@end

@implementation RMWaitActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _timerBackground = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"waitTimerBackground.png"]];
        self.timerBackground.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 12);
        [self.contentView addSubview:self.timerBackground];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterDuration) {
            self.duration = [parameter.value doubleValue];
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];

    if (editing) {
        int decimal = 100 * (self.duration - floor(self.duration));
        
        self.onesInput.value = [NSString stringWithFormat:@"%d", (int)floor(self.duration)];
        self.decimalInput.value = [NSString stringWithFormat:@"%@%d", decimal < 10 ? @"0" : @"", decimal];
        
        self.onesInput.center = CGPointMake(self.contentView.width / 2 - 40, self.contentView.height / 2);
        self.decimalDot.center = CGPointMake(self.onesInput.right - 6, self.onesInput.centerY + 7);
        self.decimalInput.center = CGPointMake(self.contentView.width / 2 + 10, self.onesInput.centerY);
        self.durationInputLabel.bottom = self.contentView.height + 80;

        self.onesInput.alpha = 0.0;
        self.decimalInput.alpha = 0.0;
        self.decimalDot.alpha = 0.0;
        self.durationInputLabel.alpha = 0.0;

        [self.contentView addSubview:self.onesInput];
        [self.contentView addSubview:self.decimalInput];
        [self.contentView addSubview:self.decimalDot];
        [self.contentView addSubview:self.durationInputLabel];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    self.onesInput.center = CGPointMake(self.contentView.width / 2 - 40, self.contentView.height / 2);
    self.decimalDot.center = CGPointMake(self.onesInput.right - 6, self.onesInput.centerY + 7);
    self.decimalInput.center = CGPointMake(self.contentView.width / 2 + 10, self.onesInput.centerY);

    if (editing) {
        self.timerBackground.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2);
        self.durationLabel.center = CGPointMake(self.contentView.width / 2 - 4, self.contentView.height / 2);
        self.durationInputLabel.bottom = self.contentView.height - 16;
        
        self.durationLabel.alpha = 0.0;
        self.onesInput.alpha = 1.0;
        self.decimalInput.alpha = 1.0;
        self.decimalDot.alpha = 1.0;
        self.durationInputLabel.alpha = 1.0;
    } else {
        self.timerBackground.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 12);
        self.durationLabel.center = CGPointMake(self.contentView.width / 2 - 4, self.contentView.height / 2 + 13);
        self.durationInputLabel.bottom = self.contentView.height + 80;
        
        self.durationLabel.alpha = 1.0;
        self.onesInput.alpha = 0.0;
        self.decimalInput.alpha = 0.0;
        self.decimalDot.alpha = 0.0;
        self.durationInputLabel.alpha = 0.0;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    if (!editing) {
        [self.onesInput removeFromSuperview];
        [self.decimalInput removeFromSuperview];
        [self.decimalDot removeFromSuperview];
        [self. durationInputLabel removeFromSuperview];
    }
}

#pragma mark - RMDurationInputDigitDelegate

- (void)digit:(RMScrollingInput *)digit didChangeToValue:(NSString *)value
{
    self.duration = [self.onesInput.value doubleValue] + ([self.decimalInput.value doubleValue] / 100.0);
}

#pragma mark - Private Methods

- (void)setDuration:(double)duration
{
    _duration = duration;
    
    self.durationLabel.text = [NSString stringWithFormat:@"%.2f",duration];
    self.durationLabel.size = [self.durationLabel.text sizeWithFont:self.durationLabel.font];
    
    if (self.isEditing) {
        self.durationLabel.center = CGPointMake(self.contentView.width / 2 - 4, self.contentView.height / 2);
    } else {
        self.durationLabel.center = CGPointMake(self.contentView.width / 2 - 4, self.contentView.height / 2 + 13);
    }
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterDuration) {
            parameter.value = @(duration);
        }
    }
}

- (RMScrollingInput *)onesInput
{
    if (!_onesInput) {
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:10];
        for (int i = 0; i < 10; i++) {
            [values addObject:[NSString stringWithFormat:@"%d",i]];
        }
        
        _onesInput = [[RMScrollingInput alloc] initWithFrame:CGRectMake(0, 0, 50, 200)];
        _onesInput.values = values;
        _onesInput.inputDelegate = self;
    }
    return _onesInput;
}

- (UIView *)decimalDot
{
    if (!_decimalDot) {
        _decimalDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 6)];
        _decimalDot.userInteractionEnabled = NO;
        _decimalDot.layer.cornerRadius = self.decimalDot.width / 2;
        _decimalDot.layer.shadowColor = [UIColor blackColor].CGColor;
        _decimalDot.layer.shadowOffset = CGSizeMake(0, -1);
        _decimalDot.layer.shadowOpacity = 1.0;
        _decimalDot.layer.shadowRadius = 0.0;
        _decimalDot.backgroundColor = [UIColor whiteColor];
    }
    return _decimalDot;
}

- (RMScrollingInput *)decimalInput
{
    if (!_decimalInput) {
        NSMutableArray *values = [NSMutableArray arrayWithCapacity:20];
        for (int i = 0; i < 20; i++) {
            [values addObject:[NSString stringWithFormat:@"%@%d",i * 5 < 10 ? @"0" : @"",i * 5]];
        }
        
        _decimalInput = [[RMScrollingInput alloc] initWithFrame:CGRectMake(0, 0, 50, 200)];
        _decimalInput.values = values;
        _decimalInput.inputDelegate = self;
    }
    return _decimalInput;
}

- (UILabel *)durationLabel
{
    if (!_durationLabel) {
        _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.textColor = [UIColor whiteColor];
        _durationLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _durationLabel.shadowOffset = CGSizeMake(0, -1);
        _durationLabel.font = [UIFont fontWithSize:48];
        _durationLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_durationLabel];
    }
    return _durationLabel;
}

- (UILabel *)durationInputLabel
{
    if (!_durationInputLabel) {
        _durationInputLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _durationInputLabel.backgroundColor = [UIColor clearColor];
        _durationInputLabel.textColor = [UIColor whiteColor];
        _durationInputLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _durationInputLabel.shadowOffset = CGSizeMake(0, -1);
        _durationInputLabel.font = [UIFont smallFont];
        _durationInputLabel.text = NSLocalizedString(@"Action-Duration-Input-Label-Title", @"Do nothing for this amount of time");
        _durationInputLabel.size = [self.durationInputLabel.text sizeWithFont:self.durationInputLabel.font];
        _durationInputLabel.centerX = self.width / 2;
    }
    return _durationInputLabel;
}

@end
