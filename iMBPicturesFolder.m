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
#import "NSWorkspace+Extensions.h"
#import "iMBLibraryNode.h"
#import "NSString+UTI.h"
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
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSMutableArray *images = [NSMutableArray array];
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		NSDictionary *fileAttribs = [fm fileAttributesAtPath:filePath traverseLink:YES];
		NSString *fileName = [filePath lastPathComponent];
		
		if ([fileName rangeOfString:@"iPhoto Library"].location != NSNotFound) continue;
		if ([fileName rangeOfString:@"Aperture Library"].location != NSNotFound) continue;
		if ([fileName hasPrefix:@"."]) continue;		// invisible
#warning TODO: Better check for invisible files; e.g. http://www.cocoabuilder.com/archive/message/cocoa/2003/6/17/86040
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[fm displayNameAtPath:[cur lastPathComponent]]];
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
					[newPicture setObject:[fm displayNameAtPath:[filePath lastPathComponent]] forKey:@"Caption"];
					[newPicture setObject:filePath forKey:@"ThumbPath"];
				}
				if ([fileAttribs valueForKey:NSFileModificationDate])
				{
					[newPicture setObject:[NSNumber numberWithDouble:[[fileAttribs valueForKey:NSFileModificationDate] timeIntervalSinceReferenceDate]]
                                                              forKey:@"DateAsTimeInterval"];
				}
				[images addObject:newPicture];
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
	
	[self recursivelyParse:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"] 
				  withNode:root];

	return [root autorelease];
}

@end
