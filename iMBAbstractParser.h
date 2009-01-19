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


#import <Cocoa/Cocoa.h>
#import "iMediaBrowserProtocol.h"

@class iMBLibraryNode;

@interface iMBAbstractParser : NSObject <iMBParser>
{
	NSString			*myDatabase;
}

// default initializer from the protocol
- (id)init;

// We provide by default the ability to watch for external changes to the databases. 
// subclasses call this super method if they want auto watching of the db file.
- (id)initWithContentsOfFile:(NSString *)file;

- (NSString *)databasePath;

// subclasses generally implement this.  Return nil if no items to avoid showing up.
// this method should not have "side effects" on instance variables. it should be a pure method
// to return the list of iMBLibraryNodes representing the data in the database. this
// ensures that it is threadable.
- (iMBLibraryNode *)parseDatabase;

// subclassers can optional implement populateLibraryNode: and invoke parseDatabaseInThread:gate:name:iconName:icon:
// directly from parseDatabase to implement threaded parsing. populateLibraryNode:name:databasePath must be threadsafe
// and will be invoked on a thread so it needs its own autorelease pool.
// gate is used to delay background parsing until all top level nodes have been displayed in table view
- (iMBLibraryNode *)parseDatabaseInThread:(NSString *)databasePath gate:(NSLock *)gate name:(NSString *)name iconName:(NSString *)iconName icon:(NSImage*)icon;

- (void)populateLibraryNode:(iMBLibraryNode *)rootLibraryNode name:(NSString *)name databasePath:(NSString *)databasePath;

// subclasses MAY implement this. this method should not have "side effects" on the class.
// it should be a pure method to return the list of iMBLibraryNode's representing the data
// in the database. this ensures that it is threadable.
// gate is used to delay background parsing until all top level nodes have been displayed in table view
- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate;  // Return nil if no items to avoid showing up

// helper method to generate an attributed string with icon and name
- (NSAttributedString *)name:(NSString *)name withImage:(NSImage *)image;

@end
