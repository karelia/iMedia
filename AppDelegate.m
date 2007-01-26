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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>  

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

#ifdef DEBUG

/*!	Override debugDescription so it's easier to use the debugger.  Not compiled for non-debug versions.
*/
@implementation NSDictionary ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSArray ( OverrideDebug )

- (NSString *)debugDescription
{
	if ([self count] > 20)
	{
		NSArray *subArray = [self subarrayWithRange:NSMakeRange(0,20)];
		return [NSString stringWithFormat:@"%@ [... %d items]", [subArray description], [self count]];
	}
	else
	{
		return [self description];
	}
}

@end

@implementation NSSet ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSData ( description )

- (NSString *)description
{
	unsigned char *bytes = (unsigned char *)[self bytes];
	unsigned length = [self length];
	NSMutableString *buf = [NSMutableString stringWithFormat:@"NSData %d bytes:\n", length];
	int i, j;
	
	for ( i = 0 ; i < length ; i += 16 )
	{
		if (i > 1024)		// don't print too much!
		{
			[buf appendString:@"\n...\n"];
			break;
		}
		for ( j = 0 ; j < 16 ; j++ )
		{
			int offset = i+j;
			if (offset < length)
			{
				[buf appendFormat:@"%02X ",bytes[offset]];
			}
			else
			{
				[buf appendFormat:@"   "];
			}
		}
		[buf appendString:@"| "];
		for ( j = 0 ; j < 16 ; j++ )
		{
			int offset = i+j;
			if (offset < length)
			{
				unsigned char theChar = bytes[offset];
				if (theChar < 32 || theChar > 127)
				{
					theChar ='.';
				}
				[buf appendFormat:@"%c", theChar];
			}
		}
		[buf appendString:@"\n"];
	}
	[buf deleteCharactersInRange:NSMakeRange([buf length]-1, 1)];
	return buf;
}

@end

#endif
