/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/

#import "iMBMoviesView.h"

#import <QTKit/QTKit.h>
#import "iMBLibraryNode.h"
#import "MUPhotoView.h"
#import "iMBMovieCacheDB.h"
#import "iMBMovieReference.h"
#import "iMediaConfiguration.h"
#import "NSString+iMedia.h"
#import "NSPasteboard+iMedia.h"
#import "NSWorkspace+iMedia.h"

#define MAX_POSTER_SIZE (NSMakeSize(240, 180))	// our thumbnail view maxes out at 240.

@interface iMBMoviesView (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
- (NSArray*) selectedItems;
- (NSDictionary *)displayableAttributesOfMovie:(QTMovie *)aMovie;
- (NSString *)imageCountPluralityAdjustedString;
@end

@implementation iMBMoviesView

+ (void)initialize
{
	if ( self == [iMBMoviesView class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize
	[iMBMoviesView setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
}
}

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
		mySelection = [[NSMutableIndexSet allocWithZone:[self zone]] init];
		myFilteredImages = [[NSMutableArray allocWithZone:[self zone]] init];
		myImageCache = [[NSMutableDictionary dictionary] retain];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(posterImageWasLoaded:) name:kMBMovieCacheLoadedPosterImageNotification object:nil];        
	}
	return self;
}

- (void)dealloc
{
	[counterField unbind:@"displayPatternValue2"];
	[counterField unbind:@"displayPatternValue1"];

	[previewMovieView release];
	[mySelection release];
	[myImages release];
	[myFilteredImages release];
	[mySearchString release];
	[myImageCache release];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
    
	[super dealloc];
}

- (void)finalize
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super finalize];
}

- (void)loadViewNib
{
	[super loadViewNib];
	finishedInit = YES; // so we know when the abstract view has finished so awakeFromNib doesn't get called twice
	[NSBundle loadNibNamed:@"Movies" owner:self];
}

- (void)awakeFromNib
{
    if ( finishedInit )
    {
        [super awakeFromNib];
        
		[oPhotoView setDelegate:self];
		[oPhotoView setUseOutlineBorder:NO];
		[oPhotoView setUseHighQualityResize:NO];
		
		[oPhotoView setBackgroundColor:[NSColor whiteColor]];
		
		[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
		[oPhotoView setPhotoHorizontalSpacing:15];
		[oPhotoView setPhotoVerticalSpacing:15];
			
		[oPhotoView setShowCaptions:[[iMediaConfiguration sharedConfiguration] prefersFilenamesInPhotoBasedBrowsers]];

		NSDictionary *optionsDict =
		[NSDictionary dictionaryWithObject:@"%{value1}@ %{value2}@"  
									forKey:NSDisplayPatternBindingOption];
		
		[counterField bind:@"displayPatternValue1"
				  toObject:self
			   withKeyPath:@"imageCount"
				   options:optionsDict];

		[counterField bind:@"displayPatternValue2"
				  toObject:self
			   withKeyPath:@"imageCountPluralityAdjustedString"
				   options:optionsDict];
		// It would be nice to also indicate # selected if there is a selection.  How to do with bindings?
    }
}

- (void)posterImageWasLoaded:(NSNotification *)notification
{
    [oPhotoView setNeedsDisplay:YES];
}

- (IBAction)play:(id)sender
{
	[previewMovieView play:sender];
}

- (void)viewResized:(NSNotification *)n
{
	NSRect r = [oPhotoView photoRectForIndex:movieIndex];
	[previewMovieView setFrame:r];
}

- (void)refilter
{
	[self willChangeValueForKey:@"images"];
	[mySelection removeAllIndexes];
	[myFilteredImages removeAllObjects];
	[self postSelectionChangeNotification:[self selectedItems]];

	if ([mySearchString length] == 0) return;
	
	iMBLibraryNode *selectedNode = [[[self controller] selectedObjects] lastObject];
	
	[myFilteredImages addObjectsFromArray:[selectedNode searchAttribute:@"Movies" withKeys:[NSArray arrayWithObjects:@"Caption", @"ImagePath", nil] matching:mySearchString]];
	
	[self didChangeValueForKey:@"images"];
}

- (IBAction)search:(id)sender
{
	[mySearchString autorelease];
	mySearchString = [[sender stringValue] copy];
	
	[self refilter];
	[oPhotoView setNeedsDisplay:YES];
}

- (NSNumber *)imageCount
{
	int count;
	if ([mySearchString length] > 0)
	{
		count = [myFilteredImages count];
	}
	else
	{
		count = [myImages count];
	}
	
	return [NSNumber numberWithUnsignedInt:count];
}

- (void)setImageCount:(NSNumber *)count 
{
	// do nothing
}

- (NSArray*) selectedItems
{
	NSArray* records = nil;
	if ([mySearchString length] > 0)
	{
		records = [myFilteredImages objectsAtIndexes:mySelection];
	}
	else
	{
		records = [myImages objectsAtIndexes:mySelection];
	}
	return records;
}

- (NSString *)imageCountPluralityAdjustedString
{
	int count = [[self imageCount] intValue];
	
	return abs(count) != 1 ? LocalizedStringInIMedia(@"movies", @"plural form for showing how many items there are") :  LocalizedStringInIMedia(@"movie", @"singular form for showing how many items there are");
}


#pragma mark -
#pragma mark Media Browser Protocol

- (Class)parserForFolderDrop
{
	return NSClassFromString(@"iMBMoviesFolder");
}

- (void)willActivate
{
	[super willActivate];
	[self bind:@"images" 
	  toObject:[self controller] 
		 withKeyPath:@"selection.Movies" 
	   options:nil];
}

- (void)didDeactivate
{
	[self unbind:@"images"];
	[previewMovieView pause:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[previewMovieView removeFromSuperview];
    [super didDeactivate];
}


static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
        NSString *path = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarMovieFolderIcon.icns";
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            _toolbarIcon = [[NSImage allocWithZone:[self zone]] initByReferencingFile:path];
            if (_toolbarIcon)
                return _toolbarIcon;
        }
        
		// Try to use iMovie, or older iMovie, or quicktime player for movies.
		NSString *identifier = @"com.apple.iMovie";
		path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:identifier];
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
	return LocalizedStringInIMedia(@"Movies", @"Name of Data Type");
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	return @"MBQuicktime.png";
}

