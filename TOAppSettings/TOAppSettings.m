//
//  TOAppSettings.m
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

/** Works out the `NSUserDefaults` key name based off the setter/getter method names */
- (NSString *)userDefaultsKeyNameForGetterSelector:(SEL)selector;
- (NSString *)userDefaultsKeyNameForSetterSelector:(SEL)selector;

/** Works out the property name from the name of the setter selector */
- (NSString *)propertyNameForSetterSelector:(SEL)selector;
- (NSString *)userDefaultsKeyNameForPropertyName:(NSString *)propertyName;

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
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setInteger:intValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static NSInteger getIntegerPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults integerForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

// Float
static void setFloatPropertyValue(TOAppSettings *self, SEL _cmd, float floatValue)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setFloat:floatValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static float getFloatPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults floatForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Double
static void setDoublePropertyValue(TOAppSettings *self, SEL _cmd, double doubleValue)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setDouble:doubleValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static double getDoublePropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults doubleForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Bool
static void setBoolPropertyValue(TOAppSettings *self, SEL _cmd, BOOL boolValue)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setBool:boolValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static BOOL getBoolPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults boolForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//String
static void setStringPropertyValue(TOAppSettings *self, SEL _cmd, NSString *stringValue)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setObject:stringValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static NSString *getStringPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults stringForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Dictionary
static void setObjectPropertyValue(TOAppSettings *self, SEL _cmd, id objectValue)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    [self willChangeValueForKey:propertyName];
    [self.userDefaults setObject:objectValue forKey:[self userDefaultsKeyNameForPropertyName:propertyName]];
    [self didChangeValueForKey:propertyName];
}

static id getObjectPropertyValue(TOAppSettings *self, SEL _cmd)
{
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForGetterSelector:_cmd]];
}

//Object
static void setArchivableObjectPropertyValue(TOAppSettings *self, SEL _cmd, id object)
{
    NSString *propertyName = [self propertyNameForSetterSelector:_cmd];
    NSString *key = [self userDefaultsKeyNameForPropertyName:propertyName];
    [self willChangeValueForKey:propertyName];
    NSData *objectData = [NSKeyedArchiver archivedDataWithRootObject:object];
    [self.userDefaults setObject:objectData forKey:key];
    [self didChangeValueForKey:propertyName];
    [self setCachedDecodedObject:object forKey:key];
}

static id getArchivableObjectPropertyValue(TOAppSettings *self, SEL _cmd)
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
            newGetter = (IMP)getObjectPropertyValue;
            newSetter = (IMP)setObjectPropertyValue;
            break;
        case TOAppSettingsDataTypeData:
            newGetter = (IMP)getObjectPropertyValue;
            newSetter = (IMP)setObjectPropertyValue;
            break;
        case TOAppSettingsDataTypeArray:
            newGetter = (IMP)getObjectPropertyValue;
            newSetter = (IMP)setObjectPropertyValue;
            break;
        case TOAppSettingsDataTypeDictionary:
            newGetter = (IMP)getObjectPropertyValue;
            newSetter = (IMP)setObjectPropertyValue;
            break;
        case TOAppSettingsDataTypeObject:
            newGetter = (IMP)getArchivableObjectPropertyValue;
            newSetter = (IMP)setArchivableObjectPropertyValue;
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
    settingsObject = [[self.class alloc] initWithIdentifier:identifier suiteName:suiteName];
    
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
    
    // If this is the first time of execution, pre-populate NSUserDefaults with any
    // desired default properties.
    [self registerDefaultSettings];
}

