#import <Cocoa/Cocoa.h>

@interface NSObject ( NSString_UTI )

+ (NSString *)UTIForFileType:(NSString *)aFileType;
+ (NSString *)UTIForFilenameExtension:(NSString *)anExtension;
+ (NSString *)UTIForFileAtPath:(NSString *)anAbsolutePath;
+ (BOOL) UTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI;

@end
