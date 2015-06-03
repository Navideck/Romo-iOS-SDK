//
//  Serializable.h
//  Romo
//
//

@class RMSerializable;

#pragma mark - Serializable (Protocol) --

/**
 * A protocol which defines methods required to serialize objects for
 * conversion into NSData objects.
 * The below abstract class is preferred, but this protocol can be used
 * for classes which are already subclassed.
 */
@protocol Serializable <NSCoding>

/**
 * Deserializes an object from the provided NSData.
 * The object must override initWithCoder to describe how to deserialize the data.
 * @return The initialized object.
 * @param data The data from which to deserialize the object.
 */
+ (RMSerializable *)deserializeData:(NSData *)data;

/**
 * Serializes the object into an NSData instance.
 * The object must override encodeWithCoder to describe how to serialize the data.
 * @return The serialized NSData instance.
 */
- (NSData *)serialize;

@end

#pragma mark - Serializable (Class) --

/**
 * An "abstract" class used as a base class for Serializable objects.
 * Already implements initWithData: as well as serialize.
 * Preferable to the above Protocol simply because of ease of use.
 */
@interface RMSerializable : NSObject <Serializable>

@end
