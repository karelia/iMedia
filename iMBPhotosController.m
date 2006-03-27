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

#import "iMBPhotosController.h"
#import "iMediaBrowser.h"
#import "iMBPhotoView.h"
#import "iMBLibraryNode.h"

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBPhotosController

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super initWithPlaylistController:ctrl]) {
		[NSBundle loadNibNamed:@"iPhoto" owner:self];
	}
	return self;
}

- (void)dealloc
{
	[super dealloc];
}


#pragma mark -
#pragma mark Media Browser Protocol Overrides

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"MBiPhotoLibrary" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"photos";
}

- (NSString *)name
{
	return NSLocalizedString(@"Photos", @"Photos");
}

- (void)willActivate
{
	[super willActivate];
	[oPhotoView bind:@"images" 
			toObject:[self controller] 
		 withKeyPath:@"selection.Images" 
			 options:nil];
}

- (void)didDeactivate
{
	[oView unbind:@"images"];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *files = [NSMutableArray array];
	NSMutableArray *urls = [NSMutableArray array];
	NSMutableArray *images = [NSMutableArray array];
	NSMutableArray *albums = [NSMutableArray array];
	
	// we don't want to overwrite any other existing types on the pboard
	NSMutableArray *types = [NSMutableArray arrayWithArray:[pboard types]];
	[types addObject:NSFilenamesPboardType];
	[types addObject:@"ImageDataListPboardType"];
	[types addObject:NSURLPboardType];
	
	[pboard declareTypes:types
				   owner:nil];
	
	//we store the images as an attribute in the node
	NSArray *imageRecords = [playlist attributeForKey:@"Images"];
	NSEnumerator *e = [imageRecords objectEnumerator];
	NSDictionary *rec;
				
	while (rec = [e nextObject]) {
		[files addObject:[rec objectForKey:@"ImagePath"]];
		//[iphotoData setObject:rec forKey:cur]; //the key should be irrelavant
		[urls addObject:[[NSURL fileURLWithPath:[rec objectForKey:@"ImagePath"]] description]];
	}
	
	[pboard addTypes:[NSArray arrayWithObjects:@"AlbumDataListPboardType", NSFilenamesPboardType, NSURLPboardType, nil] owner:nil];
	
	NSDictionary *plist = [NSDictionary dictionaryWithObjectsAndKeys:albums, @"List of Albums", images, @"Master Image List", nil];
	[pboard setPropertyList:plist forType:@"AlbumDataListPboardType"];
	[pboard setPropertyList:files forType:NSFilenamesPboardType];
	[pboard setPropertyList:urls forType:NSURLPboardType];
	
}

@end
