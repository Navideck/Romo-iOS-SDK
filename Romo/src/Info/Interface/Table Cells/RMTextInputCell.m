//
//  RMTextInputCell.m
//  Romo
//

#import "RMTextInputCell.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"

@interface RMTextInputCell ()

@property (nonatomic, strong) UIView *dividerLine;

@end

@implementation RMTextInputCell

+ (instancetype)dequeueOrCreateCellForTableView:(UITableView *)tableView
{
    static NSString *identifier = @"RMTextInputCell";
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
        
        self.inputField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.inputField.font = [UIFont mediumFont];
        self.inputField.textColor = [UIColor romoBlue];
        self.inputField.textAlignment = NSTextAlignmentRight;
        self.inputField.returnKeyType = UIReturnKeyDone;
        self.inputField.backgroundColor = [UIColor clearColor];

        [self addSubview:self.mainLabel];
        [self addSubview:self.inputField];
        [self addSubview:self.dividerLine];

        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)layoutSubviews
{
    self.mainLabel.frame = CGRectMake(20, 19, 100, 21);
    self.inputField.frame = CGRectMake(125, 17, 175, 36);
    self.dividerLine.frame = CGRectMake(0, self.bounds.size.height - 0.5, self.bounds.size.width, 0.5);
}

@end
