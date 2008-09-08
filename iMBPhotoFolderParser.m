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


#import "iMBPhotoFolderParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSString+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"

@implementation iMBPhotoFolderParser

- (id)initWithContentsOfFile:(NSString *)file
{
	if (self = [super initWithContentsOfFile:file])
	{
        myName = [[[NSFileManager defaultManager] displayNameAtPath:file] copy];
        myIconName = nil;
	}
	return self;
}

- (id)initWithName:(NSString *)name iconName:(NSString *)iconName folderPath:(NSString *)folderPath
{
	if (self = [super initWithContentsOfFile:folderPath])
	{
        myName = [name copy];
        myIconName = [iconName copy];
	}
	return self;
}

- (void)dealloc
{
	[myName release];
	[myIconName release];
	[super dealloc];
}

- (BOOL)shouldIncludeFile:(NSString *)filename
{
    return YES;
}

- (void)recursivelyParse:(NSString *)folderPath withNode:(iMBLibraryNode *)root
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSArray *folderContents = [fileManager directoryContentsAtPath:folderPath];
	NSEnumerator *folderContentsEnumerator = [folderContents objectEnumerator];
	NSString *currentFilename;
	BOOL isDirectory;
	NSMutableArray *images = [NSMutableArray array];
	NSArray *excludedFolders = [[iMediaConfiguration sharedConfiguration] excludedFolders];
	
	while (currentFilename = [folderContentsEnumerator nextObject])
	{
		NSString *filePath = [folderPath stringByAppendingPathComponent:currentFilename];

		if ([self shouldIncludeFile:currentFilename] != YES) continue;
		if ([excludedFolders containsObject:filePath]) continue;
        
		if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && ![fileManager isPathHidden:filePath] && ![workspace isFilePackageAtPath:filePath] )
		{
			if (isDirectory)
			{
				iMBLibraryNode *folder = [[[iMBLibraryNode alloc] init] autorelease];
				[folder setIcon:[NSImage genericFolderIcon]];
				[folder setName:[fileManager displayNameAtPath:filePath]];
				[folder setIdentifier:[filePath lastPathComponent]];
				[folder setParserClassName:NSStringFromClass([self class])];
				[folder setWatchedPath:filePath];
				[root fromThreadAddItem:folder];
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
						[newPicture setObject:[[fileManager displayNameAtPath:filePath] stringByDeletingPathExtension] forKey:@"Caption"];
						//[newPicture setObject:filePath forKey:@"ThumbPath"];
					}
					NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:filePath traverseLink:YES];
					NSDate *fileModificationDate = [fileAttributes fileModificationDate];
					if (fileModificationDate)
					{
						[newPicture setObject:[NSNumber numberWithDouble:[fileModificationDate timeIntervalSinceReferenceDate]]
                                       forKey:@"DateAsTimerInterval"];
					}
					[images addObject:newPicture];
				}
			}
		}
	}
	
	[root fromThreadSetIcon:[workspace iconForFile:folderPath size:NSMakeSize(16,16)]];
	[root fromThreadSetAttribute:images forKey:@"Images"];
}

- (void)populateLibraryNode:(iMBLibraryNode *)root name:(NSString *)name databasePath:(NSString *)databasePath
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSFileManager *mgr = [NSFileManager defaultManager];
	NSString *folder = databasePath;
	
	if ( [mgr fileExistsAtPath:folder] )
    {
        [self recursivelyParse:folder withNode:root];
    }
    
    // the node is populated, so remove the 'loading' moniker. do this on the main thread to be friendly to bindings.
	[root performSelectorOnMainThread:@selector(setName:) withObject:name waitUntilDone:NO];
    
	[pool release];
}

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
    iMBLibraryNode *oneNodeParsed = [self parseDatabaseInThread:[self databasePath] gate:gate name:myName iconName:myIconName icon:NULL];
	[oneNodeParsed setIdentifier:[self databasePath]];
	
	if (oneNodeParsed)
	{
		return [NSArray arrayWithObject:oneNodeParsed];
	}
	else
	{
		return nil;
	}
}

@end
