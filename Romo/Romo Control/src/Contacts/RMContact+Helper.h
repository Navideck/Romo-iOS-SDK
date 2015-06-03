//
//  RMContact+Helper.h
//  Romo
//
//  Created on 11/12/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMContact.h"

@interface RMContact (Helper)

/** Creates a contact with the specified parameters */
+ (RMContact *)createContact:(NSString *)userName
                withRomoName:(NSString *)romoName
              withRomoNumber:(NSString *)romoID
               withTimestamp:(NSDate *)lastCallDate
      inManagedObjectContext:(NSManagedObjectContext *)context;

/** Returns a contact for a given ID */
+ (RMContact *)getContactWithID:(NSString *)romoID
         inManagedObjectContext:(NSManagedObjectContext *)context;

/** Returns all contacts in the managed object context */
+ (NSArray *)getAllPeopleInManagedObjectContect:(NSManagedObjectContext *)context;

@end
