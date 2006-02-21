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

#import "iMBMoviesController.h"
#import <QTKit/QTKit.h>
#import "iMediaBrowser.h"
#import "UKKQueue.h"
#import "Library.h"

@interface iMBMoviesController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBMoviesController

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super init]) {
		[NSBundle loadNibNamed:@"Movies" owner:self];
	}
	return self;
}

- (NSArray*)loadDatabase
{
	[pathList removeAllObjects];
	NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies"];
	NSArray *files = [[NSFileManager defaultManager] subpathsAtPath:dir];
	NSArray *movieTypes = [QTMovie movieFileTypes:QTIncludeCommonTypes];
	NSEnumerator *e = [files objectEnumerator];
	NSString *cur;
	
	Library *lib = [[Library alloc] init];
	[lib setName:@"Movies"];
	[lib setLibraryImageName:[self iconNameForPlaylist:[lib name]]];
	
	while (cur = [e nextObject]) {
		NSMutableDictionary *newMovie = [NSMutableDictionary dictionary];
		if ([movieTypes containsObject:[cur pathExtension]]) {
			[newMovie setObject:[dir stringByAppendingPathComponent:cur] forKey:@"Location"];
			[lib addLibraryItem:newMovie];
		}
	}
	[counterField setStringValue:[NSString stringWithFormat:@"%d movies", [[lib libraryItems] count]]];
	return [NSArray arrayWithObject:lib];
}

//run when first loaded.
- (void)awakeFromNib
{
	pathList = [[NSMutableArray alloc] init];
	NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies"];
	
	//we want to watch this path for changes
	UKKQueue *watcher = [UKKQueue sharedQueue];
	[watcher setDelegate:self];
	[watcher addPathToQueue:dir];
}

-(void) kqueue: (UKKQueue*)kq receivedNotification: (NSString*)nm forFile: (NSString*)fpath
{
	[self loadDatabase];
}

#pragma mark -
#pragma mark Media Browser Protocol

static NSImage *_movieIcon = nil;

- (NSImage *)menuIcon
{
	if (!_movieIcon) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"quicktime_tiny" ofType:@"png"];
		_movieIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _movieIcon;
}

- (NSString *)name
{
	return NSLocalizedString(@"Movies", @"Movies");
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	[previewMovieView pause:self];
}

//- (int)numberOfPlaylistItems
//{
//	return [pathList count];
//}

//- (NSString *)playlistAtIndex:(unsigned)idx
//{
//	return [[pathList objectAtIndex:idx] lastPathComponent];
//}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	return @"MBQuicktime.png";
}

//- (NSArray *)filePathsForPlaylistAtIndex:(unsigned)idx
//{
//	return [NSArray arrayWithObject:[pathList objectAtIndex:idx]];
//}
//
//- (void)selectedPlaylistAtIndex:(unsigned)idx
//{
//	if (idx >= 0 && idx < [pathList count]) {
//		NSURL *url = [NSURL fileURLWithPath:[pathList objectAtIndex:idx]];
//		NSError *err = nil;
//		QTMovie *movie = [QTMovie movieWithURL:url error:&err];
//		if (err) {
//			NSLog(@"%@", err);
//		}
//		[previewMovieView setMovie:movie];
//		//[previewMovieView play:self]; //don't automatically play
//	}
//}


@end
