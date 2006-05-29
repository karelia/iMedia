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
 
 This file was Authored by Dan Wood
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX; THE CODE WILL HAVE THE
 SAME LICENSING TERMS.  PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
 
 
 */

#import "QTMovie+iMedia.h"
#import <QTKit/QTKit.h>
#import <QTKit/QTTime.h>

@implementation QTMovie ( iMedia )

// Get current time, or poster time, or ~20 seconds in

- (NSImage *)betterPosterImage;
{
	NSDictionary *attr = [self movieAttributes];
	
	// initialize with zero; we want something more interesting.
	QTTime qttime = QTZeroTime;
	
	// first try to get CURRENT time.
	NSValue *timeValue = [attr objectForKey:QTMovieCurrentTimeAttribute];
	if (nil != timeValue)
	{
		qttime = [timeValue QTTimeValue];
	}
	
	// If still zero, get POSTER time.
	if (NSOrderedSame == QTTimeCompare(qttime, QTZeroTime))
	{
		timeValue = [attr objectForKey:QTMoviePosterTimeAttribute];
		if (nil != timeValue)
		{
			qttime = [timeValue QTTimeValue];
		}
	}
	
	// if still zero, get 20 seconds in, capped at 1/5 movie time.
	if (NSOrderedSame == QTTimeCompare(qttime, QTZeroTime))
	{
		qttime = QTMakeTimeWithTimeInterval(20.0);
		
		timeValue = [attr objectForKey:QTMovieDurationAttribute];
		if (nil != timeValue)
		{
			QTTime capTime = [timeValue QTTimeValue];
			capTime.timeValue /= 5;
			if (NSOrderedDescending == QTTimeCompare(qttime, capTime))	// 20 seconds > 1/5 total?
			{
				qttime = capTime;
			}
		}
	}
	return [self frameImageAtTime:qttime];
}


- (BOOL) isDRMProtected
{
	BOOL isProtected = NO;
	NSEnumerator *e = [[self tracks] objectEnumerator];
	id cur;
	
	MediaHandler mh;
	ComponentResult result;
	
	while (cur = [e nextObject])
	{
		mh = GetMediaHandler([[cur media] quickTimeMedia]);
		result = 
			QTGetComponentProperty(
								   mh,								// ComponentInstance        inComponent,
								   kQTPropertyClass_DRM,			// ComponentPropertyClass   inPropClass,
								   kQTDRMPropertyID_IsProtected,	// ComponentPropertyID      inPropID,
								   sizeof(BOOL),					// ByteCount                inPropValueSize,
								   &isProtected,					// ComponentValuePtr        outPropValueAddress,
								   NULL);							// ByteCount *              outPropValueSizeUsed)
		if (isProtected)
			break;
	}

	return isProtected;
}



@end
