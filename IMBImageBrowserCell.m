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

#import "IMBImageBrowserCell.h"
#import "IMBObject.h"


//----------------------------------------------------------------------------------------------------------------------


@interface IKImageBrowserCell ()

- (void) setDataSource:(id)inDataSource;
- (void) drawShadow;
- (void) drawImageOutline;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBImageBrowserCell

@synthesize imbShouldDrawOutline = _imbShouldDrawOutline;
@synthesize imbShouldDrawShadow = _imbShouldDrawShadow;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_imbShouldDrawOutline = YES;
		_imbShouldDrawShadow = YES;
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


// Disable outline and shadow drawing for folders (IMBNodeObject)...

- (void) setDataSource:(id)inDataSource
{
	[super setDataSource:inDataSource];
	
	if ([inDataSource isKindOfClass:[IMBNodeObject class]])
	{
		_imbShouldDrawOutline = NO;
		_imbShouldDrawShadow = NO;
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) drawShadow
{
	if (_imbShouldDrawShadow)
	{
		[super drawShadow];	
	}
}


- (void) drawImageOutline
{
	if (_imbShouldDrawOutline)
	{
		[super drawImageOutline];	
	}	
}


- (void) sizeDidChange
{	
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
#else
	CGFloat points = 0;
	CGFloat width = [self size].width;
	
	if (width < 50) points = 9;
	else if (width < 60) points = 10;
	else if (width < 70) points = 11;
	else if (width < 80) points = 12;
	else points = 13;

	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObject:[NSFont fontWithName:@"Lucida Grande" size:points] forKey:NSFontAttributeName];
	[[self parent] setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];
#endif
	
	[super sizeDidChange];
}


//----------------------------------------------------------------------------------------------------------------------


@end

