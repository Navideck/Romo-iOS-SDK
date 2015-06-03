//
//  RMRomoThemeSong.h
//  Romo
//
//  Created on 10/20/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMMusicConstants.h"

static const int themeSong[] = {
    G, Fs, G, Fs, G, Fs, G, Fs, F,
    D, Cs, D, Cs, D, Cs, D, Cs, C,
    G, Fs, G, Fs, G, Fs, G, Fs, F,
    Fs, D
};

static const int ringTone[] = {
    D, Eb, E, D, Eb, E, Eb, D,
    D, Eb, E, D, Eb, E, Eb, D,
    D, Eb, E, D, Eb, E, Eb, D,
    G
};

static const int accents[] = {
    D, Cs, C, Bb,
    Fs, G, A, Bb,
    
};

@interface RMRomoThemeSong : NSObject

@end
