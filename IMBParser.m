/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import "IMBParser.h"
#import "IMBObjectPromise.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBParser

@synthesize mediaSource = _mediaSource;
@synthesize mediaType = _mediaType;
@synthesize custom = _custom;


//----------------------------------------------------------------------------------------------------------------------


// The default implementation just returns a single parser instance. Subclasses like iPhoto, Aperture, or Lightroom
// may opt to return multiple instances (preconfigured with correct mediaSource) if multiple libraries are detected...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	IMBParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
	NSArray* parserInstances = [NSArray arrayWithObject:parser];
	[parser release];
	return parserInstances;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super init])
	{
		self.mediaSource = nil;
		self.mediaType = inMediaType;
		self.custom = NO;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_mediaSource);
	IMBRelease(_mediaType);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// The following two methods must be overridden by subclasses...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	return nil;
}


- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	return NO;
}


// This method can be overridden by subclasses if the default promise is not useful...

- (IMBObjectPromise*) objectPromiseWithObjects:(NSArray*)inObjects
{
	return [[(IMBObjectPromise*)[IMBLocalObjectPromise alloc] initWithObjects:inObjects] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


// Optional methods do nothing in the base class and can be overridden in subclasses, e.g. to update  
// or get rid of cached data...

- (void) willUseParser
{

}


- (void) didDeselectParser
{

}


- (void) watchedPathDidChange:(NSString*)inWatchedPath
{

}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* parserClassName = NSStringFromClass([self class]);
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,inPath];
}


//----------------------------------------------------------------------------------------------------------------------


@end
