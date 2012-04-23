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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroomObject.h"
#import "IMBParserMessenger.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroomObject

@synthesize absolutePyramidPath = _absolutePyramidPath;
@synthesize idLocal = _idLocal;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		_absolutePyramidPath = nil;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_absolutePyramidPath);
	IMBRelease(_idLocal);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]) != nil)
	{
		self.absolutePyramidPath = [inCoder decodeObjectForKey:@"absolutePyramidPath"];
		self.idLocal = [inCoder decodeObjectForKey:@"idLocal"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	
	[inCoder encodeObject:self.absolutePyramidPath forKey:@"absolutePyramidPath"];
	[inCoder encodeObject:self.idLocal forKey:@"idLocal"];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBLightroomObject* copy = [super copyWithZone:inZone];
	copy.absolutePyramidPath = self.absolutePyramidPath;
	copy.idLocal = self.idLocal;
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserItem Protocol


// Use the path to the pyramid file as the unique identifier...

- (NSString*) identifier
{
	/*
	NSString* absolutePyramidPath = self.absolutePyramidPath;
	
	if (absolutePyramidPath != nil) {
		NSString* parserName = [[self.parserMessenger class] parserClassName];
	
		return [NSString stringWithFormat:@"%@:/%@", parserName, absolutePyramidPath];
	}
	
	return [super identifier];
	*/
	
	NSString* identifier = [super identifier];
	
	// Account for virtual copies
	return [NSString stringWithFormat:@"%@/%@", identifier, self.idLocal];
}

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QLPreviewItem Protocol 


// Request the URL to our processed preview data. Since this is an asynchronous operation, but we have to return
// synchronously for this protocol method, we'll wrap the calls in a dispatch_sync to a background queue, and 
// there we wait until we get the bookmark...

- (NSURL*) previewItemURL
{
	if (self.bookmark == nil)
	{
		if (!_isLoadingQuicklookPreview)
		{
			NSLock *lock = [[NSLock alloc] init];
			
			_isLoadingQuicklookPreview = YES;
			 
			dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0),^()
			{
				[lock lock];
				
				[self requestBookmarkWithCompletionBlock:^(NSError* inError)
				{
					[lock unlock];
					
					if (inError) [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:inError waitUntilDone:NO];
				}];
			});
			
			[lock lock];
			[lock release];
			
			_isLoadingQuicklookPreview = NO;
		}
	}
	
	return [self URLByResolvingBookmark];
}


//----------------------------------------------------------------------------------------------------------------------


@end


