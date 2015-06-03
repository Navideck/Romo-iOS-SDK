//
//  RMSayActionView.m
//  Romo
//

#import "RMSayActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMSayActionView () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textView;

@property (nonatomic, copy) NSString *text;

/** If they delete the whole input, revert to the text before editing */
@property (nonatomic, strong) NSString *originalText;

@end

@implementation RMSayActionView

#pragma mark - Public Properties

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.textView.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2.0 + 21);
        [self.contentView addSubview:self.textView];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterText) {
            self.text = [parameter.value stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            self.textView.text = self.text;
        }
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;

    self.textView.userInteractionEnabled = editing;
    
    if (editing) {
        self.originalText = self.text;
        [self.textView becomeFirstResponder];
        self.textView.center = CGPointMake(self.contentView.width / 2, (self.contentView.height - 240) / 2.0 + 40);
    } else {
        if (!self.text.length) {
            self.text = self.originalText;
        }
        [self.textView resignFirstResponder];
        self.textView.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2.0 + 21);
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        [self.delegate toggleEditingForActionView:self];
        return NO;
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    self.text = [textView.text stringByReplacingOccurrencesOfString:@"\n" withString:@""];
}

#pragma mark - Private Properties

- (void)setText:(NSString *)text
{
    if (text.length > 20) {
        text = [text substringToIndex:20];
    }
    _text = text;
    self.textView.text = text;

    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterText) {
            parameter.value = text;
        }
    }
}

- (UITextView *)textView
{
    if (!_textView) {
        _textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.contentView.width - 32, self.contentView.height)];
        _textView.delegate = self;
        _textView.clipsToBounds = NO;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.textColor = [UIColor whiteColor];
        _textView.layer.shadowColor = [UIColor colorWithHue:0.686 saturation:1.0 brightness:0.44 alpha:1.0].CGColor;
        _textView.layer.shadowOffset = CGSizeMake(0, 2.5);
        _textView.layer.shadowOpacity = 0.3;
        _textView.layer.shadowRadius = 3.0;
        _textView.layer.shouldRasterize = YES;
        _textView.layer.rasterizationScale = 2.0;
        _textView.textAlignment = NSTextAlignmentCenter;
        _textView.userInteractionEnabled = NO;
        _textView.returnKeyType = UIReturnKeyDone;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeWords;
        _textView.spellCheckingType = UITextSpellCheckingTypeNo;
        _textView.font = [UIFont fontWithSize:42];
    }
    return _textView;
}

@end
