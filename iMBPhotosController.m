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

#import "iMBPhotosController.h"
#import "iMediaBrowser.h"
#import "iMBPhotoView.h"
#import "Library.h"

@interface iMBPhotosController (PrivateAPI)
- (NSString *)iconNameForPlaylist:(NSString*)name;
@end

@implementation iMBPhotosController

- (id) initWithPlaylistController:(NSTreeController*)ctrl
{
	if (self = [super init]) {
		playlistController = [ctrl retain];
		[NSBundle loadNibNamed:@"iPhoto" owner:self];
	}
	return self;
}

- (void)dealloc
{
	[playlistController release];
	[super dealloc];
}

- (NSArray*)loadDatabase
{
	NSMutableDictionary *library = [NSMutableDictionary dictionary];
	NSMutableArray *photoLists = [NSMutableArray array];
	
	//Find all iPhoto libraries
	CFPropertyListRef iApps = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",
														(CFStringRef)@"com.apple.iApps");
	
	//Iterate over libraries, pulling dictionary from contents and adding to array for processing;
	NSArray *libraries = (NSArray *)iApps;
	NSEnumerator *e = [libraries objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		NSDictionary *db = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:cur]];
		if (db) {
			[library addEntriesFromDictionary:db];
		}
	}
	[libraries autorelease];
	
	NSDictionary *imageRecords = [library objectForKey:@"Master Image List"];
	NSDictionary *keywordMap = [library objectForKey:@"List of Keywords"];
	NSEnumerator *albumEnum = [[library objectForKey:@"List of Albums"] objectEnumerator];
	NSDictionary *albumRec;
	
	//Parse dictionary creating libraries, and filling with track infromation
	while (albumRec = [albumEnum nextObject])
	{
		Library *lib = [[Library alloc] init];
		[lib setName:[albumRec objectForKey:@"AlbumName"]];
		[lib setLibraryImageName:[self iconNameForPlaylist:[lib name]]];
		
		NSMutableDictionary *newPhotolist = [NSMutableDictionary dictionary];
		NSArray * pictureItems = [albumRec objectForKey:@"KeyList"];
		NSEnumerator *pictureItemsIter = [pictureItems objectEnumerator];
		NSString *key;
		
		while (key = [pictureItemsIter nextObject])
		{
			NSDictionary *imageRecord = [imageRecords objectForKey:key];
			[newPhotolist setObject:imageRecord forKey:key];
			//swap the keyword index to names
			NSArray *keywords = [imageRecord objectForKey:@"Keywords"];
			if ([keywords count] > 0) {
				NSEnumerator *keywordEnum = [keywords objectEnumerator];
				NSString *keywordKey;
				NSMutableArray *realKeywords = [NSMutableArray array];
				
				while (keywordKey = [keywordEnum nextObject]) {
					NSString *actualKeyword = [keywordMap objectForKey:keywordKey];
					[realKeywords addObject:actualKeyword];
				}
				
				NSMutableDictionary *mutatedKeywordRecord = [NSMutableDictionary dictionaryWithDictionary:imageRecord];
				[mutatedKeywordRecord setObject:realKeywords forKey:@"iMediaKeywords"];
				[newPhotolist setObject:mutatedKeywordRecord forKey:key];
			}
			
		}
		[lib addLibraryItem:newPhotolist];
		[photoLists addObject:lib];
		[lib release];
	}
	
	//Do the pictures folder
	Library *lib = [[Library alloc] init];
	[lib setName:@"Pictures Folder"];
	[lib setLibraryImageName:[self iconNameForPlaylist:[lib name]]];
	
	NSArray *dirContents = [[NSFileManager defaultManager] subpathsAtPath:[NSHomeDirectory() stringByAppendingString:@"/Pictures/"]];
	NSMutableArray * picturesFolder = [NSMutableArray arrayWithArray:dirContents];
	NSMutableArray * picturesRemaining = [[NSMutableArray array] retain];
	int count = [picturesFolder count];
	NSArray *availableTypes = [NSImage imageFileTypes];
	
	int x;
	for (x = 0; x < count; x++)
	{
		NSString *ext = [[[picturesFolder objectAtIndex:x] pathExtension] lowercaseString];
		if ([availableTypes indexOfObject:ext] != NSNotFound)
			[picturesRemaining addObject:[picturesFolder objectAtIndex:x]];
	}
	
	NSMutableDictionary * picsFolderList = [[NSMutableDictionary dictionary] retain];
	
	for (x=0;x<[picturesRemaining count];x++)
	{
		NSNumber * stringNumber = [NSNumber numberWithInt:x];
		NSMutableDictionary * newPicture = [NSMutableDictionary dictionary];
		NSMutableString * pathString = [NSMutableString stringWithString:[picturesRemaining objectAtIndex:x]];
		[pathString replaceOccurrencesOfString:@"%20" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [pathString length])];
		[pathString replaceOccurrencesOfString:@"%5B" withString:@"[" options:NSLiteralSearch range:NSMakeRange(0, [pathString length])];
		[pathString replaceOccurrencesOfString:@"%5D" withString:@"]" options:NSLiteralSearch range:NSMakeRange(0, [pathString length])];
		NSArray * pathComps = [pathString pathComponents];
		
		if ([[pathComps objectAtIndex:0] isEqualToString:@"iPhoto Library"]) continue;
		
		NSString * slashChar = [NSHomeDirectory() stringByAppendingString:[@"/Pictures" stringByAppendingString:[NSString stringWithString:@"/"]]];
		NSString * finalPath = [slashChar stringByAppendingString:[NSString pathWithComponents:pathComps]];
		
		NSDictionary *fileAttribs = [[NSFileManager defaultManager] fileAttributesAtPath:finalPath traverseLink:YES];
		
		// add items to dictionary
		[newPicture setObject:finalPath forKey:@"ImagePath"];
		[newPicture setObject:[finalPath lastPathComponent] forKey:@"Caption"];
		[newPicture setObject:finalPath forKey:@"ThumbPath"];
		[newPicture setObject:[fileAttribs valueForKey:NSFileModificationDate] forKey:@"DateAsTimerInterval"];
		[picsFolderList setObject:newPicture forKey:[stringNumber stringValue]];
	}
	[lib addLibraryItem:picsFolderList];
	[photoLists addObject:lib];
	[lib release];
	return photoLists;
}

