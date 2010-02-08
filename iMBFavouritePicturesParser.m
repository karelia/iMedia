/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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

#import "iMBFavouritePicturesParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"

@implementation iMBFavouritePicturesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaConfiguration registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}

- (id)init
{
    NSString *name = LocalizedStringInIMedia(@"Favorites", @"Favourite folder name");
    NSString *iconName = @"heart";
    NSString *folderPath = NULL;
    self = [super initWithName:name iconName:iconName folderPath:folderPath];
	if (self != NULL)
	{
	}
	return self;
}

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
	NSArray *paths = [[NSUserDefaults standardUserDefaults] arrayForKey:@"iMBFavouritePictures"];
	if ([paths count] == 0) return nil;
	
	iMBLibraryNode *rootLibraryNode = [[[iMBLibraryNode alloc] init] autorelease];
	[rootLibraryNode setName:LocalizedStringInIMedia(@"Favorites", @"Favourite folder name")];
	[rootLibraryNode setIconName:@"heart"];
	[rootLibraryNode setIdentifier:@"Favorites"];
	[rootLibraryNode setParserClassName:NSStringFromClass([self class])];
	[rootLibraryNode setWatchedPath:myDatabase];

    NSEnumerator *pathsEnumerator = [paths objectEnumerator];
	NSString *currentPath;
	
	while (currentPath = [pathsEnumerator nextObject])
    {
        NSString *name = [currentPath lastPathComponent];
        iMBLibraryNode *node = [self parseDatabaseInThread:currentPath gate:gate name:name iconName:@"folder" icon:NULL];
        if (node != NULL)
        {
            [rootLibraryNode addItem:node];
        }
    }
    
    return [NSArray arrayWithObject:rootLibraryNode];
}

@end
