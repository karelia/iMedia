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
		
	// first try to get CURRENT time.
	QTTime qttime = [self currentTime];

	// If still zero, get POSTER time.
	if (NSOrderedSame == QTTimeCompare(qttime, QTZeroTime))
	{
		NSValue *timeValue = [attr objectForKey:QTMoviePosterTimeAttribute];
		if (nil != timeValue)
		{
			qttime = [timeValue QTTimeValue];
		}
	}
	
	// if still zero, get 20 seconds in, capped at 1/5 movie time.
	if (NSOrderedSame == QTTimeCompare(qttime, QTZeroTime))
	{
        qttime.timeScale = [[attr objectForKey:QTMovieTimeScaleAttribute] longValue];
        if (qttime.timeScale == 0)
            qttime.timeScale = 60;
		qttime.timeValue = qttime.timeScale * 20;
		
		NSValue *timeValue = [attr objectForKey:QTMovieDurationAttribute];
		if (nil != timeValue)
		{
			QTTime capTime = [timeValue QTTimeValue];
			capTime.timeValue /= 5;
			if (NSOrderedDescending == QTTimeCompare(qttime, capTime))	// 20 seconds > 1/5 total?
			{
				qttime = capTime;
			}
		}
        // Move the time to the next key frame so QT to speed things up a little
        OSType		whichMediaType = VIDEO_TYPE;
        TimeValue   newTimeValue = 0;
        GetMovieNextInterestingTime([self quickTimeMovie], nextTimeSyncSample, 1, &whichMediaType, qttime.timeValue, 0, &newTimeValue, NULL);
        if (newTimeValue > 0 && newTimeValue < qttime.timeValue * 1.25) // stay within a reasonable time
            qttime.timeValue = newTimeValue;
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

const UInt8 kUserDataIsText = 0xA9; // the copyright symbol

- (NSString *)attributeWithFourCharCode:(OSType)code
{
	NSString *result = nil;
	OSErr err = noErr;
	OSType udType;
	short count, i;
	char nul = 0;
	Handle hData = NULL;
	Ptr p;
	UserData inUserData = GetMovieUserData([self quickTimeMovie]);
	
	if ((code >> 24) == kUserDataIsText) 
	{
		hData = NewHandle(0);
		udType = GetNextUserDataType(inUserData, 0);
		do {
			if (0 != udType) 
			{
				count = CountUserDataType(inUserData, udType);
				for(i = 1; i <= count; i++)
				{
					if(udType == code) 
					{
						err = GetUserDataText(inUserData, hData, udType, i, langEnglish);
						if (err) goto bail;
						// null-terminate the string in the handle
						PtrAndHand(&nul, hData, 1);
						
						// turn any CRs into spaces
						p = *hData;
						while(*p) {
							if (*p == kReturnCharCode) *p = ' ';
							p++;
						};
						
						HLock(hData);
						result = [NSString stringWithCString:*hData];
						HUnlock(hData);
						goto bail;
					}
				}
			}	
			udType = GetNextUserDataType(inUserData, udType);
		} while (0 != udType);
	}
bail:
	DisposeHandle(hData);
	
	return result;
}

// returns YES if the movie is currently playing, NO if not
- (BOOL)isPlaying
{
	if ([self rate] == 0)
	{
		return NO;
	}
	
	return YES;
}

// return the movie duration as a string
- (NSString *)durationAsString
{
	QTTime durationQTTime = [self duration];
	int durationInSeconds = (float)durationQTTime.timeValue/durationQTTime.timeScale;
	int durationInMinutes = durationInSeconds/60;
	int durationInHours = durationInMinutes/60;
	return ([NSString stringWithFormat:@"%qi:%qi:%qi" , 
								durationInHours, 
		durationInMinutes, 
		durationInSeconds]);
}

- (NSString *)currentTimeAsString
{
	QTTime currQTTime = [self currentTime];
	int actualSeconds = currQTTime.timeValue/currQTTime.timeScale;
	div_t hours = div(actualSeconds,3600);
	div_t minutes = div(hours.rem,60);
	
	if (hours.quot == 0) {
		return [NSString stringWithFormat:@"%2d:%.2d", minutes.quot, minutes.rem];
	}
	else {
		return [NSString stringWithFormat:@"%2d:%02d:%02d", hours.quot, minutes.quot, minutes.rem];
	}	
}

- (float)durationInSeconds
{
	QTTime durationQTTime = [self duration];
	float durationInSeconds = (float)durationQTTime.timeValue/durationQTTime.timeScale;
	return durationInSeconds;
}

// set the movie's current time
- (void)setTime:(int)timeValue
{
	QTTime movieQTTime;
	NSValue *valueForQTTime;
	
	[self timeToQTTime:timeValue resultTime:&movieQTTime];
	
	valueForQTTime = [NSValue valueWithQTTime:movieQTTime];
	
	[self setAttribute:valueForQTTime forKey:QTMovieCurrentTimeAttribute];
}


// returns YES if the movie's current time is the movie end,
// NO if not
- (BOOL)currentTimeEqualsDuration
{	
	QTTime movDuration = [self duration];
	QTTime curTime = [self currentTime];
	if (QTTimeCompare(movDuration,curTime) == NSOrderedSame)
	{
		return YES;
	}
	
	return NO;
}

// convert a time value (long) to a QTTime structure
- (void)timeToQTTime:(long)timeValue resultTime:(QTTime *)aQTTime
{
	NSNumber *timeScaleObj;
	long timeScaleValue;
	
	timeScaleObj = [self attributeForKey:QTMovieTimeScaleAttribute];
	timeScaleValue = [timeScaleObj longValue];
	
	*aQTTime = QTMakeTime(timeValue, timeScaleValue);
}

// return the movie file path
- (NSString *)movieFilePath
{
	return ([self attributeForKey:QTMovieFileNameAttribute]);
}

// return the movie file name
- (NSString *)movieFileName
{
	return ([self filenameFromFullPath:[self movieFilePath]]);
}

// returns the movie's filename specified by the full path
- (NSString *)filenameFromFullPath:(NSString *)fullPath
{
	NSArray *pathComponents = [fullPath componentsSeparatedByString:@"/"];
	return ([pathComponents objectAtIndex:([pathComponents count] - 1)]);
}

@end
