#import "RMSpaceStar.h"
#import "UIView+Additions.h"

#define RAND(min, max) ((min) + ((float)(arc4random() % (int)(((max) - (min)) * 1000))) / 1000.0)

@implementation RMSpaceStar

+ (id)randomStar {
	RMSpaceStar* star = [[RMSpaceStar alloc] initWithFrame:CGRectZero];
    
    int randomColor = arc4random() % 2;
	if (randomColor) {
		star.image = [UIImage imageNamed:@"purpleStar.png"];
	} else {
		star.image = [UIImage imageNamed:@"blueStar.png"];
    }
	
    CGFloat scale = RAND(10.0, 72.0);
    star.size = CGSizeMake(scale, scale);

    CGFloat x = RAND(-3.8, 10.6);
    CGFloat y = RAND(-3.2, 3.2);
    CGFloat z = RAND(1.6, 7.2);
    star.location = RMPoint3DMake(x, y, z);

	return star;
}

+ (NSArray *)generateRandomSpaceStarsWithCount:(NSUInteger)count
{
    NSMutableArray *starArray = [[NSMutableArray alloc] initWithCapacity:count];
    
    for (NSUInteger i = 0; i < count; i++) {
        [starArray addObject:[self randomStar]];
    }
    
    return [starArray copy];
}

@end
