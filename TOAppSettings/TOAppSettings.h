//
//  TOAppSettings.h
//
//  Copyright 2018 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
 that will not be backed by `NSUserDefaults`. Because each
 instance of this class is cached, you can reliably expect
 */
+ (nullable NSArray<NSString *> *)ignoredProperties;

/**
 Override this method with a dictionary of default values.
 These will be applied the first time of execution when it
 is detected that `NSUserDefaults` does not contain entries
 for these keys.
 */
+ (nullable NSDictionary<NSString *, id> *)defaultPropertyValues;

/**
 :nodoc:
 These method defines enable subscripting, where property
 values can be set like an `NSDictionary`.
 */
- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
