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

@interface iMBMoviesController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBMoviesController

- (id)initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"Movies" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	[previewMovieView bind:@"images" 
				  toObject:[self controller] 
			   withKeyPath:@"selection.Movies" 
				   options:nil];
}

- (IBAction)play:(id)sender
{
	[previewMovieView play:sender];
}

#pragma mark -
#pragma mark Media Browser Protocol

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBiMovie" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"movies";
}

- (NSString *)name
{
	return LocalizedStringInThisBundle(@"Movies", @"Movies");
}

- (void)didDeactivate
{
	[previewMovieView stop:self];
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	return @"MBQuicktime.png";
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	// we don't want to overwrite any other existing types on the pboard
	NSMutableArray *types = [NSMutableArray arrayWithArray:[pboard types]];
	[types addObject:NSFilenamesPboardType];
	[types addObject:NSURLPboardType];
	
	[pboard declareTypes:types
				   owner:nil];
	
	NSEnumerator *e = [[playlist attributeForKey:@"Movies"] objectEnumerator];
	NSDictionary *cur;
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *urls = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSString *loc = [cur objectForKey:@"ImagePath"];
		
		NSURL *url = [NSURL fileURLWithPath:loc];
		
		[files addObject:[url path]];
		[urls addObject:url];
	}
	[pboard setPropertyList:files forType:NSFilenamesPboardType];
	[pboard setPropertyList:urls forType:NSURLPboardType];	
}

@end
