//
//  TOAppSettings.m
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 7/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import "TOAppSettings.h"

#import <objc/runtime.h>

typedef NS_ENUM (NSInteger, TOAppSettingsDataType) {
    TOAppSettingsDataTypeUnknown,
    TOAppSettingsDataTypeInt,
    TOAppSettingsDataTypeFloat,
    TOAppSettingsDataTypeDouble,
    TOAppSettingsDataTypeBool,
    TOAppSettingsDataTypeDate,
    TOAppSettingsDataTypeString,
    TOAppSettingsDataTypeData,
    TOAppSettingsDataTypeArray,
    TOAppSettingsDataTypeDictionary,
    TOAppSettingsDataTypeObject
};

// -----------------------------------------------------------------------

@interface TOAppSettings ()

/** The user defaults that this class writes to */
@property (nonatomic, strong) NSUserDefaults *userDefaults;

/** Internal redeclarations of the objects configuration */
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *suiteName;

/** When saved to the user defaults, every property name is
 formatted with this string as a prefix. This ensures zero collisions
 with any other settings managed by external code. */
@property (nonatomic, copy) NSString *propertyKeyPrefix;

/** Due to the time spent serializing them, `<NSCoding>` objects
    are cached in this object until they are unretained */
@property (nonatomic, strong) NSMapTable *dataPropertyCache;

/** A dispatch barrier used to manage writes to the data cache property */
@property (nonatomic, copy) dispatch_queue_t dataCacheBarrierQueue;

/** Method name defines so they may be accessed from the C functions */
- (NSString *)userDefaultsKeyNameForGetterSelector:(SEL)selector;
- (NSString *)userDefaultsKeyNameForSetterSelector:(SEL)selector;

- (id)cachedDecodedObjectForKey:(NSString *)key;
- (void)setCachedDecodedObject:(id)object forKey:(NSString *)key;

@end

// -----------------------------------------------------------------------

#pragma mark - Property Accessor Analysis -

static inline TOAppSettingsDataType TOAppSettingsDataTypeForProperty(const char *attributes)
{
    if (!attributes || strlen(attributes) == 0) { return TOAppSettingsDataTypeUnknown; }
    
    // Basic types are represented by a single character, following the initial "T" marker
    char propertyType = attributes[1];
    
    switch (propertyType) {
        case 'q': return TOAppSettingsDataTypeInt;
        case 'd': return TOAppSettingsDataTypeDouble;
        case 'f': return TOAppSettingsDataTypeFloat;
        case 'B': return TOAppSettingsDataTypeBool;
        default: break;
    }
    
    // Objects are represented as 'T@"ClassName"', so filter for supported types
    if (propertyType != '@') { return TOAppSettingsDataTypeUnknown; }
    
    // Filter for specific types of objects we support
    if (strncmp(attributes + 3, "NSString", 8) == 0) {
        return TOAppSettingsDataTypeString;
    }
    else if (strncmp(attributes + 3, "NSArray", 7) == 0) {
        return TOAppSettingsDataTypeArray;
    }
    else if (strncmp(attributes + 3, "NSDictionary", 11) == 0) {
        return TOAppSettingsDataTypeDictionary;
    }
    else if (strncmp(attributes + 3, "NSData", 6) == 0) {
        return TOAppSettingsDataTypeData;
    }
    else if (strncmp(attributes + 3, "NSDate", 6) == 0) {
        return TOAppSettingsDataTypeDate;
    }
    
    // Return generic object
    return TOAppSettingsDataTypeObject;
}

static inline BOOL TOAppSettingsIsIgnoredProperty(const char *attributes)
{
    // Read-only classes are represented by a 'R' after the first comma
    if (strncmp(strchr(attributes, ',') + 1, "R", 1) == 0) {
        return YES;
    }
    return NO;
}

static inline char *TOAppSettingsClassNameForPropertyAttributes(const char *attributes)
{
    //Format is either '"'T@\"NSString\"" or '"T@\"<NSCoding>\""'
    if (strlen(attributes) < 2 || attributes[1] != '@') { return NULL; }
    
    // Get the class/protocol name
    const char *start = strstr(attributes, "\"") + 1;
    const char *end = strstr(start, "\"");
    long distance = (end - start);
    
    char *name = malloc(distance);
    strncpy(name, start, distance);
    
    return name;
}

static inline BOOL TOAppSettingsIsCompatibleObjectType(const char *attributes)
{
    char *name = TOAppSettingsClassNameForPropertyAttributes(attributes);
    if (name == NULL) { return NO; }
    
    // Check if it is a generic object that conforms to the coding protocols
    if (strcmp(name, "<NSCoding>") == 0 || strcmp(name, "<NSSecureCoding>") == 0) {
        free(name);
        return YES;
    }
    
    // If it's an object type, see if we can check if it conforms to a protocol we support
    Class class = NSClassFromString([NSString stringWithCString:name encoding:NSUTF8StringEncoding]);
    free(name);
    
    if ([class conformsToProtocol:@protocol(NSCoding)]) {
        return YES;
    }

    return NO;
}

