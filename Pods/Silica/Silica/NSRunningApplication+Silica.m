//
//  NSRunningApplication+Manageable.m
//  Silica
//

#import "NSRunningApplication+Silica.h"

@implementation NSRunningApplication (Silica)

- (BOOL)isAgent {
    NSURL *bundleInfoPath = [[self.bundleURL URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];
    NSDictionary *applicationBundleInfoDictionary = [NSDictionary dictionaryWithContentsOfURL:bundleInfoPath];
    return [applicationBundleInfoDictionary[@"LSUIElement"] boolValue];
}

@end
