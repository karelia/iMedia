//
//  iMBParserController.h
//  iMediaBrowse
//
//  Created by Chris Meyer on 7/7/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iMBParserController : NSObject
{
@private
    NSString                        *myMediaType;
    NSMutableArray                  *myLibraryNodes;
	NSMutableArray                  *myCustomFolderInfo;
}

- (id)initWithMediaType:(NSString *)mediaType;

// build the library nodes
- (void)buildLibraryNodesWithCustomFolders:(NSArray *)customFolders;

// return a mutable array of library nodes
- (NSMutableArray *)mutableLibraryNodes;

// adds a custom folder. returns the new list of iMBLibraryNodes
- (NSArray *)addCustomFolderPath:(NSString *)folderPath;

// removes an array of library nodes representing custom folders. returns a list of paths that were actually removed.
- (NSArray *)removeLibraryNodes:(NSArray *)libraryNodes;

@end
