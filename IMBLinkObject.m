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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLinkObject.h"
#import "NSWorkspace+iMedia.h"
#import "IMBSmartFolderObject.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLinkObject


// Return a small generic icon for this file. Is the icon cached by NSWorkspace, or should be provide some 
// caching ourself?

- (NSImage*) icon
{
	static NSImage *sJavaScriptIcon = nil;
	static NSImage *sURLIcon = nil;
	
	if (!sJavaScriptIcon)
	{
		NSBundle* ourBundle = [NSBundle bundleForClass:[self class]];
		NSString* pathToImage = [ourBundle pathForResource:@"js" ofType:@"tiff"];
		sJavaScriptIcon = [[NSImage alloc] initWithContentsOfFile:pathToImage];
		
		pathToImage = [ourBundle pathForResource:@"url_icon" ofType:@"tiff"];
		sURLIcon = [[NSImage alloc] initWithContentsOfFile:pathToImage];
	}

	NSImage *result = nil;
	if (IKImageBrowserNSImageRepresentationType == self.imageRepresentationType)
	{
		result = self.imageRepresentation;
	}
	else
	{
		if ([[[self location] description] hasPrefix:@"javascript:"])	// special icon for JavaScript bookmarklets
		{
			result = sJavaScriptIcon;
		}
		else if ([[[self location] description] hasPrefix:@"place:"])	// special icon for Firefox bookmarklets, so they match look
		{
			result = [IMBSmartFolderObject icon];
		}
		else if ([self isLocalFile])
		{
			NSString *type = [self type];
			result = [[NSWorkspace imb_threadSafeWorkspace] iconForFileType:type];
		}
		else
		{
			result = sURLIcon;
			// WebIconDatabase is not app-store friendly, and it doesn't actually work!
//			result = [[WebIconDatabase sharedIconDatabase] 
//					iconForURL:[self.URL absoluteString]
//					withSize:NSMakeSize(16,16)
//					cache:YES];	// Strangely, cache isn't even used in the webkit implementation
			
			/*
			 We are never getting anything other than the default globe for remote URLs.
			 We know that iconForURL: is getting past the enabled check becuase it does return a file URL.
			 So either iconForPageURL or webGetNSImage is failing in this source code of webkit.
			 
			 if (Image* image = iconDatabase()->iconForPageURL(URL, IntSize(size)))
				if (NSImage *icon = webGetNSImage(image, size))
					return icon;
			*/
			
			// NSLog(@"%p icon for %@", result, [self.URL absoluteString]);
		}
	}
	return result;
}


//----------------------------------------------------------------------------------------------------------------------


// Simply override these two methods to do nothing...

- (void) loadThumbnail
{

}

- (void) loadMetadata
{

}


//----------------------------------------------------------------------------------------------------------------------


// Short circuit this method by calling the completion immediately...

- (void) requestBookmarkWithCompletionBlock:(void(^)(NSError*))inCompletionBlock
{
	inCompletionBlock(nil);
}


// Simply return our URL...

- (NSURL*) URLByResolvingBookmark
{
	return self.URL;
}


//----------------------------------------------------------------------------------------------------------------------


// Quicklook is not supported for links...

- (NSURL*) previewItemURL
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
