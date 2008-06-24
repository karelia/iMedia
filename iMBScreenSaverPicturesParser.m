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


#import "iMBScreenSaverPicturesParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "iMedia.h"

@implementation iMBScreenSaverPicturesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaConfiguration registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}



- (void)parseWithNode:(iMBLibraryNode *)root	// path is ignored, not recursive!
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSAllDomainsMask,YES);
	NSEnumerator *pathEnum = [searchPaths objectEnumerator];
	NSString *libraryPath;
	NSMutableArray *screensaverPaths = [NSMutableArray array];

	// Build up all the screen savers into an array, from all locations
	
	while ((libraryPath = [pathEnum nextObject]) != nil)
	{
		NSString *ssDir = [libraryPath stringByAppendingPathComponent:@"Screen Savers"];
		NSArray *contents = [fm directoryContentsAtPath:ssDir];
		NSEnumerator *e = [contents objectEnumerator];
		NSString *cur;
		BOOL isDir;
		
		while (cur = [e nextObject])
		{
			NSString *filePath = [ssDir stringByAppendingPathComponent: cur];
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir]
				&& isDir
				&& [@"slideSaver" isEqualToString:[cur pathExtension]])
			{
				NSString *fullPath = [ssDir stringByAppendingPathComponent:cur];
				[screensaverPaths addObject:fullPath];
			}
		}
	}
	NSEnumerator *ssEnum = [screensaverPaths objectEnumerator];
	NSString *ssPath;

	// Go through each screen saver
	
	while ((ssPath = [ssEnum nextObject]) != nil)
	{
		NSString *imageFolderPath = [ssPath stringByAppendingPathComponent:@"Contents/Resources"];
		
		// Now give me all image in there please
		NSArray *ssContents = [fm directoryContentsAtPath:imageFolderPath];
		NSEnumerator *ssFilesEnum = [ssContents objectEnumerator];
		NSString *aFileName;
		NSMutableArray *images = [NSMutableArray array];

		while ((aFileName = [ssFilesEnum nextObject]) != nil)
		{
			NSString *filePath = [imageFolderPath stringByAppendingPathComponent:aFileName];
			BOOL isDir;
			if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && ![fm isPathHidden:filePath] && !isDir)
			{
				
				NSString *UTI = [NSString UTIForFileAtPath:filePath];
				if ([NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage])
				{
					NSMutableDictionary *newPicture = [NSMutableDictionary dictionary]; 
					if (filePath)
					{
						[newPicture setObject:filePath forKey:@"ImagePath"];
						[newPicture setObject:[fm displayNameAtPath:filePath] forKey:@"Caption"];
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
		if ([images count])
		{
			iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
			[root addItem:folder];
			[folder release];
			[folder setIconName:@"folder"];
			[folder setName:[fm displayNameAtPath:[ssPath stringByDeletingPathExtension]]];
			
			// Collected images, set.
			[folder setAttribute:images forKey:@"Images"];
		}
	}
	// done each screen saver
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInIMedia(@"Screen Savers", @"Screen Savers -- source of some images in iMedia")];
	[root setIconName:@"folder"];
		
	[self parseWithNode:root];
	
	return [root autorelease];
}

@end

