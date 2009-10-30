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

#import "IMBObject.h"
#import "IMBParser.h"
#import "IMBCommon.h"
#import "IMBOperationQueue.h"
#import "IMBObjectThumbnailLoadOperation.h"
#import "IMBObjectFifoCache.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define MAX_THUMBNAIL_SIZE 128


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObject

@synthesize location = _location;
@synthesize name = _name;
@synthesize metadata = _metadata;
@synthesize metadataDescription = _metadataDescription;
@synthesize parser = _parser;
@synthesize index = _index;

@synthesize imageLocation = _imageLocation;
@synthesize imageRepresentation = _imageRepresentation;
@synthesize imageRepresentationType = _imageRepresentationType;
@synthesize imageVersion = _imageVersion;
@synthesize isLoading = _isLoading;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		self.index = NSNotFound;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.location = [inCoder decodeObjectForKey:@"location"];
		self.name = [inCoder decodeObjectForKey:@"name"];
		self.metadata = [inCoder decodeObjectForKey:@"metadata"];
		self.metadataDescription = [inCoder decodeObjectForKey:@"metadataDescription"];
		self.index = [inCoder decodeIntegerForKey:@"index"];
//		self.imageLocation = [inCoder decodeObjectForKey:@"imageLocation"];
//		self.imageRepresentation = [inCoder decodeObjectForKey:@"imageRepresentation"];
//		self.imageRepresentationType = [inCoder decodeObjectForKey:@"imageRepresentationType"];
//		self.imageVersion = [inCoder decodeIntegerForKey:@"imageVersion"];

//		self.parser = [inCoder decodeObjectForKey:@"parser"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.location forKey:@"location"];
	[inCoder encodeObject:self.name forKey:@"name"];
	[inCoder encodeObject:self.metadata forKey:@"metadata"];
	[inCoder encodeObject:self.metadataDescription forKey:@"metadataDescription"];
	[inCoder encodeInteger:self.index forKey:@"index"];
//	[inCoder encodeObject:self.imageLocation forKey:@"imageLocation"];
//	[inCoder encodeObject:self.imageRepresentation forKey:@"imageRepresentation"];
//	[inCoder encodeObject:self.imageRepresentationType forKey:@"imageRepresentationType"];
//	[inCoder encodeInteger:self.imageVersion forKey:@"imageVersion"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObject* copy = [[IMBObject allocWithZone:inZone] init];
	
	copy.location = self.location;
	copy.name = self.name;
	copy.metadata = self.metadata;
	copy.metadataDescription = self.metadataDescription;
	copy.index = self.index;
	copy.imageLocation = self.imageLocation;
	copy.imageRepresentation = self.imageRepresentation;
	copy.imageRepresentationType = self.imageRepresentationType;
	copy.imageVersion = self.imageVersion;
	
	return copy;
}


- (void) dealloc
{
	IMBRelease(_location);
	IMBRelease(_name);
	IMBRelease(_metadata);
	IMBRelease(_metadataDescription);
	IMBRelease(_parser);
	IMBRelease(_imageLocation);
	IMBRelease(_imageRepresentation);
	IMBRelease(_imageRepresentationType);

	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IKImageBrowserItem Protocol


// Use the path or URL as the unique identifier...

- (NSString*) imageUID
{
	return _location;
}


// The name of the object will be used as the title in IKIMageBrowserView...

- (NSString*) imageTitle
{
	return _name;
}


// When this method is called we assume that the object is about to be displayed. So this could be a 
// possible hook for lazily loading thumbnail and metadata...

- (id) imageRepresentation
{
	if (_imageRepresentation == nil)
	{
		[self load];
	}
	
	return [[_imageRepresentation retain] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Asynchronous Loading


// If the image representation isn't available yet, then trigger an asynchronous loading operation...

- (void) load
{
	if (_imageRepresentation==nil && _isLoading==NO)
	{
		self.isLoading = YES;
		
		IMBObjectThumbnailLoadOperation* operation = [[IMBObjectThumbnailLoadOperation alloc] initWithObject:self];
		[[IMBOperationQueue sharedQueue] addOperation:operation];			
	}
}


// Store the imageRepresentation and add this object to the fifo cache. Older objects get bumped out of the   
// cache and are thus unloaded...

- (void) setImageRepresentation:(id)inImageRepresentation
{
	id old = _imageRepresentation;
	_imageRepresentation = [inImageRepresentation retain];
	[old release];
	
	self.imageVersion = _imageVersion + 1;
	self.isLoading = NO;
	
	if (inImageRepresentation)
	{
		[IMBObjectFifoCache addObject:self];
//		NSUInteger n = [IMBObjectFifoCache count];
//		NSLog(@"%s = %p (%d)",__FUNCTION__,inImageRepresentation,(int)n);
	}
}


// Unload the imageRepresentation to save some memory...

- (void) unload
{
   self.imageRepresentation = nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


// Objects are equal if their locations (paths or urls) are equal...

- (BOOL) isEqual:(IMBObject*)inObject
{
	return [self.location isEqual:inObject.location];
}


//----------------------------------------------------------------------------------------------------------------------


// Convert location to path...

- (NSString*) path
{
	NSString* path = nil;
	
	if ([_location isKindOfClass:[NSURL class]])
	{
		path = [(NSURL*)_location path];
	}
	else if ([_location isKindOfClass:[NSString class]])
	{
		path = (NSString*)_location;
	}
	
	return path;
}


// Convert location to url...

- (NSURL*) url
{
	NSURL* url = nil;
	
	if ([_location isKindOfClass:[NSURL class]])
	{
		url = (NSURL*)_location;
	}
	else if ([_location isKindOfClass:[NSString class]])
	{
		url = [NSURL fileURLWithPath:(NSString*)_location];
	}
	
	return url;
}


//----------------------------------------------------------------------------------------------------------------------


// Return a small generic icon for this file. Is the icon cached by NSWorkspace, or should be provide some 
// caching ourself?

- (NSImage*) icon
{
	NSString* path = [self path];
	NSString* extension = [path pathExtension];
	if (extension==nil || [extension length]==0) extension = @"jpg";
	
	return [[NSWorkspace sharedWorkspace] iconForFileType:extension];
}


//----------------------------------------------------------------------------------------------------------------------


- (NSString*) description
{
	return [NSString stringWithFormat:@"IMBObject\n\tlocation = %@\n\tname = %@\n\tmetadata = %p", 
	
		self.location, 
		self.name, 
		self.metadata];
}


//----------------------------------------------------------------------------------------------------------------------


@end
