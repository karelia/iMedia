/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBFolderParser.h"
#import "IMBConfig.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBFolderObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFolderParser

@synthesize fileUTI = _fileUTI;
@synthesize displayPriority = _displayPriority;
@synthesize isUserAdded = _isUserAdded;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.fileUTI = nil;
		self.displayPriority = 5;	// default middle-of-the-pack priority
		self.isUserAdded = NO;
	}
	
	return self;
}

- (void) dealloc
{
	IMBRelease(_fileUTI);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	NSError* error = nil;
	NSFileManager* fileManager = [NSFileManager imb_threadSafeManager];
	NSURL* url = self.mediaSource;
	NSString* path = [[url path] stringByStandardizingPath];
	
	// Check if the folder exists. If not then do not return a node...
	
	BOOL exists,directory;
	exists = [fileManager fileExistsAtPath:path isDirectory:&directory];
	
	if (!exists || !directory) 
	{
		if (outError)
		{
			NSString* description = [NSString stringWithFormat:@"Folder doesn't exist: %@",path];
			NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
			*outError = [NSError errorWithDomain:kIMBErrorDomain code:dirNFErr userInfo:info];
		}
		
		return nil;
	}	

	// Create an empty root node (unpopulated and without subnodes)...
	
	NSString* name = [fileManager displayNameAtPath:[path stringByDeletingPathExtension]];
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];

	NSUInteger countOfSubfolders = [self countOfSubfoldersInFolder:url error:&error];

	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	node.icon = [self iconForPath:path];
	node.name = name;
	node.identifier = [self identifierForPath:path];
	node.mediaType = self.mediaType;
	node.mediaSource = url;
	node.isTopLevelNode = YES;
	node.isLeafNode = countOfSubfolders == 0;
	node.displayPriority = self.displayPriority;
	node.isUserAdded = self.isUserAdded;
	node.parserIdentifier = self.identifier;
	
	if (node.isTopLevelNode)
	{
		node.groupType = kIMBGroupTypeFolder;
		node.isIncludedInPopup = YES;
	}
	else
	{
		node.groupType = kIMBGroupTypeNone;
		node.isIncludedInPopup = NO;
	}
	
	// Enable FSEvents based file watching for root nodes...
	
	node.watcherType = kIMBWatcherTypeFSEvent;
	node.watchedPath = path;
	
	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSError* error = nil;
	NSFileManager* fileManager = [NSFileManager imb_threadSafeManager];
	NSAutoreleasePool* pool = nil;
	NSInteger index = 0;
	
	// Scan the folder for files and directories...
	
	NSArray* urls = [fileManager contentsOfDirectoryAtURL:
		inNode.mediaSource 
		includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLLocalizedNameKey,NSURLIsDirectoryKey,NSURLIsPackageKey,nil] 
		options:NSDirectoryEnumerationSkipsHiddenFiles 
		error:&error];

	if (error == nil)
	{
		NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
		NSMutableArray* objects = [NSMutableArray arrayWithCapacity:urls.count];
		NSMutableArray* folders = [NSMutableArray array];
		inNode.displayedObjectCount = 0;
		
		for (NSURL* url in urls)
		{
			if (index%32 == 0)
			{
				IMBDrain(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}

			// Get some info about the file or folder...
			
			NSString* path = [url path];

			NSString* localizedName = nil;
			[url getResourceValue:&localizedName forKey:NSURLLocalizedNameKey error:&error];
			if (error) break;
			
			NSNumber* isDirectory = nil;
			[url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
			if (error) break;

			NSNumber* isPackage = nil;
			[url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:&error];
			if (error) break;
			
			// If we found a folder (that is not a package, then remember it for later. Folders will be added
			// after regular files...
			
			if ([isDirectory boolValue] && ![isPackage boolValue])
			{
				if (![IMBConfig isLibraryPath:path])
				{
					[folders addObject:url];
				}
				else
				{
					// NSLog(@"IGNORING LIBRARY PATH: %@", path);
				}
			}
			
			// Regular files are added immediately (if they have the correct UTI)...
			
			else if ([NSString imb_doesFileAtPath:path conformToUTI:_fileUTI])
			{
				IMBObject* object = [self objectForURL:url name:localizedName index:index++];
				[objects addObject:object];
				inNode.displayedObjectCount++;
			}
		}
				
		// Now we can actually handle the folders. Add a subnode and an IMBNodeObject for each folder...
				
		for (NSURL* url in folders)
		{
			if (index%32 == 0)
			{
				IMBDrain(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			NSString* path = [url path];
			NSString* name = [fileManager displayNameAtPath:path];
			NSUInteger countOfSubfolders = [self countOfSubfoldersInFolder:url error:&error];
			if (error) break;
			
			IMBNode* subnode = [[IMBNode alloc] init];
			subnode.icon = [self iconForPath:path];
			subnode.name = name;
			subnode.identifier = [self identifierForPath:path];
			subnode.mediaType = self.mediaType;
			subnode.mediaSource = url;
			subnode.parserIdentifier = self.identifier;
			subnode.isTopLevelNode = NO;
			subnode.isLeafNode = countOfSubfolders == 0;
			subnode.groupType = kIMBGroupTypeFolder;
			subnode.isIncludedInPopup = NO;
			subnode.watchedPath = path;					// These two lines are important to make file watching work for nested 
			subnode.watcherType = kIMBWatcherTypeNone;	// subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
			[subnodes addObject:subnode];
			[subnode release];

			IMBFolderObject* object = [[IMBFolderObject alloc] init];
			object.representedNodeIdentifier = subnode.identifier;
			object.location = (id)url;
			object.name = name;
			object.metadata = nil;
			object.parserIdentifier = self.identifier;
			object.index = index++;
			[objects addObject:object];
			[object release];
		}
		
		inNode.objects = objects;
		inNode.isLeafNode = [subnodes count] == 0;
	}
	
	IMBDrain(pool);
	if (outError) *outError = error;
}


//----------------------------------------------------------------------------------------------------------------------


// Since we know that we have local files we can use the helper method supplied by the base class...

- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return [self bookmarkForLocalFileObject:inObject error:outError];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


- (IMBObject*) objectForURL:(NSString*)inURL name:(NSString*)inName index:(NSUInteger)inIndex;
{
	IMBObject* object = [[[IMBObject alloc] init] autorelease];
	object.location = (id)inURL;
	object.name = inName;
	object.parserIdentifier = self.identifier;
	object.index = inIndex;
	
	object.imageRepresentationType = IKImageBrowserCGImageRepresentationType; 
	object.imageLocation = nil;             // will be loaded lazily when needed
	object.imageRepresentation = nil;		// will be loaded lazily when needed
	object.metadata = nil;					// will be loaded lazily when needed
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


// Return the number of (visible) subfolders in a given folder...

- (NSUInteger) countOfSubfoldersInFolder:(NSURL*)inFolderURL error:(NSError**)outError
{
	NSError* error = nil;
	NSFileManager* fileManager = [NSFileManager imb_threadSafeManager];
	NSUInteger count = 0;
	
	NSArray* urls = [fileManager contentsOfDirectoryAtURL:
		inFolderURL 
		includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey,NSURLIsPackageKey,nil] 
		options:NSDirectoryEnumerationSkipsHiddenFiles 
		error:&error];

	if (error == nil)
	{
		for (NSURL* url in urls)
		{
			NSNumber* folder = nil;
			[url getResourceValue:&folder forKey:NSURLIsDirectoryKey error:&error];
			if (error) break;

			NSNumber* package = nil;
			[url getResourceValue:&package forKey:NSURLIsPackageKey error:&error];
			if (error) break;
			
			if ([folder boolValue]==YES && [package boolValue]==NO)
			{
				count++;
			}
		}
	}

	if (outError) *outError = error;
	return count;
}


//----------------------------------------------------------------------------------------------------------------------


@end
