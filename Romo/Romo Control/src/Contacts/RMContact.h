//
//  RMContact.h
//  Romo
//
//  Created on 11/12/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface RMContact : NSManagedObject

@property (nonatomic, retain) NSDate * lastCallDate;
@property (nonatomic, retain) NSString * romoID;
@property (nonatomic, retain) NSString * romoName;
@property (nonatomic, retain) NSString * userName;

@end
