//
//  MyAppSettings.h
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 16/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import "TOAppSettings.h"

@interface MyAppSettings : TOAppSettings

@property (nonatomic, assign) BOOL boolProperty;
@property (nonatomic, assign) NSInteger integerProperty;
@property (nonatomic, assign) float floatProperty;
@property (nonatomic, assign) double doubleProperty;
@property (nonatomic, copy) NSString *stringProperty;
@property (nonatomic, copy) NSDate *dateProperty;
@property (nonatomic, copy) NSURL *urlProperty;
@property (nonatomic, copy) NSArray<NSString *> *arrayProperty;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *dictionaryProperty;

@property (nonatomic, readonly) NSString *readOnlyString;

@end
