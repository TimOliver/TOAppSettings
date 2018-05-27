//
//  TOAppSettings.h
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 7/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppSettings)
@interface TOAppSettings : NSObject

/**
 Returns an instance of this settings class with the default configuration.
 This object is cached, so subsequent calls will return the same object.
 */
+ (instancetype)defaultSettings NS_SWIFT_NAME(default());

/**
 Returns an instance of this settings class with a unique identifier string.
 This is useful to creating subsequent copies of the same settings class, separate
 from the default settings.
 */
+ (instancetype)settingsWithIdentifier:(nullable NSString *)identifier NS_SWIFT_NAME(init(identifier:));

/**
 Returns an instance of the settings class, with an app container suite name.
 Use this instance when you would like these settings to be shared by other apps
 in the same developer account. */
+ (instancetype)defaultSettingsWithSuiteName:(nullable NSString *)suiteName NS_SWIFT_NAME(init(suiteName:));

/**
 Returns an instance of this settings class with a unique identifier, and with
 an app suite name. Use this to create multiple copies of the same settings class
 and share it amongst apps in the same developer account. */
+ (instancetype)settingsWithIdentifier:(nullable NSString *)identifier suiteName:(nullable NSString *)suiteName NS_SWIFT_NAME(init(identifier:suiteName:));

/**
 Init is disabled. Please use one of the above creation methods
 */
- (instancetype)init NS_UNAVAILABLE;

/** The identifier of this settings instance. Will be `nil` for the default settings. */
@property (nonatomic, copy, readonly) NSString *identifier;

/** The app container suite name set for this settings instance. */
@property (nonatomic, copy, readonly) NSString *suiteName;

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
