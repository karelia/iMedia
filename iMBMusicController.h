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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import <Cocoa/Cocoa.h>
#import "iMBAbstractController.h"

@class QTMovieView, iMBDNDArrayController;

@interface iMBMusicController : iMBAbstractController
{
	IBOutlet NSTextField			*counterField;
	IBOutlet NSButton				*playButton;
	IBOutlet NSSlider				*progressIndicator;
	IBOutlet NSSearchField			*oSearch;
	IBOutlet NSTableView			*table;
	IBOutlet QTMovieView			*oAudioPlayer;
	IBOutlet iMBDNDArrayController	*songsController;
	NSString						*clockTime;
	@private
		NSTimer * pollTimer;
		NSMutableDictionary *myCurrentPlayingRecord;
}

#pragma mark ACCESSORS
- (NSString *)clockTime;
- (void)setClockTime:(NSString *)value;

#pragma mark ACTIONS
- (IBAction) playMovie: (id) sender;
- (IBAction) stopMovie: (id) sender;
- (IBAction) scrubAudio: (id) sender;
@end

extern const NSTimeInterval	k_Scrub_Slider_Update_Interval;
extern const double			k_Scrub_Slider_Minimum;