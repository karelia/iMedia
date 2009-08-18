//
//  IMBTestAppDelegate.m
//  iMedia
//
//  Created by Peter Baumgartner on 18.07.09.
//  Copyright 2009 IMAGINE GbR. All rights reserved.
//


//----------------------------------------------------------------------------------------------------------------------

//	iMedia Framework
#import <iMedia/IMBParserController.h>
#import <iMedia/IMBLibraryController.h>
#import <iMedia/IMBNodeViewController.h>
#import <iMedia/IMBPhotosViewController.h>
#import <iMedia/IMBConfig.h>
#import <iMedia/IMBParser.h>
#import <iMedia/IMBNode.h>
#import <iMedia/IMBiPhotoParser.h>

//	Test Application
#import "IMBTestAppDelegate.h"



//----------------------------------------------------------------------------------------------------------------------


#pragma mark MACROS

#define LOG_PARSERS 0
#define LOG_CREATE_NODE 0
#define LOG_POPULATE_NODE 0


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBTestAppDelegate

@synthesize nodeViewController = _nodeViewController;
@synthesize objectViewController = _objectViewController;


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	// Load parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self];
	[parserController loadParsers];
	
	// Create libraries (singleton per mediaType)...
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBMediaTypePhotos];
	[libraryController setDelegate:self];
	
	// Link the user interface (possible multiple instances) to the	singleton library...
	
	self.nodeViewController = [IMBNodeViewController viewControllerForLibraryController:libraryController];
	NSView* nodeView = self.nodeViewController.view;
	NSView* containerView = self.nodeViewController.objectContainerView;
	
	self.objectViewController = [IMBPhotosViewController viewControllerForLibraryController:libraryController];
	self.objectViewController.nodeTreeController = self.nodeViewController.nodeTreeController;
	NSView* objectView = self.objectViewController.view;

	[objectView setFrame:[containerView bounds]];
	[containerView addSubview:objectView];
	[nodeView setFrame:[ibWindow.contentView bounds]];
	[ibWindow setContentView:nodeView];

	// Restore window size...
	
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [ibWindow setFrame:NSRectFromString(frame) display:YES animate:NO];
	
	// Load the library...
	
	[libraryController reload];
}
	

// Save window frame to prefs...

- (void) applicationWillTerminate:(NSNotification*)inNotification;
{
	NSString* frame = NSStringFromRect(ibWindow.frame);
	if (frame) [IMBConfig setPrefsValue:frame forKey:@"windowFrame"];
}
	

// Cleanup...

- (void) dealloc
{
	IMBRelease(_nodeViewController);
	IMBRelease(_objectViewController);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBParserController Delegate


- (BOOL) controller:(IMBParserController*)inController shouldLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
	#endif
	
	return YES;
}


- (void) controller:(IMBParserController*)inController willLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
	#endif
}


- (void) controller:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif
}


- (void) controller:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBLibraryController Delegate


- (BOOL) controller:(IMBLibraryController*)inController shouldCreateNodeWithParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif
}


- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) controller:(IMBLibraryController*)inController shouldPopulateNode:(IMBNode*)inNode
{
	#if LOG_POPULATE_NODE
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willPopulateNode:(IMBNode*)inNode
{
	#if LOG_POPULATE_NODE
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif
}


- (void) controller:(IMBLibraryController*)inController didPopulateNode:(IMBNode*)inNode
{
	#if LOG_POPULATE_NODE
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


@end
