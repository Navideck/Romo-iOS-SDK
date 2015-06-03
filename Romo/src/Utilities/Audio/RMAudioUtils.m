//
//  RMAudioUtils.m
//  Romo
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMAudioUtils.h"

#define kTrainingSound      @"TrainingSound-%d"
#define kNumTrainingBins    8

@implementation RMAudioUtils

+ (void)updateTrainingSoundAtProgress:(float)progress
                     withLastProgress:(float)lastProgress
{
    int currentBin = (int)(progress * kNumTrainingBins);
    int lastBin = (int)(lastProgress * kNumTrainingBins);
    if (currentBin != lastBin) {
        NSString *trainingEffect = [NSString stringWithFormat:kTrainingSound, currentBin];
        [RMSoundEffect playForegroundEffectWithName:trainingEffect repeats:NO gain:1.0];
    }
}

@end
