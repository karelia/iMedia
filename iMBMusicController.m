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
#import "DNDArrayController.h"
#import "Library.h"
#import "iTunesValueTransformer.h"
#import "TimeValueTransformer.h"

#import <QTKit/QTKit.h>
#import <QTKit/QTMovieView.h>
#import <Quicktime/Quicktime.h>

extern NSString *Time_Display_String( int Number_Of_Seconds );
const NSTimeInterval	k_Scrub_Slider_Update_Interval = 0.1;
const double		k_Scrub_Slider_Minimum = 0.0;

@interface iMBMusicController (PrivateApi)
#pragma mark PRIVATE SETUP
- (void)loadAudioFile: (NSString *) path;

#pragma mark PRIVATE ACCESSORS & MUTATORS
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

// NOTE: THIS COULD DEFINITELY BE OPTIMIZED, OR MADE TO RUN IN THE BACKGROUND, ETC.

- (NSArray*)loadDatabase
{
	NSMutableDictionary *musicLibrary = [NSMutableDictionary dictionary];
	NSMutableArray *playLists = [NSMutableArray array];
	
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iTunesRecentDatabases",
														(CFStringRef)@"com.apple.iApps");
	NSArray *libraries = [(NSArray *)iApps autorelease];
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[musicLibrary addEntriesFromDictionary:db];
		}
	}
	
	// purge empty entries here....
	
	NSEnumerator * enumerator = [[musicLibrary objectForKey:@"Tracks"] keyEnumerator];
	id key;
	int x = 0;
	
	Library *library = [[Library alloc] init];
	Library *podcastLib = [[Library alloc] init];
	Library *partyShuffleLib = [[Library alloc] init];
	
	[library setName:@"Library"];
	[library setLibraryImageName:[self iconNameForPlaylist:[library name]]];
	
	NSMutableDictionary *tracksInMasterLibrary = [NSMutableDictionary dictionary];
	while ((key = [enumerator nextObject])) {
		NSNumber * keyValue = [NSNumber numberWithInt:x];
		[tracksInMasterLibrary setObject:[[musicLibrary objectForKey:@"Tracks"] objectForKey:key] forKey:[keyValue stringValue]];
		x++;
	}
	[library addLibraryItem:tracksInMasterLibrary];

	int playlistCount = [[musicLibrary objectForKey:@"Playlists"] count];
	
	for (x=0;x<playlistCount;x++)
	{
		NSString * objectName = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Name"];
		if ([objectName isEqualToString:@"Library"])
		{
			continue;
		}
		else if ([objectName isEqualToString:@"Podcasts"])
		{
			[podcastLib setName:@"Podcasts"];
			[podcastLib setLibraryImageName:[self iconNameForPlaylist:[podcastLib name]]];
			
			NSArray * podcastItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
			int podcastItemsIter;
			for (podcastItemsIter=0;podcastItemsIter<[podcastItems count];podcastItemsIter++)
			{
				NSNumber *keyNumber = [NSNumber numberWithInt:podcastItemsIter];
				NSString *newKeyString = [keyNumber stringValue];
				NSDictionary *tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
				NSString *trackId = [[[podcastItems objectAtIndex:[newKeyString intValue]] objectForKey:@"Track ID"] stringValue];
				
				NSDictionary * newPlaylistContent = [tracksDictionary objectForKey:trackId];
				if ([newPlaylistContent objectForKey:@"Name"] && [[newPlaylistContent objectForKey:@"Location"] length] > 0)
				{
					[podcastLib addLibraryItem:newPlaylistContent];
				}
			}				
		}
		else if ([objectName isEqualToString:@"Party Shuffle"])
		{
			[partyShuffleLib setName:@"Party Shuffle"];
			[partyShuffleLib setLibraryImageName:[self iconNameForPlaylist:[partyShuffleLib name]]];
			
			NSArray * partyShuffleItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
			int partyShuffleItemsIter;
			for (partyShuffleItemsIter=0;partyShuffleItemsIter<[partyShuffleItems count];partyShuffleItemsIter++)
			{
				NSNumber * keyNumber = [NSNumber numberWithInt:partyShuffleItemsIter];
				NSString * newKeyString = [keyNumber stringValue];
				NSDictionary * tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
				NSDictionary * newPlaylistContent = [tracksDictionary objectForKey:[[[partyShuffleItems objectAtIndex:[newKeyString intValue]] objectForKey:@"Track ID"] stringValue]];
				if ([newPlaylistContent objectForKey:@"Name"] && [[newPlaylistContent objectForKey:@"Location"] length] > 0)
				{
					[partyShuffleLib addLibraryItem:newPlaylistContent];
				}
			}
		}
		else
		{
			Library *lib = [[Library alloc] init];
			NSMutableDictionary * newPlaylist = [NSMutableDictionary dictionary];
			[lib setName:objectName];
			[lib setLibraryImageName:[self iconNameForPlaylist:[lib name]]];
			
			NSArray * libraryItems = [[[musicLibrary objectForKey:@"Playlists"] objectAtIndex:x] objectForKey:@"Playlist Items"];
			int libraryItemsIter;
			for (libraryItemsIter=0;libraryItemsIter<[libraryItems count];libraryItemsIter++)
			{
				NSNumber * keyNumber = [NSNumber numberWithInt:libraryItemsIter];
				NSString * newKeyString = [keyNumber stringValue];
				NSDictionary * tracksDictionary = [musicLibrary objectForKey:@"Tracks"];
				NSDictionary * newPlaylistContent = [tracksDictionary objectForKey:[[[libraryItems objectAtIndex:[newKeyString intValue]] objectForKey:@"Track ID"] stringValue]];
				if ([newPlaylistContent objectForKey:@"Name"] && [[newPlaylistContent objectForKey:@"Location"] length] > 0)
				{
					[newPlaylist setObject:newPlaylistContent forKey:newKeyString];
				}
			}
			[lib addLibraryItem:newPlaylist];
			
			if ([[lib libraryItems] count] > 0) {
				[playLists addObject:lib];
			}
			[lib release];
		}
	}
	[playLists insertObject:library atIndex:0];
	[playLists insertObject:podcastLib atIndex:1];
	[playLists insertObject:partyShuffleLib atIndex:2];
	[library release];
	[podcastLib release];
	[partyShuffleLib release];
	return playLists;
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

- (NSString *)name
{
	return NSLocalizedString(@"iTunes", @"iMedia Browser Menu Item Name");
}

static NSImage *_itunesIcon = nil;

- (NSImage *)menuIcon
{
	if (!_itunesIcon) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"tunes_tiny" ofType:@"png"];
		_itunesIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _itunesIcon;
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	[oAudioPlayer pause:self];
}

- (NSString *)iconNameForPlaylist:(NSString*)name{	
	if ([name isEqualToString:@"Library"])
		return @"MBiTunesLibrary";
	else if ([name isEqualToString:@"Party Shuffle"])
		return @"MBiTunesPartyShuffle";
	else if ([name isEqualToString:@"Purchased Music"])
		return @"MBiTunesPurchasedPlaylist";
	else if ([name isEqualToString:@"Podcasts"])
		return @"MBiTunesPodcast";
	else
		return @"MBiTunesPlaylist";
}

#pragma mark -
#pragma mark Table Data Source Methods

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
