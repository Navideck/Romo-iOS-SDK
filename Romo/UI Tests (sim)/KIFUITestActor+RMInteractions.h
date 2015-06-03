//
//  KIFUITestActor+RMInteractions.h
//  Romo
//
//  Created on 9/10/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <KIF/KIF.h>

@interface KIFUITestActor (RMInteractions)

- (void)romoSays:(NSString *)phrase;
- (void)crashLand;
- (void)pokeRomo;

@end
