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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBButtonObject.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBButtonObject

@synthesize representedObject = _representedObject;
@synthesize target = _target;
@synthesize clickAction = _clickAction;
@synthesize doubleClickAction = _doubleClickAction;
@synthesize normalImage = _normalImage;
@synthesize highlightedImage = _highlightedImage;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_representedObject = nil;
		_target = nil;
		_clickAction = NULL;
		_doubleClickAction = NULL;
		_normalImage = nil;
		_highlightedImage = nil;

		self.shouldDrawAdornments = NO;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_representedObject);
	IMBRelease(_target);
	IMBRelease(_normalImage);
	IMBRelease(_highlightedImage);

	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Buttons are not selectable...

- (BOOL) isSelectable 
{
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// If we have custom images for the normal and hilghted state, then update imageRepresentation with the appropriate
// one depdending on state. If we do not have any custom images, then do not touch imageRepresentation...


- (void) setImageRepresentationForState:(BOOL)inHighlighted
{
	if (inHighlighted)
	{
		if (_highlightedImage)
		{
			self.imageRepresentation = _highlightedImage;
			self.imageVersion = self.imageVersion + 1;
		}
	}
	else
	{
		if (_normalImage)
		{
			self.imageRepresentation = _normalImage;
			self.imageVersion = self.imageVersion + 1;
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Send the preconfigured actions. The object is self (IMBButtonObject), so the action can access all properties,
// like representedObject and location to customize the behavior of the action...


- (void) sendClickAction
{
	if (_target != nil && _clickAction != NULL)
	{
		[_target performSelector:_clickAction withObject:self];
	}	
	else
	{
		NSBeep();
	}
}


- (void) sendDoubleClickAction
{
	if (_target != nil && _doubleClickAction != NULL)
	{
		[_target performSelector:_doubleClickAction withObject:self];
	}	
	else
	{
		NSBeep();
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Return the button image as the small icon...

- (NSImage*) icon
{
	id imageRepresentation = self.imageRepresentation;
	
	if ([imageRepresentation isKindOfClass:[NSImage class]])
	{
		return (NSImage*)imageRepresentation;
	}
	
	return [super icon];
}


//----------------------------------------------------------------------------------------------------------------------


@end
