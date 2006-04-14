
#import <Cocoa/Cocoa.h>

@interface NSPasteboard ( iMedia )

+ (NSArray *)fileAndURLTypes;
+ (NSArray *)URLTypes;

- (void) writeURLs:(NSArray *)urls files:(NSArray *)files names:(NSArray *)names;

@end
