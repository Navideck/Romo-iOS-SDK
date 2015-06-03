//
//  RMTelepresence2ClientViewController.h
//  Romo
//
//  Created on 11/7/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^RMTelepresence2ClientViewControllerCompletion)(NSError *error);

@interface RMTelepresenceClientViewController : UIViewController

- (instancetype)initWithNumber:(NSString *)number
                    completion:(RMTelepresence2ClientViewControllerCompletion)completion;

@end
