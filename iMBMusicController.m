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
 
 In the case of iMediaBrowse, in addition to the terms noted above, in any 
 application that uses iMediaBrowse, we ask that you give a small attribution to 
 the members of CocoaDev.com who had a part in developing the project. Including, 
 but not limited to, Jason Terhorst, Greg Hulands and Ben Dunton.
 
 Greg doesn't really want acknowledgement he just want bug fixes as he has rewritten
 practically everything but the xml parsing stuff. Please send fixes to 
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */

#import "iMBMusicController.h"
#import "iMediaBrowser.h"
#import "iMBDNDArrayController.h"
#import "iTunesValueTransformer.h"
#import "TimeValueTransformer.h"

#import <QTKit/QTKit.h>
#import <QTKit/QTMovieView.h>
#import <Quicktime/Quicktime.h>

extern NSString *Time_Display_String( int Number_Of_Seconds );
const NSTimeInterval	k_Scrub_Slider_Update_Interval = 0.1;
const double		k_Scrub_Slider_Minimum = 0.0;

@interface iMBMusicController (PrivateApi)

- (void)loadAudioFile: (NSString *) path;
- (NSNumber *)clockTime;
- (void)setClockTime:(NSNumber *)value;
- (NSString*)iconNameForPlaylist:(NSString*)name;

@end

@implementation iMBMusicController

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	id itunesValueTransformer = [[[iTunesValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:itunesValueTransformer forName:@"itunesValueTransformer"];
	
	id timeValueTransformer = [[[TimeValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:timeValueTransformer forName:@"timeValueTransformer"];
	
	[pool release];
}

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super init]) {
		[self setPlaylistController:ctrl];
		[NSBundle loadNibNamed:@"iTunes" owner:self];
	}
	return self;
}

- (void)dealloc
{	
	[playlistController release];
	[super dealloc];
}

- (void) awakeFromNib
{	
}

#pragma mark Protocol Methods

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBiTunes" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"music";
}

- (NSString *)name
{
	return NSLocalizedString(@"Audio", @"Audio");
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	[oAudioPlayer pause:self];
}


- (void)writePlaylistsToPasteboard:(NSPasteboard *)pboard
{
	
}

- (void)refresh
{
	
}

static NSImage *_playing = nil;
static NSImage *_song = nil;

#pragma mark -
#pragma mark Interface Methods

- (void) loadAudioFile: (NSString *) urlString
{		
	NSURL * movieURL = [NSURL URLWithString:urlString];
	
	[oAudioPlayer pause:self];
	NSError *err = nil;
	QTMovie *audio = [QTMovie movieWithURL:movieURL error:&err];
	if (err) 
		NSLog(@"%@", err);
	[audio setDelegate:self];
	[oAudioPlayer setMovie:audio];
	[playButton setEnabled: (audio != nil)];
	
	[clockDisplay setObjectValue:[NSNumber numberWithInt:0]];
	[progressIndicator setMinValue: k_Scrub_Slider_Minimum];
    [progressIndicator setMaxValue: GetMovieDuration( [audio quickTimeMovie] )];
    [progressIndicator setDoubleValue: k_Scrub_Slider_Minimum ];
}

static NSImage *_stopImage = nil;

- (IBAction) playMovie: (id) sender
{	
	[self loadAudioFile:[[songsController selection] valueForKey:@"Location"]];
	
	[pollTimer invalidate];
	pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
												 target:self
											   selector:@selector(updateDisplay:)
											   userInfo:nil
												repeats:YES];
	
	[table reloadData];
	
	[oAudioPlayer gotoBeginning:self];
	[oAudioPlayer play:self];
	
	[playButton setAction:@selector(stopMovie:)];
	[playButton setState:NSOnState];
	if (!_stopImage) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBNowPlayingButton" ofType:@"png"];
		_stopImage = [[NSImage alloc] initWithContentsOfFile:p];
	}
	[playButton setImage:_stopImage];
}

static NSImage *_playImage = nil;

- (IBAction) stopMovie: (id) sender
{
	[oAudioPlayer pause:self];
	[table reloadData];
	[pollTimer invalidate];
	pollTimer = nil;
	[playButton setAction:@selector(playMovie:)];
	[playButton setState:NSOffState];
	if (!_playImage) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBPlayN" ofType:@"png"];
		_playImage = [[NSImage alloc] initWithContentsOfFile:p];
	}
	[playButton setImage:_playImage];
	[clockDisplay setObjectValue:[NSNumber numberWithInt:0]];
}

- (IBAction) scrubAudio: (id) sender
{
	SetMovieTimeValue([(QTMovie *)[oAudioPlayer movie] quickTimeMovie], [progressIndicator doubleValue]);
	[self setClockTime:[NSNumber numberWithInt:GetMovieTime([(QTMovie *)[oAudioPlayer movie] quickTimeMovie], NULL)]];
}

- (void)updateDisplay:(NSTimer *)timer
{
	QTMovie *audio = [oAudioPlayer movie];
	if (GetMovieTime([audio quickTimeMovie], NULL) == GetMovieDuration([audio quickTimeMovie])) {
		[self stopMovie:self];
	} else {
		[progressIndicator setDoubleValue: GetMovieTime([(QTMovie *)[oAudioPlayer movie] quickTimeMovie], NULL)];
		[self setClockTime:[NSNumber numberWithInt:GetMovieTime([(QTMovie *)[oAudioPlayer movie] quickTimeMovie], NULL)]];
	}
}

#pragma mark -
#pragma mark Accessors
- (NSTreeController *)playlistController {
    return [[playlistController retain] autorelease];
}

- (void)setPlaylistController:(NSTreeController *)value {
    if (playlistController != value) {
        [playlistController release];
        playlistController = [value retain];
    }
}

- (NSNumber *)clockTime {
    return [[clockTime retain] autorelease];
}

- (void)setClockTime:(NSNumber *)value {
    if (clockTime != value) {
        [clockTime release];
        clockTime = [value copy];
    }
}
@end
