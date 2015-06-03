//
//  RMMusicConstants.h
//  Romo
//
//  Created on 10/21/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#ifndef Romo_RMMusicConstants_h
#define Romo_RMMusicConstants_h

/**
 Different pitches of the musical scale
 */
typedef enum {
    A  = 0,
    Bb = 1,
    B  = 2,
    C  = 3,
    Cs = 4,
    D  = 5,
    Eb = 6,
    E  = 7,
    F  = 8,
    Fs = 9,
    G  = 10,
    Ab = 11
} RMMusicPitch;

/**
 Octaves at which pitches can play
 */
typedef enum {
    RMMusicOctave_0 = 0,
    RMMusicOctave_1 = 1,
    RMMusicOctave_2 = 2,
    RMMusicOctave_3 = 3,
    RMMusicOctave_4 = 4,
    RMMusicOctave_5 = 5,
    RMMusicOctave_6 = 6,
    RMMusicOctave_7 = 7,
    RMMusicOctave_8 = 8
} RMMusicOctave;

#endif
