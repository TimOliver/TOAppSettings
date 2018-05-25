//
//  TOAppSettings.m
//  TOAppSettingsExample
//
//  Created by Tim Oliver on 7/5/18.
//  Copyright © 2018 Tim Oliver. All rights reserved.
//

#import "TOAppSettings.h"
#import "TOAppSettingsProperty.h"

#import <objc/runtime.h>

// ---

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

static inline BOOL TOAppSettingsIsCompatibleObjectType(const char *attributes)
{
    //Format is either '"'T@\"NSString\"" or '"T@\"<NSCoding>\""'
    if (strlen(attributes) < 2 || attributes[1] != '@') { return NO; }
    
    // Get the class/protocol name
    const char *start = strstr(attributes, "\"") + 1;
    const char *end = strstr(start, "\"");
    long distance = (end - start);
    
    char *name = malloc(distance);
    strncpy(name, start, distance);
    
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
static void setIntegerPropertyValue(id self, SEL _cmd, NSInteger intValue) {  }
static NSInteger getIntegerPropertyValue(id self, SEL _cmd) { return 1; }

// Float
static void setFloatPropertyValue(id self, SEL _cmd, float floatValue) { }
static float getFloatPropertyValue(id self, SEL _cmd) { return 1.0f; }

//Double
static void setDoublePropertyValue(id self, SEL _cmd, double doubleValue) { }
static double getDoublePropertyValue(id self, SEL _cmd) { return 1.0f; }

//Bool
static void setBoolPropertyValue(id self, SEL _cmd, BOOL boolValue) { }
static BOOL getBoolPropertyValue(id self, SEL _cmd) { return NO; }

//String
static void setStringPropertyValue(id self, SEL _cmd, NSString *stringValue) { }
static NSString *getStringPropertyValue(id self, SEL _cmd) { return @""; }

//Array
static void setArrayPropertyValue(id self, SEL _cmd, NSArray *arrayValue) { }
static NSArray *getArrayPropertyValue(id self, SEL _cmd) { return nil; }

//Dictionary
static void setDictionaryPropertyValue(id self, SEL _cmd, NSDictionary *dictionarrValue) { }
static NSDictionary *getDictionaryPropertyValue(id self, SEL _cmd) { return nil; }

//Object
static void setObjectPropertyValue(id self, SEL _cmd, id object)
{
    
}

static id getObjectPropertyValue(id self, SEL _cmd)
{
    return nil;
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
    
    class_replaceMethod(class, originalGetter, newGetter, attributes);
    class_replaceMethod(class, originalSetter, newSetter, attributes);
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
        if (TOAppSettingsIsCompatibleObjectType(attributes) == NO) { continue; }
        
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

#pragma mark - Class Entry -

+ (void)load
{
    @autoreleasepool {
        TOAppSettingsRegisterSubclassProperties();
    }
}

+ (NSMutableDictionary *)sharedSchema
{
    static dispatch_once_t onceToken;
    static NSMutableDictionary *_schema;
    dispatch_once(&onceToken, ^{
        _schema = [NSMutableDictionary dictionary];
    });
    return _schema;
}

#pragma mark - Subclass Overridable -

+ (nullable NSArray *)ignoredProperties { return nil; }
+ (nullable NSDictionary *)defaultPropertyValues { return nil; }

@end

