/*
 iMedia Browser <http://kareia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window,Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
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
