//
//  RMTextButtonCell
//  Romo
//

#import "RMTextButtonCell.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"

@interface RMTextButtonCell ()

@property (nonatomic, strong) UIView *dividerLine;

@end

@implementation RMTextButtonCell

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView
{
    static NSString *identifier = @"RMTextButtonCell";
    id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil) {
        cell = [[self alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    return cell;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        self.mainLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.mainLabel.font = [UIFont smallFont];
        self.mainLabel.textColor = [UIColor whiteColor];
        self.mainLabel.backgroundColor = [UIColor clearColor];
        
        self.rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.rightButton.titleLabel.font = [UIFont mediumFont];
        self.rightButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        [self.rightButton setTitleColor:[UIColor romoBlue] forState:UIControlStateNormal];
        [self.rightButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
        
        [self addSubview:self.mainLabel];
        [self addSubview:self.rightButton];
        [self addSubview:self.dividerLine];

        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)layoutSubviews
{
    self.mainLabel.frame = CGRectMake(20, 19, 117, 21);
    self.rightButton.frame = CGRectMake(145, 16, 155, 28);
    self.dividerLine.frame = CGRectMake(0, self.bounds.size.height - 0.5, self.bounds.size.width, 0.5);
}

@end
