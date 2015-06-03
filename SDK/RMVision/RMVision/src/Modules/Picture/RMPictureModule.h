//
//  RMPictureModule.h
//  RMVision
//
//  Created on 6/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMVisionModuleProtocol.h"
#import "RMVisionModule.h"

@interface RMPictureModule : RMVisionModule <RMVisionModuleProtocol>

@end

/**
 Posts a notifcation whenever a picture is captured
 The photo is a UIImage stored in the userInfo dictionary with "photo" as the key
 */
extern NSString *const RMPictureModuleDidTakePictureNotification;