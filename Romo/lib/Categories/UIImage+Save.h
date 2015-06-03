//
//  UIImage+Save.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface UIImage (Save)

+ (void)writeToSavedPhotoAlbumWithImage:(UIImage *)image
                       completionTarget:(id)completionTarget
                     completionSelector:(SEL)completionSelector
                            contextInfo:(void *)contextInfo;

@end
