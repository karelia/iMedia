#import <Cocoa/Cocoa.h>


@interface NSWorkspace (iMediaExtensions)

- (NSImage *)iconForAppWithBundleIdentifier:(NSString *)bundleID;

@end
