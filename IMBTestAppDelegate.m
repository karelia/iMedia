//
//  IMBTestAppDelegate.m
//  iMedia
//
//  Created by Peter Baumgartner on 18.07.09.
//  Copyright 2009 IMAGINE GbR. All rights reserved.
//


//----------------------------------------------------------------------------------------------------------------------


#import "IMBTestAppDelegate.h"
#import "IMBParserController.h"
#import "IMBLibraryController.h"
#import "IMBUserInterfaceController.h"
#import "IMBParser.h"
#import "IMBNode.h"
#import "IMBiPhotoParser.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark MACROS

#define DEBUG 1


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBTestAppDelegate


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	// Load parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self];
	[parserController logRegisteredParsers];
	[parserController loadParsers];
	[parserController logLoadedParsers];
	
	// Create libraries (singleton per mediaType)...
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBPhotosMediaType];
	[libraryController setDelegate:self];
	[libraryController reload];
	
	// Link the user interface (possible multiple instances) to the	singleton library...
	
	ibUserInterfaceController.libraryController = libraryController;
}
	

//----------------------------------------------------------------------------------------------------------------------


- (IBAction) select:(id)inSender
{
	IMBLibraryController* libraryController =  [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBPhotosMediaType];
	IMBNode* node = [libraryController.nodes objectAtIndex:0];
	[libraryController selectNode:node];
}

- (IBAction) expand:(id)inSender
{
	IMBLibraryController* libraryController =  [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBPhotosMediaType];
	IMBNode* node = [libraryController.nodes objectAtIndex:0];
	[libraryController expandNode:node];
}

- (IBAction) update:(id)inSender
{
	IMBLibraryController* libraryController =  [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBPhotosMediaType];
	IMBNode* node = [libraryController.nodes objectAtIndex:0];
	[libraryController reloadNode:node];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBParserController Delegate


- (BOOL) controller:(IMBParserController*)inController willLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	#if DEBUG
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
	#endif
	
	return YES;
}


- (void) controller:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if DEBUG
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif
}


- (void) controller:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if DEBUG
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBLibraryController Delegate


- (BOOL) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser
{
	#if DEBUG
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser
{
	#if DEBUG
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

	[inController logNodes];
//	[inController selectNode:[inController.nodes objectAtIndex:0]];
}


- (BOOL) controller:(IMBLibraryController*)inController willExpandNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	BOOL iPhoto = [inNode.parser isKindOfClass:[IMBiPhotoParser class]];
	return !iPhoto;
}


- (void) controller:(IMBLibraryController*)inController didExpandNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	[inController logNodes];
}


- (BOOL) controller:(IMBLibraryController*)inController willSelectNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	BOOL iPhoto = [inNode.parser isKindOfClass:[IMBiPhotoParser class]];
	return !iPhoto;
}


- (void) controller:(IMBLibraryController*)inController didSelectNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	[inController logNodes];
//	[inController expandNode:[inController.nodes objectAtIndex:0]];
}


//----------------------------------------------------------------------------------------------------------------------


@end
