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

#import "AppDelegate.h"
#import <iMediaBrowser/iMedia.h>

// see http://www.codecomments.com/message755849.html

extern void QTSetProcessProperty(UInt32 type, UInt32 creator, size_t size, uint8_t *data);

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	char *fairplay = "FairPlay";
	QTSetProcessProperty('dmmc', 'play', strlen(fairplay), (uint8_t *)fairplay);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//[iMediaBrowser sharedBrowserWithDelegate:self supportingBrowserTypes:[NSArray arrayWithObject:@"iMBMusicController"]];
	[[iMediaBrowser sharedBrowserWithDelegate:self] showWindow:self];
}

- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willLoadBrowser:(NSString *)browserClassname
{
	// NSLog(@"loading %@", browserClassname);
	return YES;
}

@end

@interface iMBApplication : NSApplication
{
	
}
@end

// This can be implemented by the application's subclass as a class or instance method, or the app delegate as an instance method.

@implementation iMBApplication
+ (NSString *)applicationIdentifier
{
	return @"com.test";
}
@end

