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


// Author: Peter Baumgartner, Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBNodeObject.h"
#import "IMBNode.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBNodeObject

@synthesize representedNodeIdentifier = _representedNodeIdentifier;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		// IMBNodeObject are represented in the user interface as folder icons. Since these are prerendered  
		// and do not have a rectangular shape, we do not want to draw a border and shadow around it...

		self.shouldDrawAdornments = NO;
		self.shouldDisableTitle = NO;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_representedNodeIdentifier);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
		self.representedNodeIdentifier = [inCoder decodeObjectForKey:@"representedNodeIdentifier"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	[inCoder encodeObject:self.representedNodeIdentifier forKey:@"representedNodeIdentifier"];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBNodeObject* copy = [super copyWithZone:inZone];
	copy.representedNodeIdentifier = self.representedNodeIdentifier;
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


// Buttons are not selectable or draggable...

- (BOOL) isSelectable 
{
	return NO;
}


- (BOOL) isDraggable
{
	return NO;
}


- (IMBResourceAccessibility) accessibility
{
	return kIMBResourceIsAccessible;
}


//----------------------------------------------------------------------------------------------------------------------


// Since a string is required here we return the identifier of a node instead for the node itself...

- (NSString*) imageUID
{
	NSString* imageUID = [super imageUID];
	
	if (imageUID)
	{
		return imageUID;
	}
	
	return [self representedNodeIdentifier];
}


// Override to show a folder icon ALWAYS instead of a generic file icon...

- (NSString*) imageRepresentationType
{
	return IKImageBrowserNSImageRepresentationType;
}


- (NSImage *) sharedImageRepresentation
{
	return nil;
}


- (id) imageRepresentation
{
    NSImage *imageRep;
    
    if ((imageRep = [self sharedImageRepresentation]))
    {
        return imageRep;
    }
    
	return [super imageRepresentation];
}


- (NSImage*) icon
{
	return [NSImage imb_sharedGenericFolderIcon];
}


//----------------------------------------------------------------------------------------------------------------------

@end
