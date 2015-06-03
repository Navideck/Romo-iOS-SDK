//
//  Serializable.m
//  Romo
//

#import "RMSerializable.h"

#pragma mark - Constants

#define KEY_SERIALIZED @"serialized"

@implementation RMSerializable

+ (id<Serializable>)deserializeData:(NSData *)data
{
    NSKeyedUnarchiver *unarchiver = nil;
    @try {
        unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    }
    @catch (NSException *exception) {
        return nil;
    }
        
    RMSerializable *serializable = [unarchiver decodeObjectForKey:KEY_SERIALIZED];
        
	[unarchiver finishDecoding];
    
    return serializable;
}

- (NSData *)serialize
{
    NSMutableData *data = [[NSMutableData alloc] init];
    
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
	[archiver encodeObject:self forKey:KEY_SERIALIZED];
	
    [archiver finishEncoding];
    
    NSData *result = [NSData dataWithData:data];
    
    return result;
}

#pragma mark - NSCoding --

- (id)initWithCoder:(NSCoder *)coder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

@end
