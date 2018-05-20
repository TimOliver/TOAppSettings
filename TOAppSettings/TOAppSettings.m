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
    TOAppSettingsDataTypeLong,
    TOAppSettingsDataTypeFloat,
    TOAppSettingsDataTypeDouble,
    TOAppSettingsDataTypeBool,
    TOAppSettingsDataTypeString,
    TOAppSettingsDataTypeArray,
    TOAppSettingsDataTypeDictionary,
    TOAppSettingsDataTypeObject
};

// ---

static inline TOAppSettingsDataType TOAppSettingsDataTypeForPropertyAttributes(const char *attributes)
{
    if (!attributes || strlen(attributes) == 0) { return TOAppSettingsDataTypeUnknown; }
    
    // Basic types are represented by a single character, following the initial "T" marker
    char propertyType = attributes[1];
    
    switch (propertyType) {
        case 'i': return TOAppSettingsDataTypeInt;
        case 'd': return TOAppSettingsDataTypeDouble;
        case 'l': return TOAppSettingsDataTypeLong;
        case 'f': return TOAppSettingsDataTypeFloat;
        case 'B': return TOAppSettingsDataTypeBool;
        default: break;
    }
    
    // Objects are represented as 'T@"ClassName"', so filter for supported types
    if (propertyType != '@') { return TOAppSettingsDataTypeUnknown; }
    
    if (strncmp(attributes + 3, "NSString", 8) == 0) {
        return TOAppSettingsDataTypeString;
    }
    else if (strncmp(attributes + 3, "NSArray", 7) == 0) {
        return TOAppSettingsDataTypeArray;
    }
    else if (strncmp(attributes + 3, "NSDictionary", 11) == 0) {
        return TOAppSettingsDataTypeDictionary;
    }
    
    return TOAppSettingsDataTypeObject;
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

static inline void TOAppSettingsSwapClassPropertyAccessors(Class class)
{
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
    for(NSInteger i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        const char *attributes = property_getAttributes(property);
        
        printf("%s %s %li\n", name, attributes, (long)TOAppSettingsDataTypeForPropertyAttributes(attributes));
    }
    free(properties);
}

// -----------------------------------------------------------------------

@implementation TOAppSettings

+ (void)load
{
    [[self class] registerSubclasses];
}

+ (void)registerSubclasses
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

@end