- (void)writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *names = [NSMutableArray array];
	
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[items count]];
	while (cur = [e nextObject])
	{
      [nativeDataArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
         [cur objectForKey:@"ImagePath"], @"ImagePath",
         [cur objectForKey:@"Caption"], @"Caption",
         nil]];
         
		[files addObject:[cur objectForKey:@"ImagePath"]];
		[names addObject:[cur objectForKey:@"Caption"]];
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
   [pboard writeURLs:nil files:files names:names];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	[self writeItems:[playlist valueForKey:@"Movies"] toPasteboard:pboard];
}

#pragma mark -
#pragma mark Threaded Image Loading

- (NSDictionary *)recordForPath:(NSString *)path
{
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([[cur objectForKey:@"Preview"] isEqualToString:path])
		{
			return cur;
		}
	}
	return nil;
}

- (NSDictionary *)displayableAttributesOfMovie:(QTMovie *)aMovie
{
	NSDictionary *attr = [aMovie movieAttributes];
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	
	NSArray *keys = [NSArray arrayWithObjects:
		QTMovieDisplayNameAttribute, QTMovieCopyrightAttribute, 
		QTMovieCreationTimeAttribute,
		QTMovieHasDurationAttribute, QTMovieDurationAttribute,
		QTMovieNaturalSizeAttribute, 
		nil];
	NSEnumerator *enumerator = [keys objectEnumerator];
	NSString *key;

	while ((key = [enumerator nextObject]) != nil)
	{
		id value = [attr objectForKey:key];
		if (value && (value != [NSNull null]))
		{
			[result setObject:value forKey:key];
		}
	}
	return [NSDictionary dictionaryWithDictionary:result];
}
	

#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	[self refilter];
	//reset the scroll position
	[previewMovieView removeFromSuperview];
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

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)aIndex
{
	NSMutableDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
    
	//try the caches
	NSString *imagePath = [rec objectForKey:@"Preview"];
	NSImage *img = [myImageCache objectForKey:imagePath];		// preview image is keyed by the path of the preview
	
    if (!img)
    {   // Perhaps there's a ThumbPath
        NSString *thumbPath = [rec objectForKey:@"ThumbPath"];
        if (thumbPath)
        {
            img = [[[NSImage alloc] initByReferencingFile:thumbPath] autorelease];
            if (img)
                [myImageCache setObject:img forKey:imagePath];
        }
    }

	if (!img && (img != (NSImage *)[NSNull null]))	// need to generate, but not if NSNull
    {		
        iMBMovieReference    *movieRef = [[iMBMovieCacheDB sharedMovieCacheDB] movieReferenceWithURL:[NSURL fileURLWithPath:imagePath]];
        img = [movieRef posterImage];
        if (img)
        {
            [myImageCache setObject:img forKey:imagePath];
            // No movie could be generated, so also no metadata
        }
        else
            img = [[NSWorkspace sharedWorkspace] iconForFile:imagePath];
        NSDictionary    *movieAttributes = [movieRef movieAttributes];
        if (movieAttributes)
        {
            [rec setObject:movieAttributes forKey:@"movieAttributes"];
            NSString    *displayName = [movieAttributes objectForKey:QTMovieDisplayNameAttribute];
            if (displayName && [displayName length] > 0)
                [rec setObject:displayName forKey:@"Caption"];
        }
	}
	if (img == (NSImage *)[NSNull null])	img = nil;	// don't return NSNull
	
	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
	[self postSelectionChangeNotification:[self selectedItems]];
}

- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view
{
	return mySelection;
}

- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

// MUPHOTOVIEW STYLE

- (NSArray *)pasteboardDragTypesForPhotoView:(MUPhotoView *)view
{
    return [[[NSArray alloc] init] autorelease];
}

- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)aIndex dataType:(NSString *)type
{
    return nil;
}

// OUR STYLE

- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard
{
	NSMutableArray *fileList = [NSMutableArray array];
	NSMutableArray *captions = [NSMutableArray array];
	
	NSMutableArray *types = [NSMutableArray array]; 
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[pboard declareTypes:types owner:nil];
	
	NSDictionary *cur;
	
	unsigned int i;
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

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)aIndex
{
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
	return [rec objectForKey:@"Caption"];
}

// called in thread 1 so it's safe to open the movie for more info.
// BETTER YET -- PUT THE MOVIE METADATA WITH THE CACHED THUMBNAIL SO WE DON'T HAVE TO OPEN UP MOVIE AS WELL.
- (NSString *)photoView:(MUPhotoView *)view tooltipForPhotoAtIndex:(unsigned)aIndex
{
	NSMutableString *result = [NSMutableString string];
	NSDictionary *rec;
	if ([mySearchString length] > 0)
	{
		rec = [myFilteredImages objectAtIndex:aIndex];
	}
	else
	{
		rec = [myImages objectAtIndex:aIndex];
	}
	
	// GET METADATA, WE MIGHT USE THAT FOR DISPLAY NAME INSTEAD OF "Caption"
	NSDictionary *userInfo = [rec objectForKey:@"movieAttributes"];
	NSString *title = [rec objectForKey:@"Caption"];	// default
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	NSString *imagePathUTI = nil;
	
	// Don't have User Info from cache?  Try to get it from the movie itself
	// TODO: Attributes generated from a movie file for the tooltip are not cached in memory.
	if (!userInfo && [NSString UTI:imagePathUTI conformsToUTI:(NSString *)kUTTypeAudiovisualContent])
	{
		// Get our own User info from the file directly by making a quicktime movie.
		NSError *error = nil;
		
		///NSLog(@"photoView:tooltipForPhotoAtIndex:%@ going to load movie", imagePath);

		QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:imagePath];
		QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys: 
				ref, QTMovieDataReferenceAttribute,
				[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil] error:&error] autorelease];
		if (movie)
		{
			userInfo = [movie movieAttributes];
		}
	}
	
	// Possibly override title by using the metadata from quicktime file
	if (userInfo)
	{
		NSString *displayName = [userInfo objectForKey:QTMovieDisplayNameAttribute];
		if (displayName && ![displayName isEqual:title] && ![[NSNull null] isEqual:displayName])
		{
			title = displayName;	// and use the display name to override the title
		}
	}
	
	// APPEND THE TITLE FIRST
	[result appendString:title];	// the title of the image, often the file name.

	// APPEND SOME GENERAL ITUNES METADATA
	if ([rec objectForKey:@"Artist"]) [result appendFormat:@"\n%@", [rec objectForKey:@"Artist"]];
	if ([rec objectForKey:@"Album"]) [result appendFormat:@"\n%@", [rec objectForKey:@"Album"]];
	
	// APPEND GENERAL QUICKTIME METADATA
	if (userInfo)
	{
		NSString *copyright = [userInfo objectForKey:QTMovieCopyrightAttribute];
		if (copyright && ![[NSNull null] isEqual:copyright]) [result appendFormat:@"\n%@", copyright];
	}

	
	// ---------------------- COLLECT TECHNICAL METADATA
	
	float durationSeconds = 0.0;
	float width = 0.0;
	float height = 0.0;
	NSString *dateTimeLocalized = nil;
	
	// COLLECT TECHNICAL QUICKTIME METADATA
	if (userInfo)
	{
		NSDate *creationTime = [userInfo objectForKey:QTMovieCreationTimeAttribute];

		if (creationTime && ![[NSNull null] isEqual:creationTime])
		{
			NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
			[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
			[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds
			dateTimeLocalized = [formatter stringFromDate:creationTime];
		}
		
		NSNumber *hasDuration = [userInfo objectForKey:QTMovieHasDurationAttribute];
		NSValue *durValue = [userInfo objectForKey:QTMovieDurationAttribute];
		
		if (hasDuration && ![[NSNull null] isEqual:hasDuration] && [hasDuration boolValue] && durValue)
		{
			QTTime durTime = [durValue QTTimeValue];
			if (durTime.timeScale == 0)
				durTime.timeScale = 60;	// make sure there's a time scale
			
			durationSeconds = durTime.timeValue / durTime.timeScale;
		}
		
		NSValue *sizeValue = [userInfo objectForKey:QTMovieNaturalSizeAttribute];

		if (sizeValue && ![[NSNull null] isEqual:sizeValue])
		{
			NSSize size = [sizeValue sizeValue];
			width = size.width;
			height = size.height;
		}
	}
		
	// COLLECT TECHNICAL ITUNES METADATA
	NSNumber *iTunesDuration = [rec objectForKey:@"Total Time"];
	if (iTunesDuration)
	{
		durationSeconds = [iTunesDuration floatValue] / 1000.0;
	}
		
	// -------------------------- OUTPUT TECHNICAL METADATA

	// OUTPUT DATE/TIME
	if (dateTimeLocalized)
	{
		[result appendFormat:@"\n%@", dateTimeLocalized];
	}
	
	// OUTPUT DIMENSIONS
	if (width >= 1.0 && height >= 1.0)
	{
		NSString *dimensionsFormat = LocalizedStringInIMedia(@"\n%.0f \\U2715 %.0f", @"format for width X height");
		[result appendFormat:dimensionsFormat, width, height];
	}

	// OUTPUT DURATION	
	if (durationSeconds > 0.01)
	{
		int actualSeconds = (int) roundf(durationSeconds);
		div_t hours = div(actualSeconds,3600);
		div_t minutes = div(hours.rem,60);
		
		NSString *timeString = nil;
		// TODO: Internationalize these time strings if necessary.
		if (hours.quot == 0) {
			timeString = [NSString stringWithFormat:@"%d:%.2d", minutes.quot, minutes.rem];
		}
		else {
			timeString = [NSString stringWithFormat:@"%d:%02d:%02d", hours.quot, minutes.quot, minutes.rem];
		}
		[result appendFormat:@"\n%@", timeString];
	}		
	
	
	// --------------------- OUTPUT USER INFORMATION, IF ANY, AFTER A BLANK LINE
	
	int rating = [[rec objectForKey:@"Rating"] intValue];
	NSString *iTunesComments = [rec objectForKey:@"Comments"];
	BOOL hasITunesComment = (nil != iTunesComments && ![iTunesComments isEqualToString:@""]);
	NSString *iPhotoComment = [rec objectForKey:@"Comment"];
	BOOL hasIPhotoComment = (nil != iPhotoComment && ![iPhotoComment isEqualToString:@""]);
	NSArray *keywords = [rec objectForKey:@"iMediaKeywords"];
	BOOL hasKeywords = keywords && [keywords count];
	if (rating > 0 || hasITunesComment || hasIPhotoComment || hasKeywords)
	{
		[result appendString:@"\n"];	// extra blank line before comment or rating
		if (hasITunesComment)
		{
			[result appendFormat:@"\n%@", iTunesComments];
		}
		if (hasIPhotoComment)
		{
			[result appendFormat:@"\n%@", iPhotoComment];
		}
		if (rating > 0)
		{
			[result appendFormat:@"\n%@", 
				[NSString stringFromStarRating:rating]];
		}
		if (hasKeywords)
		{
			[result appendFormat:@"\n"];
			NSEnumerator *keywordsEnum = [keywords objectEnumerator];
			NSString *keyword;
			
			while ((keyword = [keywordsEnum nextObject]) != nil)
			{
				[result appendFormat:@"%@, ", keyword];
			}
			[result deleteCharactersInRange:NSMakeRange([result length] - 2, 2)];	// remove last comma+space
		}
	}
	return result;
}

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)aIndex withFrame:(NSRect)frame
{
	if (aIndex < [myImages count])
	{
		movieIndex = aIndex;
		if (!previewMovieView)
		{
			previewMovieView = [[QTMovieView alloc] initWithFrame:frame];
			[previewMovieView setControllerVisible:NO];
			[previewMovieView setShowsResizeIndicator:NO];
			[previewMovieView setPreservesAspectRatio:YES];
		}
		else
		{
			[previewMovieView pause:self];
		}
		[previewMovieView setFrame:frame];
		NSString *path = [[myImages objectAtIndex:aIndex] objectForKey:@"ImagePath"];
		
		NSError *error = nil;
		///NSLog(@"photoView:doubleClickOnPhotoAtIndex:%@ going to load movie", path);
		QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:path];
		QTMovie *movie = [[[QTMovie alloc] initWithAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys: 
				ref, QTMovieDataReferenceAttribute,
				[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil] error:&error] autorelease];
		if (!movie && [error code] == -2126)	// DRM, I think
		{
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
			
			// now start playing -- but after a delay to prevent a flash-frame of the movie at full size!
			[previewMovieView performSelector:@selector(play:) withObject:self afterDelay:0.0];
		}
		
		[self postSelectionChangeNotification:[self selectedItems]];
	}
}

@end
