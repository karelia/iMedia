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
#import "IMBCommon.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObject

@synthesize value = _value;
@synthesize name = _name;
@synthesize metadata = _metadata;


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.value = [inCoder decodeObjectForKey:@"value"];
		self.name = [inCoder decodeObjectForKey:@"name"];
		self.metadata = [inCoder decodeObjectForKey:@"metadata"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.value forKey:@"value"];
	[inCoder encodeObject:self.name forKey:@"name"];
	[inCoder encodeObject:self.metadata forKey:@"metadata"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObject* copy = [[IMBObject allocWithZone:inZone] init];
	copy.value = self.value;
	copy.name = self.name;
	copy.metadata = self.metadata;
	return copy;
}


- (void) dealloc
{
	IMBRelease(_value);
	IMBRelease(_name);
	IMBRelease(_metadata);
	[super dealloc];
}


// Return a small generic icon for this file. Is the icon cached by NSWorkspace, or should be provide some 
// caching ourself?

- (NSImage*) icon
{
	NSString* path = nil;
	
	if ([_value isKindOfClass:[NSURL class]])
		path = [(NSURL*)_value path];
	else if ([_value isKindOfClass:[NSString class]])
		path = (NSString*)_value;
		
	NSString* extension = [path pathExtension];
	if (extension==nil || [extension length]==0) extension = @"jpg";
	
	return [[NSWorkspace sharedWorkspace] iconForFileType:extension];
}


// Objects are equal if their value (paths or urls) are equal...

- (BOOL) isEqual:(IMBObject*)inObject
{
	return [self.value isEqual:inObject.value];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ name=%@ value=%@ metadata=%p", [super description], self.name, self.value, self.metadata];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBVisualObject

@synthesize imageRepresentation = _imageRepresentation;
@synthesize imageRepresentationType = _imageRepresentationType;
@synthesize imageVersion = _imageVersion;


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.imageRepresentation = [inCoder decodeObjectForKey:@"imageRepresentation"];
		self.imageRepresentationType = [inCoder decodeObjectForKey:@"imageRepresentationType"];
		self.imageVersion = [inCoder decodeIntegerForKey:@"imageVersion"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	[inCoder encodeObject:self.imageRepresentation forKey:@"imageRepresentation"];
	[inCoder encodeObject:self.imageRepresentationType forKey:@"imageRepresentationType"];
	[inCoder encodeInteger:self.imageVersion forKey:@"imageVersion"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBVisualObject* copy = (IMBVisualObject*)[super copyWithZone:inZone];
	copy.imageRepresentation = self.imageRepresentation;
	copy.imageRepresentationType = self.imageRepresentationType;
	copy.imageVersion = self.imageVersion;
	return copy;
}


- (void) dealloc
{
	IMBRelease(_imageRepresentation);
	IMBRelease(_imageRepresentationType);
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ imageRepresentation=%@ imageRepresentationType=%@ imageVersion=%d", [super description], self.imageRepresentation, self.imageRepresentationType, self.imageVersion];
}


// Use the path or URL as the unique identifier...

- (NSString*) imageUID
{
	return _value;
}

// The name of the object will be used as the title in IKIMageBrowserView...

- (NSString*) imageTitle
{
	return _name;
}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Override to show a folder icon instead of a generic file icon...

@implementation IMBNodeObject

@synthesize path = _path;


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.path = [inCoder decodeObjectForKey:@"path"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	[inCoder encodeObject:self.path forKey:@"path"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBNodeObject* copy = (IMBNodeObject*) [super copyWithZone:inZone];
	copy.path = self.path;
	return copy;
}


- (void) dealloc
{
	IMBRelease(_path);
	[super dealloc];
}


- (NSString*) imageUID
{
	return _path;
}


- (NSImage*) icon
{
	return [[NSWorkspace sharedWorkspace] iconForFile:self.path];
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ path=%@", [super description], self.path];
}

@end


//----------------------------------------------------------------------------------------------------------------------
