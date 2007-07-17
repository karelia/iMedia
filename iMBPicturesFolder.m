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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/


#import "iMBPicturesFolder.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"

@implementation iMBPicturesFolder

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]])
	{
		
	}
	return self;
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSMutableArray *images = [NSMutableArray array];
   NSArray * excludedFolders = [[iMediaBrowser sharedBrowserWithoutLoading] excludedFolders];
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		
		if ([cur rangeOfString:@"iPhoto Library"].location != NSNotFound) continue;
		if ([cur rangeOfString:@"Aperture Library"].location != NSNotFound) continue;
		if ([excludedFolders containsObject:filePath]) continue;
      
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && ![fm isPathHidden:filePath] && ![ws isFilePackageAtPath:filePath] )
		{
			if (isDir)
			{
				iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
				[root addItem:folder];
				[folder release];
				[folder setIconName:@"folder"];
				[folder setName:[fm displayNameAtPath:filePath]];
				[self recursivelyParse:filePath withNode:folder];
			}
			else
			{
				NSString *UTI = [NSString UTIForFileAtPath:filePath];
				if ([NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage])
				{
					NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
					if (filePath)
					{
						[newPicture setObject:filePath forKey:@"ImagePath"];
						[newPicture setObject:[[fm displayNameAtPath:filePath] stringByDeletingPathExtension] forKey:@"Caption"];
						//[newPicture setObject:filePath forKey:@"ThumbPath"];
					}
					NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
					NSDate* modDate = [fileAttribs fileModificationDate];
					if (modDate)
					{
						[newPicture setObject:[NSNumber numberWithDouble:[modDate timeIntervalSinceReferenceDate]]
																  forKey:@"DateAsTimerInterval"];
					}
					[images addObject:newPicture];
				}
			}
		}
	}
	[root setAttribute:images forKey:@"Images"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"Pictures Folder", @"Name of your 'Pictures' folder in your home directory")];
	[root setIconName:@"picturesFolder"];
		
	if (![[NSFileManager defaultManager] fileExistsAtPath:myDatabase])
	{
		[root release];
		return nil;
	}
	
	[self recursivelyParse:myDatabase
				  withNode:root];

	return [root autorelease];
}

@end
