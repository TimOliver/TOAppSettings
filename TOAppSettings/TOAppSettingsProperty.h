//
//  TOAppSettingsSchema.h
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 23/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, TOAppSettingsDataType) {
    TOAppSettingsDataTypeUnknown,
    TOAppSettingsDataTypeInt,
    TOAppSettingsDataTypeFloat,
    TOAppSettingsDataTypeDouble,
    TOAppSettingsDataTypeBool,
    TOAppSettingsDataTypeString,
    TOAppSettingsDataTypeArray,
    TOAppSettingsDataTypeDictionary,
    TOAppSettingsDataTypeObject
};

NS_ASSUME_NONNULL_BEGIN

@interface TOAppSettingsProperty : NSObject

/** The name of this propety as defined in the class */
@property (nonatomic, readonly) NSString *name;

/** The data type of this property (e.g., float, int etc) */
@property (nonatomic, readonly) TOAppSettingsDataType dataType;

/** If the property is an object, the class of that object */
@property (nonatomic, readonly, nullable) Class objectClass;

@end

NS_ASSUME_NONNULL_END
