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


#import "iMBPicturesFolder.h"
#import "iMediaBrowser.h"
#import "iMBLibraryNode.h"

@implementation iMBPicturesFolder

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}


- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingString:@"/Pictures/"]])
	{
		
	}
	return self;
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSArray *imageTypes = [NSImage imageFileTypes];
	NSMutableArray *images = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingFormat:@"/%@", cur];
		
		if ([filePath rangeOfString:@"iPhoto Library"].location != NSNotFound) continue;
		if ([filePath rangeOfString:@"Aperture Library"].location != NSNotFound) continue;
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[cur lastPathComponent]];
			[self recursivelyParse:filePath withNode:folder];
		}
		else
		{
			if ([imageTypes indexOfObject:[[filePath lowercaseString] pathExtension]] != NSNotFound)
			{
				NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
				
				NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
				[newPicture setObject:filePath forKey:@"ImagePath"];
				[newPicture setObject:[filePath lastPathComponent] forKey:@"Caption"];
				[newPicture setObject:filePath forKey:@"ThumbPath"];
				[newPicture setObject:[fileAttribs valueForKey:NSFileModificationDate] forKey:@"DateAsTimerInterval"];
				[images addObject:newPicture];
			}
		}
	}
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:NSLocalizedString(@"Pictures Folder", @"Node name")];
	[root setIconName:@"picturesFolder"];
	
	[self recursivelyParse:[NSHomeDirectory() stringByAppendingString:@"/Pictures/"] 
				  withNode:root];

	return [root autorelease];
}

@end
