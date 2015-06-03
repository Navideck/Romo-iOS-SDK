//
//  GPUImageCustomLookupFilter.h
//  RMVision
//
//  Created on 9/23/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageFilterGroup.h"

@class GPUImagePicture;

/** A photo filter based on semantic color labeling
 http://lear.inrialpes.fr/people/vandeweijer/color_names.html
 
 */

// Note: If you want to use this effect you have to add the .png image
// from Resources folder to your application bundle.

@interface GPUImageCustomLookupFilter : GPUImageFilterGroup
{
    GPUImagePicture *lookupImageSource;
}

- (id)initWithImageNamed:(NSString *) imageName;


@end