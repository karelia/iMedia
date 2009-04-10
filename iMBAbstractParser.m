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


#import "iMBAbstractParser.h"
#import "UKKQueue.h"
#import "iMBLibraryNode.h"
#import "NSAttributedString+iMedia.h"

NSString *iMediaBrowserParserDidStartNotification = @"iMediaBrowserParserDidStart";
NSString *iMediaBrowserParserDidEndNotification = @"iMediaBrowserParserDidEnd";


// TODO: Split the UKKQueue stuff into a new abstract subclass of this, for better encapsulation since many subclasses don't need UKKQueue.

@interface iMBAbstractParser (Private)

- (void)registerForNotifications;
- (void)unRegisterFromNotifications;

@end

@implementation iMBAbstractParser

- (id)init
{
	if (self = [super init])
	{
		[self registerForNotifications];
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)file
{
	if (self = [super init])
	{
		myDatabase = [file copy];
		
		[self registerForNotifications];
	}
	return self;
}

- (void)registerForNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(parserDidStart:) name:iMediaBrowserParserDidStartNotification object:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(parserDidEnd:) name:iMediaBrowserParserDidEndNotification object:self];
}

- (void)unRegisterFromNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iMediaBrowserParserDidStartNotification object:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:iMediaBrowserParserDidEndNotification object:self];
}

- (void)dealloc
{
	[self unRegisterFromNotifications];
	
	[myDatabase release];
	[super dealloc];
}

- (void)finalize
{
	[super finalize];
}

- (NSString *)databasePath
{
	return myDatabase;
}

- (NSAttributedString *)name:(NSString *)name withImage:(NSImage *)image
{
	return [NSAttributedString attributedStringWithName:name image:image];
}

- (iMBLibraryNode *)parseDatabase
{
	// we do nothing, let the subclass do the hard yards.
	return nil;
}

- (iMBLibraryNode *)parseDatabaseInThread:(NSString *)databasePath gate:(NSLock *)gate name:(NSString *)name iconName:(NSString *)iconName icon:(NSImage*)icon
{
	NSString *folder = databasePath;
	if ( [[NSFileManager defaultManager] fileExistsAtPath:folder] )
    {
        iMBLibraryNode *libraryNode = [[[iMBLibraryNode alloc] init] autorelease];
        
        [libraryNode setName:name];
        [libraryNode setIconName:iconName];
        [libraryNode setIcon:icon];
        [libraryNode setIdentifier:name];
        [libraryNode setParserClassName:NSStringFromClass([self class])];
		[libraryNode setWatchedPath:myDatabase];
       
        // the node itself will be returned immediately. now launch _another_ thread to populate the node.
        NSDictionary *populateLibraryNodeArguments = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      libraryNode,          @"rootLibraryNode",
                                                      databasePath,         @"databasePath",
                                                      name,                 @"name",
                                                      gate,                 @"gate",
                                                      NULL];
        [NSThread detachNewThreadSelector:@selector(populateLibraryNodeWithArguments:) toTarget:self withObject:populateLibraryNodeArguments];
        
        return libraryNode;
    }
    else
    {
        return nil;
    }
}

// NOTE: subclassers SHOULD override this method
- (void)populateLibraryNode:(iMBLibraryNode *)rootLibraryNode name:(NSString *)name databasePath:(NSString *)databasePath
{
}

// NOTE: subclassers should NOT override this method
- (void)populateLibraryNodeWithArguments:(NSDictionary *)arguments
{	
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self performSelectorOnMainThread:@selector(postParserDidStartNotification:) withObject:arguments waitUntilDone:YES];

    iMBLibraryNode *rootLibraryNode = [arguments objectForKey:@"rootLibraryNode"];
	NSString *name = [arguments objectForKey:@"name"];
    NSString *databasePath = [arguments objectForKey:@"databasePath"];
    NSLock *gate = [arguments objectForKey:@"gate"];
    if (gate != NULL)
    {
        [gate lock];
        [gate unlock];
    }
    [self populateLibraryNode:rootLibraryNode name:name databasePath:databasePath];
	[self performSelectorOnMainThread:@selector(postParserDidEndNotification:) withObject:arguments waitUntilDone:YES];
	[pool release];
}

- (void)postParserDidStartNotification:(NSDictionary *)arguments
{
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserParserDidStartNotification
														object:self
													  userInfo:arguments];
}

- (void)postParserDidEndNotification:(NSDictionary *)arguments
{
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserParserDidEndNotification
														object:self
													  userInfo:arguments];
}

- (void)parserDidStart:(NSNotification*)notification
{
	NSDictionary *arguments = [notification userInfo];
    iMBLibraryNode *rootLibraryNode = [arguments objectForKey:@"rootLibraryNode"];
	NSString *name = [arguments objectForKey:@"name"];
	
	// the name will include 'loading' until it is populated.
	NSString *loadingString = LocalizedStringInIMedia(@"Loading...", @"Text that shows that we are loading");
	
	[rootLibraryNode setName:[name stringByAppendingFormat:@" (%@)", loadingString]];	
}

- (void)parserDidEnd:(NSNotification*)notification
{
	NSDictionary *arguments = [notification userInfo];
    iMBLibraryNode *rootLibraryNode = [arguments objectForKey:@"rootLibraryNode"];
	NSString *name = [arguments objectForKey:@"name"];
	
    // the node is populated, so remove the 'loading' moniker. do this on the main thread to be friendly to bindings.
	[rootLibraryNode setName:name];	
}

// standard implementation for single-item nodes.  Override if we return multiple items.

- (NSArray *)nodesFromParsingDatabase:(NSLock *)gate
{
	iMBLibraryNode *oneNodeParsed = [self parseDatabase];
	if (oneNodeParsed)
	{
		return [NSArray arrayWithObject:oneNodeParsed];
	}
	else
	{
		return nil;
	}
}

@end
