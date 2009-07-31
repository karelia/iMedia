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
//	[parserController logRegisteredParsers];
	[parserController loadParsers];
//	[parserController logLoadedParsers];
	
	// Create libraries (singleton per mediaType)...
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBPhotosMediaType];
	[libraryController setDelegate:self];
	
	// Link the user interface (possible multiple instances) to the	singleton library...
	
	ibUserInterfaceController.libraryController = libraryController;

	// Load the library...
	
	[libraryController reload];
}
	

//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBParserController Delegate


- (BOOL) controller:(IMBParserController*)inController shouldLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
//	#if DEBUG
//	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
//	#endif
	
	return ![NSStringFromClass(inParserClass) isEqualToString:@"IMBiPhotoParser"];
}


- (void) controller:(IMBParserController*)inController willLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
//	#if DEBUG
//	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
//	#endif
}


- (void) controller:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
//	#if DEBUG
//	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
//	#endif
}


- (void) controller:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
//	#if DEBUG
//	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
//	#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBLibraryController Delegate


- (BOOL) controller:(IMBLibraryController*)inController shouldCreateNodeWithParser:(IMBParser*)inParser
{
	#if DEBUG
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser
{
	#if DEBUG
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif
}


- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser
{
	#if DEBUG
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

//	[inController logNodes];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) controller:(IMBLibraryController*)inController shouldExpandNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willExpandNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif
}


- (void) controller:(IMBLibraryController*)inController didExpandNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

//	[inController logNodes];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) controller:(IMBLibraryController*)inController shouldSelectNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willSelectNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif
}


- (void) controller:(IMBLibraryController*)inController didSelectNode:(IMBNode*)inNode
{
	#if DEBUG
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

//	[inController logNodes];
}


//----------------------------------------------------------------------------------------------------------------------


@end