/*
 Checks if class A is a subclass of class B
 */
static inline BOOL TOAppSettingsIsSubclass(Class class1, Class class2) {
    while (class1) {
        class1 = class_getSuperclass(class1);
        if (class1 == class2) { return YES; }
    }
    return NO;
}

#pragma mark - Accessor Implementations -

// Int
static void setIntegerPropertyValue(TOAppSettings *self, SEL _cmd, NSInteger intValue)
{
    [self.userDefaults setInteger:intValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSInteger getIntegerPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults integerForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

// Float
static void setFloatPropertyValue(TOAppSettings *self, SEL _cmd, float floatValue)
{
    [self.userDefaults setFloat:floatValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static float getFloatPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults floatForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Double
static void setDoublePropertyValue(TOAppSettings *self, SEL _cmd, double doubleValue)
{
    [self.userDefaults setDouble:doubleValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static double getDoublePropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults doubleForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Bool
static void setBoolPropertyValue(TOAppSettings *self, SEL _cmd, BOOL boolValue)
{
    [self.userDefaults setBool:boolValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static BOOL getBoolPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults boolForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Date
static void setDatePropertyValue(TOAppSettings *self, SEL _cmd, NSDate *dateValue)
{
    [self.userDefaults setObject:dateValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSDate *getDatePropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//String
static void setStringPropertyValue(TOAppSettings *self, SEL _cmd, NSString *stringValue)
{
    [self.userDefaults setObject:stringValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSString *getStringPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults stringForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Data
static void setDataPropertyValue(TOAppSettings *self, SEL _cmd, NSData *dataValue)
{
    [self.userDefaults setObject:dataValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSData *getDataPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Array
static void setArrayPropertyValue(TOAppSettings *self, SEL _cmd, NSArray *arrayValue)
{
    [self.userDefaults setObject:arrayValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSArray *getArrayPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Dictionary
static void setDictionaryPropertyValue(TOAppSettings *self, SEL _cmd, NSDictionary *dictionaryValue)
{
    [self.userDefaults setObject:dictionaryValue forKey:[self userDefaultsKeyNameForSetterSelector:_cmd]];
}

static NSDictionary *getDictionaryPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Object
static void setObjectPropertyValue(TOAppSettings *self, SEL _cmd, id object)
{
    NSString *key = [self userDefaultsKeyNameForSetterSelector:_cmd];
    NSData *objectData = [NSKeyedArchiver archivedDataWithRootObject:object];
    [self.userDefaults setObject:objectData forKey:key];
    [self setCachedDecodedObject:object forKey:key];
}

static id getObjectPropertyValue(TOAppSettings *self, SEL _cmd)
{
    NSString *key = [self userDefaultsKeyNameForGetterSelector:_cmd];
    id object = [self cachedDecodedObjectForKey:key];
    if (object) { return object; }
    
    NSData *objectData = [self.userDefaults objectForKey:key];
    if (objectData == nil) { return nil; }
    return [NSKeyedUnarchiver unarchiveObjectWithData:objectData];
}

static inline void TOAppSettingsReplaceAccessors(Class class, NSString *name, const char *attributes, TOAppSettingsDataType type)
{
    IMP newGetter = NULL;
    IMP newSetter = NULL;
    
    switch (type) {
        case TOAppSettingsDataTypeInt:
            newGetter = (IMP)getIntegerPropertyValue;
            newSetter = (IMP)setIntegerPropertyValue;
            break;
        case TOAppSettingsDataTypeFloat:
            newGetter = (IMP)getFloatPropertyValue;
            newSetter = (IMP)setFloatPropertyValue;
            break;
        case TOAppSettingsDataTypeDouble:
            newGetter = (IMP)getDoublePropertyValue;
            newSetter = (IMP)setDoublePropertyValue;
            break;
        case TOAppSettingsDataTypeBool:
            newGetter = (IMP)getBoolPropertyValue;
            newSetter = (IMP)setBoolPropertyValue;
            break;
        case TOAppSettingsDataTypeString:
            newGetter = (IMP)getStringPropertyValue;
            newSetter = (IMP)setStringPropertyValue;
            break;
        case TOAppSettingsDataTypeDate:
            newGetter = (IMP)getDatePropertyValue;
            newSetter = (IMP)setDatePropertyValue;
            break;
        case TOAppSettingsDataTypeData:
            newGetter = (IMP)getDataPropertyValue;
            newSetter = (IMP)setDataPropertyValue;
            break;
        case TOAppSettingsDataTypeArray:
            newGetter = (IMP)getArrayPropertyValue;
            newSetter = (IMP)setArrayPropertyValue;
            break;
        case TOAppSettingsDataTypeDictionary:
            newGetter = (IMP)getDictionaryPropertyValue;
            newSetter = (IMP)setDictionaryPropertyValue;
            break;
        case TOAppSettingsDataTypeObject:
            newGetter = (IMP)getObjectPropertyValue;
            newSetter = (IMP)setObjectPropertyValue;
            break;
        default:
            break;
    }
    
    if (newGetter == NULL || newSetter == NULL) { return; }
    
    // Generate synthesized setter method name
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [[name substringToIndex:1] capitalizedString], [name substringFromIndex:1]];
    
    SEL originalGetter = NSSelectorFromString(name);
    SEL originalSetter = NSSelectorFromString(setterName);
    
    // If the class already has that selector, replace it.
    // Otherwise, add as a new method
    if ([class instancesRespondToSelector:originalGetter]) {
        class_replaceMethod(class, originalGetter, newGetter, attributes);
    }
    else {
        class_addMethod(class, originalGetter, newGetter, attributes);
    }
    
    // Repeat for setter
    if ([class instancesRespondToSelector:originalSetter]) {
        class_replaceMethod(class, originalSetter, newSetter, attributes);
    }
    else {
        class_addMethod(class, originalSetter, newSetter, attributes);
    }
}

static inline void TOAppSettingsSwapClassPropertyAccessors(Class class)
{
    // Get a list of all of the ignored properties defined by this subclass
    NSArray *ignoredProperties = [class ignoredProperties];
    
    // Get all properties in this class
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
    
    // Loop through each property
    for (NSInteger i = 0; i < propertyCount; i++) {
        // Get the property from the class
        objc_property_t property = properties[i];
        
        // Check if the property is read-only
        const char *attributes = property_getAttributes(property);
        if (TOAppSettingsIsIgnoredProperty(attributes)) { continue; }
        
        // Get the type of this property
        TOAppSettingsDataType type = TOAppSettingsDataTypeForProperty(attributes);
        if (type == TOAppSettingsDataTypeUnknown) { continue; }
        
        // Get the name and check if it was explicitly ignored
        NSString *name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if (ignoredProperties.count && [ignoredProperties indexOfObject:name] != NSNotFound) { continue; }
        
        // Check if it's an object type we can support
        if (type == TOAppSettingsDataTypeObject &&
            TOAppSettingsIsCompatibleObjectType(attributes) == NO) { continue; }
        
        // Perform the method swap
        TOAppSettingsReplaceAccessors(class, name, attributes, type);
    }
    free(properties);
}

/*
Get a C array of all of the classes visible to this executable.
The array must be manually freed when finished.
*/
static inline Class *TOAppSettingsGetClassList(unsigned int *numClasses)
{
    unsigned int _numClasses = 0;
    Class *_classes = NULL;
    
    // Get the number of classes in the current runtime
    _numClasses = objc_getClassList(NULL, 0);
    if (_numClasses == 0) { return NULL; }
    
    // Allocate enough memory to hold a list of each class
    _classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * _numClasses);
    
    // Copy the class list to our memory
    _numClasses = objc_getClassList(_classes, _numClasses);
    
    // Expose the number of classes found to the external reference
    if (numClasses != NULL) {
        *numClasses = _numClasses;
    }
    
    return _classes;
}

static inline void TOAppSettingsRegisterSubclassProperties()
{
    // Get a list of all classes
    unsigned int numClasses = 0;
    Class *classes = TOAppSettingsGetClassList(&numClasses);
    if (numClasses == 0) { return; }
    
    // Loop through each class and find ones that are subclasses of this one
    for (NSInteger i = 0; i < numClasses; i++) {
        if (TOAppSettingsIsSubclass(classes[i], TOAppSettings.class) == NO) { continue; }
        
        // Perform the internal accessor swizzling
        TOAppSettingsSwapClassPropertyAccessors(classes[i]);
    }
    free(classes);
}

// -----------------------------------------------------------------------

@implementation TOAppSettings

#pragma mark - Singleton Properties -

/** A cache where previously created instances of the same
    settings objects are persisted. */
+ (NSCache *)sharedCache
{
    static NSCache *_cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [[NSCache alloc] init];
    });
    return _cache;
}

/** Manages a dispatch queue that ensures the cache is
    accessed in a thread-safe manner */
+ (dispatch_queue_t)sharedSettingsCacheQueue
{
    static dispatch_queue_t _sharedSettingsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedSettingsQueue = dispatch_queue_create("TOAppSettings.SharedSettingsBarrierQueue",
                                                  DISPATCH_QUEUE_CONCURRENT);
    });
    return _sharedSettingsQueue;
}

#pragma mark - Class Creation -
+ (instancetype)defaultSettings
{
    return [[self class] settingsWithIdentifier:nil suiteName:nil];
}

+ (instancetype)defaultSettingsWithSuiteName:(NSString *)suiteName
{
    return [[self class] settingsWithIdentifier:nil suiteName:suiteName];
}

+ (instancetype)settingsWithIdentifier:(NSString *)identifier
{
    return [[self class] settingsWithIdentifier:identifier suiteName:nil];
}

+ (instancetype)settingsWithIdentifier:(NSString *)identifier suiteName:(NSString *)suiteName
{
    NSString *instanceKeyName = [[self class] instanceKeyNameWithIdentifier:identifier];
    dispatch_queue_t barrierQueue = [TOAppSettings sharedSettingsCacheQueue];
    
    // Retrieve the previous instance from the cache
    __block id settingsObject = nil;
    dispatch_sync(barrierQueue, ^{
        settingsObject = [[TOAppSettings sharedCache] objectForKey:instanceKeyName];
    });
    
    // Return the previous instance
    if (settingsObject) { return settingsObject; }
    
    // Create a new instance and cache it
    settingsObject = [[self alloc] initWithIdentifier:identifier suiteName:suiteName];
    
    // Save the instance to the cache
    dispatch_barrier_async(barrierQueue, ^{
        [[TOAppSettings sharedCache] setObject:settingsObject forKey:instanceKeyName];
    });
    
    return settingsObject;
}

- (instancetype)initWithIdentifier:(nullable NSString *)identifier suiteName:(nullable NSString *)suiteName
{
    if (self = [super init]) {
        _suiteName = suiteName;
        _identifier = identifier;
        
        NSString *queueName = [NSString stringWithFormat:@"%@.DataObjectsCacheQueue", [self class]];
        _dataCacheBarrierQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_CONCURRENT);
        
        [self setUp];
    }
    
    return self;
}

- (void)setUp
{
    // Work out which NSUserDefaults we'll be targetting
    if (self.suiteName) {
        self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.suiteName];
    }
    else {
        self.userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    // Generate the property prefix we'll be
    // using to uniquely identify the properties we manage
    self.propertyKeyPrefix = [[self class] instanceKeyNameWithIdentifier:_identifier];
}

#pragma mark - Runtime Entry -

+ (void)load
{
    @autoreleasepool {
        TOAppSettingsRegisterSubclassProperties();
    }
}

#pragma mark - Subclass Overridable -

+ (nullable NSArray *)ignoredProperties { return nil; }
+ (nullable NSDictionary *)defaultPropertyValues { return nil; }

#pragma mark - Static State Management -
+ (NSString *)instanceKeyNameWithIdentifier:(NSString *)identifier
{
    NSString *className = NSStringFromClass(self.class);
    if (identifier.length == 0) {
        return className;
    }
    
    return [NSString stringWithFormat:@"%@.%@", className, identifier];
}

#pragma mark - Dynamic Accessor Handling -
- (NSString *)userDefaultsKeyNameForGetterSelector:(SEL)selector
{
    NSString *propertyName = NSStringFromSelector(selector);
    //Capitalize only first character
    propertyName = [NSString stringWithFormat:@"%@%@",
                        [propertyName substringToIndex:1].capitalizedString,
                        [propertyName substringFromIndex:1]];
    return [self.propertyKeyPrefix stringByAppendingFormat:@".%@", propertyName];
}

- (NSString *)userDefaultsKeyNameForSetterSelector:(SEL)selector
{
    NSString *propertyName = NSStringFromSelector(selector);
    //Drop the ":" at the end
    propertyName = [propertyName substringToIndex:propertyName.length - 1];
    //Remove the "set" at the beginning
    propertyName = [propertyName substringFromIndex:3];
    
    return [self.propertyKeyPrefix stringByAppendingFormat:@".%@", propertyName];
}

- (id)cachedDecodedObjectForKey:(NSString *)key
{
    if (self.dataPropertyCache == nil) { return nil; }
    __block id object = nil;
    dispatch_sync(_dataCacheBarrierQueue, ^{
        object = [self.dataPropertyCache objectForKey:key];
    });
    return object;
}

- (void)setCachedDecodedObject:(id)object forKey:(NSString *)key
{
    if (self.dataPropertyCache == nil) {
        dispatch_sync(self.dataCacheBarrierQueue, ^{
            self.dataPropertyCache = [NSMapTable strongToWeakObjectsMapTable];
        });
    }
    
    dispatch_barrier_async(self.dataCacheBarrierQueue, ^{
        [self.dataPropertyCache setObject:object forKey:key];
    });
}

@end