- (void)awakeFromNib
{	
	//Bind images array of photo view to the current library selection
	[oPhotoView bind:@"images" 
			toObject:playlistController 
		 withKeyPath:@"selection.libraryItems" 
			 options:[NSDictionary dictionaryWithObject:[NSValueTransformer valueTransformerForName:@"libraryItemsValueTransformer"]
												 forKey:NSValueTransformerBindingOption]];
}

#pragma mark -
#pragma mark Media Browser Protocol

static NSImage *_iphotoIcon = nil;

- (NSImage *)menuIcon
{
	if (!_iphotoIcon) {
		NSBundle *b = [NSBundle bundleForClass:[self class]];
		NSString *p = [b pathForResource:@"photo_tiny" ofType:@"png"];
		_iphotoIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _iphotoIcon;
}

- (NSString *)name
{
	return NSLocalizedString(@"iPhoto", @"iPhoto");
}

- (NSView *)browserView
{
	return oView;
}

- (void)didDeactivate
{
	[oView unbind:@"images"];
}

- (NSString *)iconNameForPlaylist:(NSString*)name
{
	if ([name hasSuffix:@"Roll"])
		return @"MBiPhotoRoll";
	else if ([name hasSuffix:@"Rolls"])
		return @"MBiPhotoRoll";
	else if ([name hasSuffix:@"Month"])
		return @"MBiPhotoCalendar";
	else if ([name hasSuffix:@"Months"])
		return @"MBiPhotoCalendar";
	else if ([name isEqualToString:@"Library"])
		return @"MBiPhotoLibrary";
	else if ([name isEqualToString:@"Pictures Folder"])
		return @"picturesFolder";
	else
		return @"MBiPhotoAlbum";
}
@end
