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
#import "QTMovie+iMedia.h"

#import <QTKit/QTKit.h>

extern NSString *Time_Display_String( int Number_Of_Seconds );
const NSTimeInterval	k_Scrub_Slider_Update_Interval = 0.1;
const double		k_Scrub_Slider_Minimum = 0.0;

@interface iMBMusicController (PrivateApi)

- (BOOL)loadAudioFile: (NSString *) path;
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

- (Class)parserForFolderDrop
{
	return NSClassFromString(@"iMBMusicFolder");
}

- (void)refresh
{
	[super refresh];
	[self unbind:@"selectionChanged"];
	[self stopMovie:self];
	[self bind:@"selectionChanged" 
	  toObject:songsController
		 withKeyPath:@"selectedObjects" 
	   options:nil];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:QTMovieTimeDidChangeNotification
												  object:nil];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	//[types addObject:@"ImageDataListPboardType"];
	
	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [[playlist valueForKey:@"Tracks"] objectEnumerator];
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
	[types addObject:@"CorePasteboardFlavorType 0x6974756E"]; // iTunes track information
	[types addObject:iMBNativePasteboardFlavor]; // Native iMB Data
	
	[pboard declareTypes:types owner:nil];
	
	NSArray *content = [songsController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *files = [NSMutableArray array];
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[rows count]];
	while (cur = [e nextObject])
	{
		NSDictionary *song = [content objectAtIndex:[cur unsignedIntValue]];
		NSData *data = [NSArchiver archivedDataWithRootObject:song];
		[pboard setData:data forType:@"CorePasteboardFlavorType 0x6974756E"]; // iTunes track information
      
      [nativeDataArray addObject:song];
		
		NSString *locURLString = [song objectForKey:@"Location"];
		NSURL *locURL = [NSURL URLWithString:locURLString];
		if (!locURL)
			locURL = [NSURL fileURLWithPath:locURLString];
		NSString *loc = [locURL path];
		[files addObject:loc];
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
	// We add files, not URLs, since is is really a list of files
	[pboard writeURLs:nil files:files names:nil];
	
	return YES;
}


#pragma mark -
#pragma mark Interface Methods

- (IBAction)search:(id)sender
{
	[songsController setSearchString:[sender stringValue]];
}

static NSImage *_playingIcon = nil;

- (BOOL) loadAudioFile: (NSString *) urlString
{		
	BOOL success = YES;
	
	// remove notification for currently playing song
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:QTMovieTimeDidChangeNotification
												  object:[oAudioPlayer movie]];
	//change the icon back
	[myCurrentPlayingRecord setObject:[myCurrentPlayingRecord objectForKey:@"OriginalIcon"] forKey:@"Icon"];
	
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
		success = NO;
	}
	
	[audio setDelegate:self];
	[oAudioPlayer setMovie:audio];
	[playButton setEnabled: (audio != nil)];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(audioTimeDidChange:)
												 name:QTMovieTimeDidChangeNotification
											   object:audio];
	
	[progressIndicator setMinValue: k_Scrub_Slider_Minimum];
	
	float audioDurationSeconds = [audio durationInSeconds];
    [progressIndicator setMaxValue: audioDurationSeconds];
    [progressIndicator setDoubleValue: k_Scrub_Slider_Minimum ];
	
	// update the icon
	if (!_playingIcon)
	{
		NSString *p = [[NSBundle bundleForClass:[self class]] pathForResource:@"MBAudioPlaying" ofType:@"png"];
		_playingIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	myCurrentPlayingRecord = [[songsController selectedObjects] objectAtIndex:0];
	[myCurrentPlayingRecord setObject:[myCurrentPlayingRecord objectForKey:@"Icon"] forKey:@"OriginalIcon"];
	[myCurrentPlayingRecord setObject:_playingIcon forKey:@"Icon"];
	
	return success;
}

static NSImage *_stopImage = nil;

- (IBAction) playMovie: (id) sender
{	
	if ([self loadAudioFile:[[[songsController selectedObjects] objectAtIndex:0] valueForKey:@"Preview"]])
	{
		[pollTimer invalidate];
		pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
													 target:self
												   selector:@selector(updateDisplay:)
												   userInfo:nil
													repeats:YES];
		
		[table reloadData];
		
		[progressIndicator setDoubleValue:0];
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
		[progressIndicator setEnabled:YES];
	}
}

static NSImage *_playImage = nil;

- (IBAction) stopMovie: (id) sender
{
	[oAudioPlayer pause:self];
	[pollTimer invalidate];
	pollTimer = nil;
	//change the icon back
	[myCurrentPlayingRecord setObject:[myCurrentPlayingRecord objectForKey:@"OriginalIcon"] forKey:@"Icon"];
	[table reloadData];
	[progressIndicator setDoubleValue:[progressIndicator minValue]];
	[progressIndicator setEnabled:NO];
	[self setClockTime:@"0:00"];
	[playButton setAction:@selector(playMovie:)];
	[playButton setState:NSOffState];
	if (!_playImage) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBPlayN" ofType:@"png"];
		_playImage = [[NSImage alloc] initWithContentsOfFile:p];
	}
	[playButton setImage:_playImage];
}

- (IBAction) scrubAudio: (id) sender
{
	[[oAudioPlayer movie] setTime:(int)[progressIndicator doubleValue]*600];
}

- (void)updateDisplay:(NSTimer *)timer
{
	QTMovie *audio = [oAudioPlayer movie];
	
	if ([audio currentTimeEqualsDuration]) {
		[self stopMovie:self];
	} else {
		QTTime curPlayTime = [audio currentTime];
		[progressIndicator setDoubleValue: curPlayTime.timeValue/curPlayTime.timeScale];
		[self setClockTime:[audio currentTimeAsString]];
	}
}

- (NSString *)clockTime {
    return [[clockTime retain] autorelease];
}

- (void)setClockTime:(NSString *)value {
    if (clockTime != value) {
        [clockTime release];
        clockTime = [value copy];
    }
}

#pragma mark -
#pragma mark Audio Notifications

- (void)audioTimeDidChange:(NSNotification *)aNotification
{
	[self setClockTime:[[oAudioPlayer movie] currentTimeAsString]];
}
@end
