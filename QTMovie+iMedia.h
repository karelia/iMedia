#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface QTMovie ( iMedia )

- (NSImage *)betterPosterImage;
- (BOOL) isDRMProtected;
// get access to the mp3 meta data
- (NSString *)attributeWithFourCharCode:(OSType)code;

-(BOOL)isPlaying;
-(NSString *)durationAsString;
-(NSString *)currentPlayTimeAsString;
- (long long)durationInSeconds;
-(QTTime)currentPlayTime;
-(double)currentTimeValue;
-(void)timeToQTTime:(long)timeValue resultTime:(QTTime *)aQTTime;
-(void)setTime:(int)timeValue;
-(BOOL)currentTimeEqualsDuration;
-(NSImage *)posterImage;
-(NSString *)movieFileName;
-(NSString *)movieFilePath;
- (NSString *)filenameFromFullPath:(NSString *)fullPath;

@end
