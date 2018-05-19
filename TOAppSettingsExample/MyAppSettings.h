//
//  MyAppSettings.h
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 16/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import "TOAppSettings.h"
#import <CoreGraphics/CoreGraphics.h>

@interface MyAppSettings : TOAppSettings

@property (nonatomic, assign) BOOL boolProperty;
@property (nonatomic, assign) NSInteger integerProperty;
@property (nonatomic, assign) CGFloat floatProperty;
@property (nonatomic, copy) NSDate *dateProperty;
@property (nonatomic, copy) NSURL *urlProperty;
@property (nonatomic, copy) NSArray<NSString *> *arrayProperty;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *dictionaryProperty;

@end
