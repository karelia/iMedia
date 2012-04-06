/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.

	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBSmartFolderObject.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBSmartFolderObject


//----------------------------------------------------------------------------------------------------------------------


// Usable from other places for a smart folder...

+ (NSImage*) icon		
{
	static NSImage* sSmartFolderImage = nil;
	static dispatch_once_t sOnceToken = 0;

	dispatch_once(&sOnceToken, ^()
	{
		// Get high-resolution version of smart folder icon directly from CoreTypes
		
		NSBundle* coreTypes = [NSBundle	bundleWithPath:@"/System/Library/CoreServices/CoreTypes.bundle"];
		
		if (coreTypes)
		{
			NSString* smartPath = [coreTypes pathForResource:@"SmartFolderIcon.icns" ofType:nil];
			
			if (smartPath)
			{
				sSmartFolderImage = [[NSImage alloc] initWithContentsOfFile:smartPath];
			}
		}
		
		// Fall-back low-resolution version :-(
		
		if (sSmartFolderImage == nil)
		{
			sSmartFolderImage = [[NSImage imageNamed:NSImageNameFolderSmart] retain];	
		}
	});

	return sSmartFolderImage;
}


//----------------------------------------------------------------------------------------------------------------------


// Override to ALWAYS show a smart folder icon...

- (NSString*) imageRepresentationType
{
	return IKImageBrowserNSImageRepresentationType;
}


- (id) imageRepresentation
{
	return [IMBSmartFolderObject icon];
}


- (NSImage*) icon
{
	static NSImage* sIcon = nil;
	static dispatch_once_t sOnceToken = 0;

	dispatch_once(&sOnceToken, ^()
	{
		sIcon = [[IMBSmartFolderObject icon] copy];
		[sIcon setSize:NSMakeSize(16.0,16.0)];
	});
	
	return sIcon;
}


//----------------------------------------------------------------------------------------------------------------------


@end
