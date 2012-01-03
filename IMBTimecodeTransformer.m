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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS
	
#import "IMBTimecodeTransformer.h"
	

//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBTimecodeTransformer


//----------------------------------------------------------------------------------------------------------------------


// Register the transformer...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	IMBTimecodeTransformer* transformer = [[IMBTimecodeTransformer alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:NSStringFromClass(self)];
	[transformer release];
	[pool drain];
}


//----------------------------------------------------------------------------------------------------------------------


+ (Class) transformedValueClass
{
	return [NSString class];
}


+ (BOOL) allowsReverseTransformation
{
	return YES;
}
		

//----------------------------------------------------------------------------------------------------------------------


// Convert from NSNumber to NSString...

- (id) transformedValue:(id)inValue
{
	id result = nil;
	
	if (inValue)
	{
		if ([inValue respondsToSelector:@selector(doubleValue)]) 
		{
			double t = [inValue doubleValue];
			NSInteger T = (NSInteger) t;
			
			NSInteger HH = T / 3600;
			NSInteger MM = (T / 60) % 60;
			NSInteger SS = T % 60;
			
			if (HH > 0)
			{
				result = [NSString stringWithFormat:@"%d:%d:%02d",HH,MM,SS];
			}	
			else
			{
				result = [NSString stringWithFormat:@"%d:%02d",MM,SS];
			}	
		}
	}
	
	return result;
}


// Convert from NSString to NSNumber...

- (id) reverseTransformedValue:(id)inValue
{
	double t = 0.0;
	
	if (inValue != nil && [inValue isKindOfClass:[NSString class]])
	{
		NSArray* parts = [(NSString*)inValue componentsSeparatedByString:@":"];
		NSInteger n = [parts count];
		double multiplier = 1.0;
		
		for (NSInteger i=n-1; i>=0; i--)
		{
			NSString* string = [parts objectAtIndex:i];
			double value = [string doubleValue];
			t += value * multiplier;
			multiplier *= 60.0;
		}
	}
	
	return [NSNumber numberWithDouble:t];
}
	

//----------------------------------------------------------------------------------------------------------------------


@end
	