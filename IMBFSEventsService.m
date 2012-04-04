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

#import <XPCKit/XPCKit.h>
#import <iMedia/IMBFileWatcher.h>
#import <iMedia/IMBFSEventsWatcher.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static XPCConnection* sConnection = nil;
static dispatch_queue_t sDispatchQueue = NULL;


//----------------------------------------------------------------------------------------------------------------------


@interface IMBFSEventsWatcherDelegate : NSObject //<IMBFileWatcherDelegate>

@end

@implementation IMBFSEventsWatcherDelegate

-(void) watcher:(id<IMBFileWatcher>)inWatcher receivedNotification:(NSString*)inNotification forPath:(NSString*)inPath
{
//	[sConnection sendLog:[NSString stringWithFormat:@"DETECTED CHANGE FOR PATH %@",inPath]];
	
	[sConnection sendMessage:[XPCMessage messageWithObjectsAndKeys:
		@"pathDidChange",@"operation",
		inPath,@"path",
		nil]];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


int main(int argc, const char *argv[])
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	sDispatchQueue = dispatch_queue_create("com.karelia.imedia.FSEvents",DISPATCH_QUEUE_SERIAL);
	IMBFSEventsWatcherDelegate* delegate = [[IMBFSEventsWatcherDelegate alloc] init];
	[[IMBFSEventsWatcher sharedFileWatcher] setDelegate:delegate];
	[[IMBFSEventsWatcher sharedFileWatcher] setDispatchQueue:sDispatchQueue];
	
	[XPCService runServiceWithConnectionHandler:^(XPCConnection* inConnection)
	{
		[inConnection setEventHandler:^(XPCMessage* inMessage, XPCConnection* inConnection)
		{
			NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];

			NSString* operation = [inMessage objectForKey:@"operation"];
			NSString* path = [inMessage objectForKey:@"path"];
                
			if ([operation isEqual:@"start"])
			{
				xpc_transaction_begin();
				sConnection = [inConnection retain];
//				[sConnection sendLog:@"STARTING FSEVENTS SERVICE"];
			}
			else if ([operation isEqual:@"addPath"])
			{
//				[sConnection sendLog:[NSString stringWithFormat:@"ADDING PATH %@",path]];
				[[IMBFSEventsWatcher sharedFileWatcher] addPath:path];
			}
			else if ([operation isEqual:@"removePath"])
			{
//				[sConnection sendLog:[NSString stringWithFormat:@"REMOVING PATH %@",path]];
				[[IMBFSEventsWatcher sharedFileWatcher] removePath:path];
			}
			else if ([operation isEqual:@"stop"])
			{
//				[sConnection sendLog:@"STOPPING FSEVENTS SERVICE"];
				IMBRelease(sConnection);
				xpc_transaction_end();
			}
			
			[pool2 drain];
		}];
	}];
	
	[[IMBFSEventsWatcher sharedFileWatcher] setDelegate:nil];
	IMBRelease(delegate);
	dispatch_release(sDispatchQueue);
	
	[pool drain];
	return 0;
}


//----------------------------------------------------------------------------------------------------------------------


