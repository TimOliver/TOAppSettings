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

@property (nonatomic, assign) NSInteger integerProperty;
@property (nonatomic, assign) CGFloat floatProperty;
@property (nonatomic, assign) BOOL boolProperty;

@end