- (void)registerDefaultSettings
{
    // Check if we have any default settings to apply
    NSDictionary *defaultSettings = [[self class] defaultPropertyValues];
    if (defaultSettings.allKeys.count == 0) { return; }
    
    // Check if there are any keys with our prefix already present (If there are, we've already done this)
    NSString *keyPrefix = self.propertyKeyPrefix;
    NSArray *keys = [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys;
    for (NSString *key in keys) {
        if ([key hasPrefix:keyPrefix]) { return; }
    }
    
    // Register each setting
    for (NSString *key in defaultSettings.allKeys) {
        [self setValue:defaultSettings[key] forKey:key];
    }
}

#pragma mark - KVC Compliance -

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self valueForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key
{
    [self setValue:obj forKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    // If it's a property we don't manage, defer to the super class
    if ([self isIgnoredProperty:key]) {
        [super setValue:value forKey:key];
        return;
    }
    
    // Work out what type of object this is from the schema
    TOAppSettingsDataType type = [self typeForPropertyWithName:key];
    if (type == TOAppSettingsDataTypeUnknown) {
        [super setValue:value forKey:key];
        return;
    }
    
    NSString *userDefaultsKey = [self userDefaultsKeyNameForPropertyName:key];
    
    // Inform KVO the property is changing
    [self willChangeValueForKey:key];
    
    // If an archivable object, encode it and cache it
    if (type == TOAppSettingsDataTypeObject) {
        NSData *objectData = [NSKeyedArchiver archivedDataWithRootObject:value];
        [self.userDefaults setObject:objectData forKey:userDefaultsKey];
        [self setCachedDecodedObject:value forKey:userDefaultsKey];
    }
    else {
        [self.userDefaults setObject:value forKey:userDefaultsKey];
    }
    
    // Inform KVO the key has changed
    [self didChangeValueForKey:key];
}

- (id)valueForKey:(NSString *)key
{
    if ([self isIgnoredProperty:key]) {
        return [super valueForKey:key];
    }
    
    // Work out what type of object this is from the schema
    TOAppSettingsDataType type = [self typeForPropertyWithName:key];
    if (type == TOAppSettingsDataTypeUnknown) {
        return [super valueForKey:key];
    }
    
    // If an archived object, forward it to the getter function
    if (type == TOAppSettingsDataTypeObject) {
        return getArchivableObjectPropertyValue(self, @selector(key));
    }
    
    // Otherwise, get the value straight from NSUserDefaults
    return [self.userDefaults objectForKey:[self userDefaultsKeyNameForPropertyName:key]];
}

- (BOOL)isIgnoredProperty:(NSString *)property
{
    NSArray *ignoredProperties = [[self class] ignoredProperties];
    return (ignoredProperties.count && [ignoredProperties indexOfObject:property] != NSNotFound);
}

- (TOAppSettingsDataType)typeForPropertyWithName:(NSString *)propertyName
{
    objc_property_t property = class_getProperty([self class], propertyName.UTF8String);
    if (property == NULL) { return TOAppSettingsDataTypeUnknown; }
    
    return TOAppSettingsDataTypeForProperty(property_getAttributes(property));
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
    
    // Swift classes namespace their names with the product name.
    // That's not necessary here, so strip it out
    NSRange range = [className rangeOfString:@"."];
    if (range.location != NSNotFound) {
        className = [className substringFromIndex:range.location + 1];
    }

    // If this instance doesn't have an identifier, just return the class name
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

- (NSString *)propertyNameForSetterSelector:(SEL)selector
{
    NSString *propertyName = NSStringFromSelector(selector);
    //Drop the ":" at the end
    propertyName = [propertyName substringToIndex:propertyName.length - 1];
    //Remove the "set" at the beginning
    propertyName = [propertyName substringFromIndex:3];
    //Make the first letter lowercase
    propertyName = [NSString stringWithFormat:@"%@%@",
                    [propertyName substringToIndex:1].lowercaseString,
                    [propertyName substringFromIndex:1]];
    
    return propertyName;
}

- (NSString *)userDefaultsKeyNameForPropertyName:(NSString *)propertyName
{
    // Capitalize first letter
    propertyName = [NSString stringWithFormat:@"%@%@",
                    [propertyName substringToIndex:1].capitalizedString,
                    [propertyName substringFromIndex:1]];
    return [self.propertyKeyPrefix stringByAppendingFormat:@".%@", propertyName];
}

#pragma mark - NSCoder Decoded Object Caching -

- (id)cachedDecodedObjectForKey:(NSString *)key
{
    __block id object = nil;
    dispatch_sync(_dataCacheBarrierQueue, ^{
        object = [self.dataPropertyCache objectForKey:key];
    });
    return object;
}

- (void)setCachedDecodedObject:(id)object forKey:(NSString *)key
{
    dispatch_barrier_async(self.dataCacheBarrierQueue, ^{
        if (self.dataPropertyCache == nil) {
            self.dataPropertyCache = [NSMapTable strongToWeakObjectsMapTable];
        }
        [self.dataPropertyCache setObject:object forKey:key];
    });
}

@end
