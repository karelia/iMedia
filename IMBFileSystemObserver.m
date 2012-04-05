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

#import "IMBFileSystemObserver.h"
#import "IMBFileWatcher.h"
#import "IMBFSEventsWatcher.h"
#import "SBUtilities.h"
#import <XPCKit/XPCKit.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBPathDidChangeNotification = @"IMBPathDidChange";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// Private methods...

@interface IMBFileSystemObserver ()
- (void) _setupXPCService;
- (void) _setupFSEventsWatcher;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFileSystemObserver

@synthesize notificationDelay = _notificationDelay;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// Create a singleton instance...

+ (IMBFileSystemObserver*) sharedObserver
{
	static IMBFileSystemObserver* sSharedObserver = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedObserver = [[IMBFileSystemObserver alloc] init];
	});
	
	return sSharedObserver;
}


//----------------------------------------------------------------------------------------------------------------------


// Initialize file system observing. If sandboxed then use the XPC service, otherwise use do it directly...
		
- (id) init
{
	if ((self = [super init]))
	{
		_notificationDelay = 2.0;
		
		if (SBIsSandboxed())
		{
			[self _setupXPCService];
		}
		else
		{
			[self _setupFSEventsWatcher];
		}
	}
	
	return self;
}


// Close down the XPC service. Most likely this won't ever be called, since we are a singleton instance...

- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	if (_connection)
	{
		[_connection sendMessage:[XPCMessage messageWithObjectsAndKeys:@"stop",@"operation",nil]];
		IMBRelease(_connection);
	}
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// In a sandboxed Lion app we'll use an XPC service that will stay around for the filetime of the app...

- (void) _setupXPCService
{
	// Launch the FSEvents XPC service and establish a connection to it...
	
	_connection = [[XPCConnection alloc] initWithServiceName:@"com.karelia.imedia.FSEvents"];
	
	// Install a global event handler to receive replies. For each pathDidChange reply we'll get,  
	// we will send out a notification on the main thread that any interested parties (probably 
	// the IMBLibraryController) can listen to...
	
	_connection.eventHandler = ^(XPCMessage* inMessage,XPCConnection *inConnection)
	{
		NSString* operation = [inMessage objectForKey:@"operation"];
		NSString* path = [inMessage objectForKey:@"path"];
			
		if ([operation isEqual:@"pathDidChange"])
		{
			dispatch_async(dispatch_get_main_queue(),^()
			{	
				[self sendDidChangeNotificationForPath:path];
			});
		}
	};

	// Init the FSEvents service...
	
	[_connection sendMessage:[XPCMessage messageWithObjectsAndKeys:@"start",@"operation",nil]];
}


// On 10.6 we will create a watcher and handle everything directly here in our own process...

- (void) _setupFSEventsWatcher
{
	[[IMBFSEventsWatcher sharedFileWatcher] setDelegate:self];
	[[IMBFSEventsWatcher sharedFileWatcher] setDispatchQueue:dispatch_get_main_queue()];
}


//----------------------------------------------------------------------------------------------------------------------


// Add a path to be observed...

- (void) addPath:(NSString*)inPath
{
	if (inPath)
	{
		if (_connection)
		{
			[_connection sendMessage:[XPCMessage messageWithObjectsAndKeys:
				@"addPath",@"operation",
				inPath,@"path",
				nil]];
		}
		else
		{
			[[IMBFSEventsWatcher sharedFileWatcher] addPath:inPath];
		}
	}
}


// Remove a path to be observed...

- (void) removePath:(NSString*)inPath
{
	if (inPath)
	{
		if (_connection)
		{
			[_connection sendMessage:[XPCMessage messageWithObjectsAndKeys:
				@"removePath",@"operation",
				inPath,@"path",
				nil]];
		}
		else
		{
			[[IMBFSEventsWatcher sharedFileWatcher] removePath:inPath];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This callback is only used on 10.6. When sandboxed on Lion everything is handled by the XPC service...

- (void) watcher:(id<IMBFileWatcher>)inWatcher receivedNotification:(NSString*)inNotification forPath:(NSString*)inPath
{
	[self sendDidChangeNotificationForPath:inPath];
}


// Send a notification to interested parties (taking the coalescing delay into account)...

- (void) sendDidChangeNotificationForPath:(NSString*)inPath
{
	SEL method = @selector(_sendDidChangeNotificationForPath:);
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:method object:inPath];
	[self performSelector:method withObject:inPath afterDelay:_notificationDelay];
}


- (void) _sendDidChangeNotificationForPath:(NSString*)inPath
{
//	NSLog(@"RECEIVED CHANGE FOR PATH %@",inPath);
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBPathDidChangeNotification object:inPath];
}


//----------------------------------------------------------------------------------------------------------------------


@end

