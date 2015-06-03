//
//  RMStringListInput.m
//  Romo
//

#import "RMListInput.h"
#import "RMScrollingInput.h"
#import "UIView+Additions.h"

@interface RMListInput () <RMScrollingInputDelegate>

@property (nonatomic, strong) RMScrollingInput *list;

@end

@implementation RMListInput

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _list = [[RMScrollingInput alloc] initWithFrame:CGRectMake(0, 0, 190, 200)];
        self.list.inputDelegate = self;
        self.list.centerY = self.height / 2;
        self.list.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:self.list];

        UIImageView *selected = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"inputDigitSelected.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 17, 0, 18)]];
        selected.frame = CGRectMake(0, self.height / 2 - 25, self.width, 50);
        selected.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self insertSubview:selected atIndex:0];
    }
    return self;
}

- (void)setOptions:(NSArray *)options
{
    _options = options;
    
    self.list.values = options;
}

- (void)digit:(RMScrollingInput *)digit didChangeToValue:(NSString *)value
{
    super.value = value;
    [self.delegate input:self didChangeValue:self.value];
}

- (void)setValue:(id)value
{
    super.value = value;
    self.list.value = value;
}

@end
