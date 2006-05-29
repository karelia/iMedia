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

#import "iMBMusicController.h"
#import "iMediaBrowser.h"
#import "iMBDNDArrayController.h"
#import "TimeValueTransformer.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"

#import <QTKit/QTKit.h>
#import <QTKit/QTMovieView.h>
#import <QuickTime/QuickTime.h>

extern NSString *Time_Display_String( int Number_Of_Seconds );
const NSTimeInterval	k_Scrub_Slider_Update_Interval = 0.1;
const double		k_Scrub_Slider_Minimum = 0.0;

@interface iMBMusicController (PrivateApi)

- (BOOL)loadAudioFile: (NSString *) path;
- (NSNumber *)clockTime;
- (void)setClockTime:(NSNumber *)value;
- (NSString*)iconNameForPlaylist:(NSString*)name;

@end

@implementation iMBMusicController

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	id timeValueTransformer = [[[TimeValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:timeValueTransformer forName:@"timeValueTransformer"];
	
	[pool release];
}

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"iTunes" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	[songsController setDelegate:self];
}

#pragma mark Protocol Methods

static NSImage *_toolbarIcon = nil;

- (NSImage *)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		_toolbarIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:@"com.apple.iTunes"] retain];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"music";
}

- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Audio", @"Name of Data Type");
}

- (void)setSelectionChanged:(id)val
{
	[self postSelectionChangeNotification:val];
}

- (id)selectionChanged
{
	return nil;
}

- (void)willActivate
{
	[self bind:@"selectionChanged" 
	  toObject:songsController
		 withKeyPath:@"selectedObjects" 
	   options:nil];
}

- (void)didDeactivate
{
	[self unbind:@"selectionChanged"];
	[self stopMovie:self];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	//[types addObject:@"ImageDataListPboardType"];
	
	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [[playlist attributeForKey:@"Tracks"] objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSString *locURLString = [cur objectForKey:@"Location"];
		NSURL *locURL = [NSURL URLWithString:locURLString];
		NSString *loc = [locURL path];
		[files addObject:loc];
	}
	[pboard writeURLs:nil files:files names:nil];
}

- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	//[types addObject:@"ImageDataListPboardType"];
	
	[pboard declareTypes:types owner:nil];
	
	NSArray *content = [songsController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *files = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSDictionary *song = [content objectAtIndex:[cur unsignedIntValue]];
		NSString *locURLString = [song objectForKey:@"Location"];
		NSURL *locURL = [NSURL URLWithString:locURLString];
		NSString *loc = [locURL path];
		[files addObject:loc];
	}
	// We add files, not URLs, since is is really a list of files
	[pboard writeURLs:nil files:files names:nil];
	
	return YES;
}

static NSImage *_playing = nil;
static NSImage *_song = nil;

#pragma mark -
#pragma mark Interface Methods

- (BOOL) loadAudioFile: (NSString *) urlString
{		
	BOOL success = YES;
	NSURL * movieURL = [NSURL URLWithString:urlString];
	if (!movieURL)
		movieURL = [NSURL fileURLWithPath:urlString];
	
	NSString *filePath = [movieURL path];
	[oAudioPlayer pause:self];
	NSError *err = nil;
	QTMovie *audio = [[[QTMovie alloc] initWithAttributes:
		[NSDictionary dictionaryWithObjectsAndKeys: 
			filePath, QTMovieFileNameAttribute,
			[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
			nil] error:&err] autorelease];
	if (err || !audio)
	{
		NSLog(@"%@", err);
		success = NO;
	}
		
	[audio setDelegate:self];
	[oAudioPlayer setMovie:audio];
	[playButton setEnabled: (audio != nil)];
	
	[clockDisplay setObjectValue:[NSNumber numberWithInt:0]];
	[progressIndicator setMinValue: k_Scrub_Slider_Minimum];
	QTTime dur = [audio duration];
    [progressIndicator setMaxValue: GetMovieDuration( [audio quickTimeMovie] )];
    [progressIndicator setDoubleValue: k_Scrub_Slider_Minimum ];
	return success;
}

static NSImage *_stopImage = nil;

- (IBAction) playMovie: (id) sender
{	
	if ([self loadAudioFile:[[songsController selection] valueForKey:@"Preview"]])
	{
		[pollTimer invalidate];
		pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
													 target:self
												   selector:@selector(updateDisplay:)
												   userInfo:nil
													repeats:YES];
		
		[table reloadData];
		
		[progressIndicator setDoubleValue:0];
		[clockDisplay setStringValue:@"0:00"];
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
