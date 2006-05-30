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

#import "iMBMoviesController.h"
#import <QTKit/QTKit.h>
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"
#import "MUPhotoView.h"

@interface iMBMoviesController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBMoviesController

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		mySelection = [[NSMutableIndexSet alloc] init];
		myFilteredImages = [[NSMutableArray alloc] init];
		
		[NSBundle loadNibNamed:@"Movies" owner:self];
	}
	return self;
}

- (void)dealloc
{
	[previewMovieView release];
	[mySelection release];
	[myImages release];
	[myFilteredImages release];
	[mySearchString release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[oPhotoView setDelegate:self];
	[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
}

- (IBAction)play:(id)sender
{
	[previewMovieView play:sender];
}

- (void)viewResized:(NSNotification *)n
{
	NSRect r = [oPhotoView photoRectForIndex:movieIndex];
	[previewMovieView setFrame:r];
	[previewMovieView play:self];
}

- (void)refilter
{
	[mySelection removeAllIndexes];
	[myFilteredImages removeAllObjects];
	
	if ([mySearchString length] == 0) return;
	
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"Caption"] rangeOfString:mySearchString options:NSCaseInsensitiveSearch].location != NSNotFound ||
			[[cur objectForKey:@"ImagePath"] rangeOfString:mySearchString options:NSCaseInsensitiveSearch].location != NSNotFound)
		{
			[myFilteredImages addObject:cur];
		}
	}
}

- (IBAction)search:(id)sender
{
	[mySearchString autorelease];
	mySearchString = [[sender stringValue] copy];
	
	[self refilter];
	[oPhotoView setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Media Browser Protocol

- (void)willActivate
{
	[super willActivate];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Movies" 
	   options:nil];
	[oPhotoView prepare];
	[[oPhotoView window] makeFirstResponder:oPhotoView];
}

- (void)didDeactivate
{
	[self unbind:@"images"];
	[previewMovieView pause:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[previewMovieView removeFromSuperview];
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		// Try to use iMovie, or older iMovie, or quicktime player for movies.
		NSString *identifier = @"com.apple.iMovie";
		NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
		if (nil == path)
		{
			identifier = @"com.apple.iMovie3";
			path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
		}
		if (nil == path)
		{
			identifier = @"com.apple.quicktimeplayer";
		}
		_toolbarIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:identifier] retain];
		[_toolbarIcon setScalesWhenResized:YES];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"movies";
}

- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Movies", @"Name of Data Type");
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	return @"MBQuicktime.png";
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
	
	NSEnumerator *e = [[playlist attributeForKey:@"Movies"] objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		[files addObject:[cur objectForKey:@"ImagePath"]];
	}
	[pboard writeURLs:nil files:files names:nil];
}

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	[self refilter];
	//reset the scroll position
	[oPhotoView scrollRectToVisible:NSMakeRect(0,0,1,1)];
	[oPhotoView setNeedsDisplay:YES];
}

- (NSArray *)images
{
	return myImages;
}

- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
	if ([mySearchString length] > 0)
	{
		return [myFilteredImages count];
	}
	return [myImages count];
}

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:index];
	}
	else
	{
		rec = [myImages objectAtIndex:index];
	}
	
	return [rec objectForKey:@"CachedThumb"];
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
}

- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view
{
	return mySelection;
}

- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard
{
	NSMutableArray *fileList = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	
	NSMutableArray *types = [NSMutableArray array]; 
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
	
	NSDictionary *cur;
	
	int i;
	for(i = 0; i < [myImages count]; i++) 
	{
		if ([mySelection containsIndex:i]) 
		{
			if ([mySearchString length] > 0)
			{
				cur = [myFilteredImages objectAtIndex:i];
			}
			else
			{
				cur = [myImages objectAtIndex:i];
			}
			[fileList addObject:[cur objectForKey:@"ImagePath"]];
			[captions addObject:[cur objectForKey:@"Caption"]];
		}
	}
				
	[pboard writeURLs:nil files:fileList names:captions];	
}

- (NSString *)photoView:(MUPhotoView *)view captionForPhotoAtIndex:(unsigned)index
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:index];
	}
	else
	{
		rec = [myImages objectAtIndex:index];
	}
	return [rec objectForKey:@"Caption"];
}

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame
{
	movieIndex = index;
	if (!previewMovieView)
	{
		previewMovieView = [[QTMovieView alloc] initWithFrame:frame];
		[previewMovieView setControllerVisible:NO];
		[previewMovieView setShowsResizeIndicator:NO];
		[previewMovieView setPreservesAspectRatio:YES];
	}
	[previewMovieView setFrame:frame];
	NSString *path = [[myImages objectAtIndex:index] objectForKey:@"ImagePath"];
	
	NSError *error = nil;
	QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
	QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
		[NSDictionary dictionaryWithObjectsAndKeys: 
			ref, QTMovieDataReferenceAttribute,
			[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
			nil] error:&error] autorelease];
	if (!movie && [error code] == -2126)
	{
		//NSLog(@"Failed to load DRMd QTMovie: %@", error);
		[previewMovieView removeFromSuperview];
		[previewMovieView setMovie:nil];
	}
	else
	{
		[previewMovieView setMovie:movie];
		if (![previewMovieView superview])
		{
			[oPhotoView addSubview:previewMovieView];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(viewResized:)
														 name:NSViewFrameDidChangeNotification
													   object:oPhotoView];
		}
	}
}

@end
