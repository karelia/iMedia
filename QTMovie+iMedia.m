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
	QTTime qttime = QTZeroTime;
	NSValue *timeValue = [attr objectForKey:QTMovieCurrentTimeAttribute];
	if (nil == timeValue)
	{
		timeValue = [attr objectForKey:QTMoviePosterTimeAttribute];
	}
	if (nil == timeValue)
	{
		timeValue = [attr objectForKey:QTMovieDurationAttribute];
		
		// cap at 1/10 of total time
		qttime = [timeValue QTTimeValue];
		
	}
	qttime = [timeValue QTTimeValue];
	return [self posterImage];
}
//- (NSImage *)currentFrameImage;
//- (NSImage *)frameImageAtTime:(QTTime)time;


@end
