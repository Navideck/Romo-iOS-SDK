//
//  RMMissionsPageControl.m
//  Romo
//

#import "RMMissionsPageControl.h"
#import "UIView+Additions.h"
#import "RMProgressManager.h"

static const CGFloat sidePadding = 12.0;
static const CGFloat height = 28.0;

// we don't want the page control to be tappable
//#define PAGE_CONTROL_INTERACTION

@interface RMMissionsPageControl ()

@property (nonatomic, strong) NSMutableArray *indicators;

@end

@implementation RMMissionsPageControl

@synthesize indicators = __indicators;
@synthesize currentPage = __currentPage;

- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
#ifdef PAGE_CONTROL_INTERACTION
        self.userInteractionEnabled = YES;
#elseif
        self.userInteractionEnabled = NO;
#endif

        NSMutableArray *chapters = [[RMProgressManager sharedInstance].chapters mutableCopy];
        // Don't display "The End" chapter
        [chapters removeObject:@(RMChapterTheEnd)];
        [chapters removeObject:@(RMChapterTheLab)];
        [chapters removeObject:@(RMCometChase)];
        [chapters removeObject:@(RMCometLineFollow)];

        __indicators = [NSMutableArray arrayWithCapacity:chapters.count];

        [chapters enumerateObjectsUsingBlock:^(NSNumber *chapterValue, NSUInteger idx, BOOL *stop) {
            RMChapter chapter = chapterValue.intValue;
            RMChapterStatus chapterStatus = [[RMProgressManager sharedInstance] statusForChapter:chapter];

            UIImage *chapterImage = nil;
            if (chapterStatus != RMChapterStatusLocked) {
                chapterImage = [UIImage imageNamed:[NSString stringWithFormat:@"planet%dIndicator.png", chapter]];
            } else {
                chapterImage = [UIImage imageNamed:@"planetLockedIndicator.png"];
            }

            UIImageView *indicator = [[UIImageView alloc] initWithImage:chapterImage];
            [self.indicators addObject:indicator];
            [self addSubview:indicator];
        }];

        __currentPage = self.numberOfPages - 1;
    }
    return self;
}

- (void)setCurrentPage:(NSInteger)currentPage
{
    if (currentPage != __currentPage && currentPage >= 0) {
        __currentPage = currentPage;

        [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             CGFloat left = 0;
                             for (int i = 0; i < self.indicators.count; i++) {
                                 UIImageView *indicator = self.indicators[i];

                                 if (i == currentPage) {
                                     indicator.transform = CGAffineTransformMakeScale(1.75, 1.75);
                                 } else {
                                     indicator.transform = CGAffineTransformIdentity;
                                 }

                                 indicator.centerY = height / 2.0;
                                 indicator.left = left;
                                 left = indicator.right + sidePadding;
                             }

                             CGFloat width = left - sidePadding;
                             self.frame = CGRectMake(self.centerX - width / 2, self.top, width, height);
                         } completion:nil];
    }
}

#ifdef PAGE_CONTROL_INTERACTION
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self];
    for (UIView *indicator in self.indicators) {
        if (indicator.right > touchLocation.x) {
            int index = [self.indicators indexOfObject:indicator];
            [self.delegate pageControl:self didSelectPage:index];
            break;
        }
    }
}
#endif

@end
