//
//  TOAppSettings.h
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 7/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TOAppSettings : NSObject

+ (TOAppSettings *)defaultSettings;

+ (TOAppSettings *)settingsWithIdentifier:(NSString *)identifier;

+ (TOAppSettings *)defaultSettingsWithSuiteName:(NSString *)suiteName;

+ (TOAppSettings *)settingsWithIdentifier:(NSString *)identifier suiteName:(NSString *)suiteName;

/**
 Init is disabled. Please use one of the above creation methods
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 Override this method with an array of any property names
 that you do NOT wish to have persisted.
 */
+ (nullable NSArray<NSString *> *)ignoredProperties;

/**
 Override this method with any initial values that should
 be set when loaded for the first time.
 */
+ (nullable NSDictionary *)defaultPropertyValues;

@end

NS_ASSUME_NONNULL_END
