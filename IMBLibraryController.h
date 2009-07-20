/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#pragma mark HEADERS

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

extern NSString* kIMBNodesWillChangeNotification;
extern NSString* kIMBNodesDidChangeNotification;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


@interface IMBLibraryController : NSObject
{
	NSString* _mediaType;
	NSMutableArray* _nodes;
	IMBOptions _options;
	id _delegate;
}

// Create singleton instance of the controller. Don't forget to set the delegate early in the app lifetime...

+ (IMBLibraryController*) sharedLibraryControllerWithMediaType:(NSString*)inMediaType;
- (id) initWithMediaType:(NSString*)inMediaType;

@property (retain) NSString* mediaType;
@property (retain) NSMutableArray* nodes;
@property (assign) IMBOptions options;
@property (assign) id delegate;

// Loading...

- (void) reload;

- (void) reloadNode:(IMBNode*)inNode;
- (void) expandNode:(IMBNode*)inNode;
- (void) selectNode:(IMBNode*)inNode;

// Node accessors (must only be called on the main thread)...

- (NSArray*) nodesForParser:(IMBParser*)inParser;
- (IMBNode*) nodeWithIdentifier:(NSString*)inIdentifier;

// Custom folders...

- (void) addNodeForFolder:(NSString*)inPath;
- (BOOL) removeNode:(IMBNode*)inNode;

// Popup menu...

- (NSMenu*) menuWithSelector:(SEL)inSelector target:(id)inTarget addSeparators:(BOOL)inAddSeparator;

// Debugging support...

- (void) logNodes;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// The following delegate methods are called multiple time during the app lifetime. When return NO from the
// will method the delegate can suppress the operation. The delegate methods are called on the main thread... 

@protocol IMBLibraryControllerDelegate

@optional

- (BOOL) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser;
- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser;

- (BOOL) controller:(IMBLibraryController*)inController willExpandNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController didExpandNode:(IMBNode*)inNode;

- (BOOL) controller:(IMBLibraryController*)inController willSelectNode:(IMBNode*)inNode;
- (void) controller:(IMBLibraryController*)inController didSelectNode:(IMBNode*)inNode;

@end


//----------------------------------------------------------------------------------------------------------------------

