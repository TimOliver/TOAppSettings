//
//  AppDelegate.m
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 7/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import "AppDelegate.h"
#import "TOAppSettings.h"

@interface MyAppSettings: TOAppSettings

@end

//---

@implementation MyAppSettings

@end

@implementation AppDelegate

- (void)demonstrateAppSettings
{
    
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [self demonstrateAppSettings];
    
    return YES;
}

@end
