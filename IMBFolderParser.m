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
	NSURL* url = self.mediaSource;
	NSString* path = [[url path] stringByStandardizingPath];
	
    // Check if the folder exists. If not then do not return a node...

	NSNumber* hasSubfolders = [self directoryHasVisibleSubfolders:url error:outError];
    if (!hasSubfolders) return nil;	
    
	// Create an empty root node (unpopulated and without subnodes)...
	
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	NSString* name = [fileManager displayNameAtPath:[path stringByDeletingPathExtension]];
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    [fileManager release];

	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	node.icon = [self iconForItemAtURL:url error:NULL];
	node.name = name;
	node.identifier = [self identifierForPath:path];
	node.mediaType = self.mediaType;
	node.mediaSource = url;
	node.isTopLevelNode = YES;
	node.isLeafNode = ![hasSubfolders boolValue];
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
	
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSError* error = nil;
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	NSAutoreleasePool* pool = nil;
	NSInteger index = 0;
	BOOL ok;
    BOOL result = YES;
	
	// Scan the folder for files and directories...
	
	NSArray* urls = [fileManager contentsOfDirectoryAtURL:
		inNode.mediaSource 
		includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLLocalizedNameKey,NSURLIsDirectoryKey,NSURLIsPackageKey,nil] 
		options:NSDirectoryEnumerationSkipsHiddenFiles 
		error:&error];
    
    [fileManager release];

	if (urls)
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
			
			NSString* localizedName = nil;
			ok = [url getResourceValue:&localizedName forKey:NSURLLocalizedNameKey error:&error];
			if (!ok) continue;
			
			NSNumber* isDirectory = nil;
			ok = [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
			if (!ok) continue;

			NSNumber* isPackage = nil;
			ok = [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:&error];
			if (!ok) continue;
			
			// If we found a folder (that is not a package, then remember it for later. Folders will be added
			// after regular files...
			
			if ([isDirectory boolValue] && ![isPackage boolValue])
			{
				if (![IMBConfig isLibraryAtURL:url])
				{
					[folders addObject:url];
				}
				else
				{
					// NSLog(@"IGNORING LIBRARY PATH: %@", path);
				}
			}
			
			// Regular files are added immediately (if they have the correct UTI)...
			
            NSString *type;
            ok = [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error];
			
            if (ok && UTTypeConformsTo((CFStringRef)type, (CFStringRef)_fileUTI))
            {
				IMBObject* object = [self objectForURL:url name:localizedName index:index++];
				[objects addObject:object];
				inNode.displayedObjectCount++;
			}
		}
				
		IMBDrain(pool);

		// Now we can actually handle the folders. Add a subnode and an IMBNodeObject for each folder...
				
		for (NSURL* url in folders)
		{
			if (index%32 == 0)
			{
				IMBDrain(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			NSString* name;
			if (![url getResourceValue:&name forKey:NSURLLocalizedNameKey error:&error]) continue;
			
			NSNumber* hasSubfolders = [self directoryHasVisibleSubfolders:url error:&error];
			if (!hasSubfolders) continue;
			
			IMBNode* subnode = [[IMBNode alloc] init];
			subnode.icon = [self iconForItemAtURL:url error:NULL];
			subnode.name = name;
			
            NSString* path = [url path];
			subnode.identifier = [self identifierForPath:path];
            
			subnode.mediaType = self.mediaType;
			subnode.mediaSource = url;
			subnode.parserIdentifier = self.identifier;
			subnode.isTopLevelNode = NO;
			subnode.isLeafNode = ![hasSubfolders boolValue];
			subnode.groupType = kIMBGroupTypeFolder;
			subnode.isIncludedInPopup = NO;
			subnode.watchedPath = path;					// These two lines are important to make file watching work for nested 
			subnode.watcherType = kIMBWatcherTypeNone;	// subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
			
            [subnodes addObject:subnode];
			[subnode release];

			IMBFolderObject* object = [[IMBFolderObject alloc] init];
			object.representedNodeIdentifier = subnode.identifier;
			object.location = url;
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
	else
    {
        result = NO;
    }
	
    IMBDrain(pool);
	return result;
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


// This method must return an appropriate prefix for IMBObject identifiers. Refer to the method
// -[IMBParser iMedia2PersistentResourceIdentifierForObject:] to see how it is used. Historically we used class names as the prefix. 
// However, during the evolution of iMedia class names can change and identifier string would thus also change. 
// This is undesirable, as things that depend of the immutability of identifier strings would break. One such 
// example are the object badges, which use object identifiers. To guarrantee backward compatibilty, a parser 
// class must override this method to return a prefix that matches the historic class name...

- (NSString*) iMedia2PersistentResourceIdentifierPrefix
{
	return @"IMBFolderParser";
}


- (IMBObject*) objectForURL:(NSURL*)inURL name:(NSString*)inName index:(NSUInteger)inIndex;
{
	IMBObject* object = [[[IMBObject alloc] init] autorelease];
	object.location = inURL;
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


// @YES if there is at least one visible subfolder
// @NO if there are definitely none, perhaps because the URL isn't even a directory
// nil if couldn't tell, in which case error pointer is filled in

- (NSNumber*) directoryHasVisibleSubfolders:(NSURL*)directory error:(NSError**)outError;
{
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	
	NSArray* contents = [fileManager contentsOfDirectoryAtURL:directory 
                                   includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey,NSURLIsPackageKey,nil] 
                                                      options:NSDirectoryEnumerationSkipsHiddenFiles 
                                                        error:outError];
    [fileManager release];
    
	if (!contents)
	{
		// Mask out file not found error. Disappearing folders are not considered an error here!
		if (outError!=nil && [*outError code] == 260) *outError = nil;
		return nil;
	}
	
    BOOL knowForSure = YES;
	for (NSURL* url in contents)
    {
        NSNumber* isFolder = nil;
		NSError* error = nil;
        BOOL ok = [url getResourceValue:&isFolder forKey:NSURLIsDirectoryKey error:&error];
        
        if (ok)
        {
            // Can stop looking as soon as a folder is found
            if ([isFolder boolValue])
            {
                NSNumber* isPackage = nil;
                ok = [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:&error];
                
                if (ok && ![isPackage boolValue]) return [NSNumber numberWithBool:YES];
            }
        }
        
        // If no subfolders are found, return the last error if there was one
        if (!ok)
        {
            knowForSure = NO;
            if (outError) *outError = error;
        }
    }
    
    return (knowForSure ? [NSNumber numberWithBool:NO] : nil);
}


//----------------------------------------------------------------------------------------------------------------------


@end
