//
//  UIImage+Save.m
//  Romo
//

#import "UIImage+Save.h"
#import "RMAlertView.h"
#import <AssetsLibrary/AssetsLibrary.h>

static RMAlertView *photosNotAllowed;

@implementation UIImage (Save)

+ (void)writeToSavedPhotoAlbumWithImage:(UIImage *)image
                       completionTarget:(id)completionTarget
                     completionSelector:(SEL)completionSelector
                            contextInfo:(void *)contextInfo {
    
    // iOS <6 does not allow users to restrict apps from accessing photos
    // and does not support the check for authorization status. So, if the
    // device is running iOS <6, we don't check. The photos will be saved to
    // the Camera Roll.
    if ([[[UIDevice currentDevice] systemVersion] compare:@"6.0" options:NSNumericSearch] != NSOrderedAscending) {
        DDLogVerbose(@"%d", [ALAssetsLibrary authorizationStatus]);
        
        ALAuthorizationStatus authStatus = [ALAssetsLibrary authorizationStatus];
        // There are 4 possible auth statuses. These are the two that prevent access to the library
        if (authStatus == ALAuthorizationStatusDenied || authStatus == ALAuthorizationStatusRestricted) {
            if (photosNotAllowed == nil) {
                photosNotAllowed = [[RMAlertView alloc] initWithTitle:@"Romo can't save photos!"
                                                               message:@"To allow Romo to save photos to your Camera Roll, go to Settings > Privacy > Photos, and allow Romo access to your photos."
                                                              delegate:nil];
            }
            [photosNotAllowed show];
            return;
        }
    }

    UIImageWriteToSavedPhotosAlbum(image, completionTarget, completionSelector, contextInfo);
}

@end
