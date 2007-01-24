/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface QTMovie ( iMedia )

- (NSImage *)betterPosterImage;
- (NSImage *)betterPosterImageWithMaxSize:(NSSize)maxSize;  // Shrinks the image if it's larger than maxSize

- (BOOL) isDRMProtected;
// get access to the mp3 meta data
- (NSString *)attributeWithFourCharCode:(OSType)code;

- (BOOL)isPlaying;
- (NSString *)durationAsString;
- (NSString *)currentTimeAsString;
- (float)durationInSeconds;
- (void)timeToQTTime:(long)timeValue resultTime:(QTTime *)aQTTime;
- (void)setTime:(int)timeValue;
- (BOOL)currentTimeEqualsDuration;
- (NSString *)movieFileName;
- (NSString *)movieFilePath;
- (NSString *)filenameFromFullPath:(NSString *)fullPath;

@end
