/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#import "TimeValueTransformer.h"


@implementation TimeValueTransformer
+ (Class)transformedValueClass
{
	return [NSString self];
}

+ (BOOL)allowsReverseTransformation
{
	return NO;
}

- (id)transformedValue:(id)beforeObject
{
    if (![beforeObject isKindOfClass:[NSNumber class]]) {
        return nil;
    }
	
	if([beforeObject intValue] == 0) return @"0:00";
	
	// Convert number to seconds, and then to an appropriate time value
	int actualSeconds = (int) roundf([beforeObject floatValue] / 1000.0);
	div_t hours = div(actualSeconds,3600);
	div_t minutes = div(hours.rem,60);
	
#warning really should internationalize
	if (hours.quot == 0) {
		return [NSString stringWithFormat:@"%2d:%.2d", minutes.quot, minutes.rem];
	}
	else {
		return [NSString stringWithFormat:@"%2d:%02d:%02d", hours.quot, minutes.quot, minutes.rem];
	}
}
@end
