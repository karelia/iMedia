//
//  iMBParserController.h
//  iMediaBrowse
//
//  Created by Chris Meyer on 7/7/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//
// Control a set of parsers for a given media type.
// Clients can bind to the "libraryNodes" array but the binding should always take place on the main thread.
// Library nodes may be updated at any time due to changing files on disk or API calls such as adding custom
// folders.
//
@interface iMBParserController : NSObject
{
@private
    NSString                        *myMediaType;
    NSMutableArray                  *myLibraryNodes;
	NSMutableArray                  *myCustomFolderInfo;
    BOOL                             myIsBuilt;
}

// private constructor.
- (id)initWithMediaType:(NSString *)mediaType;

// build the library nodes. a client MUST call this before any other methods or bindings. customFolders can be NULL.
- (void)buildLibraryNodesWithCustomFolders:(NSArray *)customFolders;

// rebuild the library nodes.
- (void)rebuildLibrary;

// return a mutable array of library nodes
- (NSMutableArray *)mutableLibraryNodes;

// adds a custom folder. returns the new list of iMBLibraryNodes. not thread safe.
- (NSArray *)addCustomFolderPath:(NSString *)folderPath;

// removes an array of library nodes representing custom folders. returns a list of paths that were actually removed. not thread safe.
- (NSArray *)removeLibraryNodes:(NSArray *)libraryNodes;

@end
