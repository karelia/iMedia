#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface QTMovie ( iMedia )

- (NSImage *)betterPosterImage;
- (BOOL) isDRMProtected;
// get access to the mp3 meta data
- (NSString *)attributeWithFourCharCode:(OSType)code;

@end
