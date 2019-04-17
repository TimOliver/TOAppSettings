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
@property (nonatomic, assign) float height;
@property (nonatomic, strong) NSDictionary *voiceActors;
@property (nonatomic, strong) NSData *portalGunFormula;
@property (nonatomic, strong) UIColor *portalGunColor;
@property (nonatomic, assign) BOOL isDrunk;

@end

@implementation TestSettings

// Test swapping accessor methods vs adding them
@dynamic isDrunk;

+ (NSDictionary *)defaultPropertyValues
{
	return @{@"isDrunk": @YES, @"height": @(-1.05f)};
}

@end

// ---------------------------------------------------------------------------

@interface TOAppSettingsTests : XCTestCase

@end

// ---------------------------------------------------------------------------

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
        settings.name = @"Rick"; // String
        settings.age = 70; // Int
        settings.birthdate = [NSDate dateWithTimeIntervalSince1970:-241290000]; //NSDate
        settings.grandkids = @[@"Morty", @"Summer"]; //NSArray
        settings.height = 6.2f; // Float
        settings.voiceActors = @{@"English": @"Justin Roiland"}; // NSDictionary
        settings.portalGunFormula = [@"McDonald's Szechuan McNugget Sauce" dataUsingEncoding:NSUTF8StringEncoding]; // NSData
        settings.portalGunColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f]; // <NSCoding>
    }
    
    // Get a second copy of the same instance and compare data was successfully retrieved
    TestSettings *settings = [TestSettings defaultSettings];
    XCTAssert([settings.name isEqualToString:@"Rick"]);
    XCTAssert(settings.age == 70);
    XCTAssert([settings.birthdate isEqual:[NSDate dateWithTimeIntervalSince1970:-241290000]]);
    XCTAssert([settings.grandkids.firstObject isEqualToString:@"Morty"]);
    XCTAssert([settings.voiceActors[@"English"] isEqualToString:@"Justin Roiland"]);
    XCTAssert([[[NSString alloc] initWithData:settings.portalGunFormula encoding:NSUTF8StringEncoding] isEqualToString:@"McDonald's Szechuan McNugget Sauce"]);
    XCTAssert([settings.portalGunColor isEqual:[UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:1.0f]]);
}

- (void)testDefaultValueUpdate {
	
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	// note: "className.ID.property"
	
	NSString * clsName = @"TestSettings";
	NSString * identifier = @"DefValTest";

	[defaults setObject:@"default-value"
				 forKey:[NSString stringWithFormat:@"%@.%@.%@", clsName, identifier, @"Name"]];

	[defaults setObject:@(42)
				 forKey:[NSString stringWithFormat:@"%@.%@.%@", clsName, identifier, @"Age"]];

	[defaults synchronize];
	
	// Set initial object, then dealloc
	@autoreleasepool {
		TestSettings * settings = [TestSettings settingsWithIdentifier:identifier];
		settings = nil;
	}
	
	// Get a second copy of the same instance and compare data was successfully retrieved
	TestSettings * settings = [TestSettings settingsWithIdentifier:identifier];
	
	XCTAssert([settings.name isEqualToString:@"default-value"]);
	XCTAssert(settings.age == 42);
	
	XCTAssert(settings.height == -1.05f);
	XCTAssert(settings.isDrunk == YES);
}

// Test that two separate copies of the same object can be saved
- (void)testSeparateCopies
{
    @autoreleasepool {
        TestSettings *rick = [TestSettings settingsWithIdentifier:@"Rick"];
        rick.name = @"Rick";
        
        TestSettings *morty = [TestSettings settingsWithIdentifier:@"Morty"];
        morty.name = @"Morty";
    }
    
    TestSettings *rick = [TestSettings settingsWithIdentifier:@"Rick"];
    TestSettings *morty = [TestSettings settingsWithIdentifier:@"Morty"];
    
    XCTAssert([rick.name isEqualToString:@"Rick"]);
    XCTAssert([morty.name isEqualToString:@"Morty"]);
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
