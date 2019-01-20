//
//  RMRomotePhotoVC.m
//  Romo
//

#import "RMRomotePhotoVC.h"
#import "UIButton+RMButtons.h"
#import "UIView+Additions.h"

@interface RMRomotePhotoVC () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *view;
@property (nonatomic, strong) NSMutableDictionary *photoViews;
@property (nonatomic, strong, readwrite) UIButton *dismissButton;

@end

@implementation RMRomotePhotoVC

@dynamic view;

- (void)loadView
{
    self.view = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.delegate = self;
    self.view.bounces = YES;
    self.view.alwaysBounceHorizontal = YES;
    self.view.showsHorizontalScrollIndicator = NO;
    self.view.backgroundColor = [UIColor blackColor];
    self.view.pagingEnabled = YES;
    
    [self.view addSubview:self.dismissButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    [self.photoViews removeAllObjects];
}

#pragma mark - Public Properties

- (void)setPhotos:(NSArray *)photos
{
    _photos = photos;
    
    [self.photoViews removeAllObjects];
    
    self.view.contentSize = CGSizeMake(photos.count * self.view.width, self.view.height);
    self.view.contentOffset = CGPointMake(self.view.contentSize.width - self.view.width, 0);
    [self scrollViewDidScroll:self.view];
}

- (UIButton *)dismissButton
{
    if (!_dismissButton) {
        _dismissButton = [UIButton backButtonWithImage:nil];
    }
    return _dismissButton;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat x = scrollView.contentOffset.x;
    
    int indexOfLeftPhotoView = (int)(x / scrollView.width);
    UIImageView *leftPhotoView = [self photoViewForPhotoAtIndex:indexOfLeftPhotoView];
    leftPhotoView.left = indexOfLeftPhotoView * scrollView.width;
    [scrollView insertSubview:leftPhotoView atIndex:0];
    
    int indexOfRightPhotoView = indexOfLeftPhotoView + 1;
    if (indexOfRightPhotoView< self.photos.count) {
        UIImageView *rightPhotoView = [self photoViewForPhotoAtIndex:indexOfRightPhotoView];
        rightPhotoView.left = indexOfRightPhotoView * scrollView.width;
        [scrollView insertSubview:rightPhotoView atIndex:0];
    }
    
    CGRect visibleRect = CGRectMake(x, 0, self.view.width, self.view.height);
    for (NSNumber *photoIndex in self.photoViews) {
        UIImageView *photoView = self.photoViews[photoIndex];
        if (!CGRectIntersectsRect(photoView.frame, visibleRect)) {
            [photoView removeFromSuperview];
        }
    }
    
    self.dismissButton.left = x;
}

#pragma mark - Private Methods

- (NSMutableDictionary *)photoViews
{
    if (!_photoViews) {
        _photoViews = [NSMutableDictionary dictionary];
    }
    return _photoViews;
}

- (UIImageView *)photoViewForPhotoAtIndex:(int)index
{
    UIImageView *photoView = self.photoViews[@(index)];
    if (!photoView && index >= 0 && index < self.photos.count) {
        photoView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        photoView.contentMode = UIViewContentModeScaleAspectFit;
        photoView.image = self.photos[index];
        photoView.backgroundColor = [UIColor blackColor];
        
        self.photoViews[@(index)] = photoView;
    }
    return photoView;
}

@end
