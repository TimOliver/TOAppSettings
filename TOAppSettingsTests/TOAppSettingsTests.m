//
//  TOAppSettingsTests.m
//  TOAppSettingsTests
//
//  Created by Tim Oliver on 28/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TOAppSettings.h"

// ---------------------------------------------------------------------------

@interface TestSettings : TOAppSettings

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, strong) NSDate *birthdate;
@property (nonatomic, strong) NSArray *grandkids;

@property (nonatomic, assign) BOOL isDrunk;

@end

@implementation TestSettings

+ (NSDictionary *)defaultPropertyValues
{
    return @{@"isDrunk": @YES};
}

@end

// ---------------------------------------------------------------------------

@interface TOAppSettingsTests : XCTestCase

@end

@implementation TOAppSettingsTests

- (void)setUp {
    [super setUp];
    
    // Clear all of user defaults to ensure a fresh deploy each time
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
}

// Test that it's possible to write settings to one instance, and then read back
// the same settings in a separate instance
- (void)testDefaultSettingsWriteAndRead
{
    // Set initial object, set properties, then dealloc
    @autoreleasepool {
        TestSettings *settings = [TestSettings defaultSettings];
        settings.name = @"Rick";
        settings.age = 70;
        settings.birthdate = [NSDate dateWithTimeIntervalSince1970:-241290000];
        settings.grandkids = @[@"Morty", @"Summer"];
    }
    
    // Get a second copy of the same instance and compare data was successfully retrieved
    TestSettings *settings = [TestSettings defaultSettings];
    XCTAssert([settings.name isEqualToString:@"Rick"]);
    XCTAssert(settings.age == 70);
    XCTAssert([settings.birthdate isEqual:[NSDate dateWithTimeIntervalSince1970:-241290000]]);
    XCTAssert([settings.grandkids.firstObject isEqualToString:@"Morty"]);
}

// Test that the caching mechanism is ensuring that the same instance is returned on each call
- (void)testDefaultSettingsCache
{
    TestSettings *first = [TestSettings defaultSettings];
    TestSettings *second = [TestSettings defaultSettings];
    XCTAssert(first == second);
}

- (void)testDefaultPropertyValues
{
    XCTAssert([TestSettings defaultSettings].isDrunk == YES);
}

@end
