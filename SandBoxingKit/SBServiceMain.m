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
#import "IMBAccessRightsController.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
/**
 returns a static semaphore of eight resources intended to restrain parallelity when dispatching events with this service
 
 @Discussion
 We had instances where the Facebook parser service hung up on us when about 60 some parallel requests were issued
 (this might correlate with the fact that all Facebook requests reach out to the internet).
 
 Going beyond eight parallel resources did not seem to gain any better performance on any of the parsers.
 */
dispatch_semaphore_t dispatch_semaphore()
{
	static dispatch_semaphore_t sSharedInstance = NULL;
	static dispatch_once_t sOnceToken = 0;
    
    dispatch_once(&sOnceToken,
                  ^{
                      sSharedInstance = dispatch_semaphore_create(8);
                  });
    
 	return sSharedInstance;
}


// This is a generic main function for all our XPC services. It simply tries to invoke the message and 
// sends back any result and/or error...

int main(int argc, const char *argv[])
{
    NSAutoreleasePool* pool1 = [[NSAutoreleasePool alloc] init];
    
    // TODO/JJ: We should not have a reference to IMBAccessRightsController in here. Any way to put it outside framework?
    // Load the access rights bookmarks to grant access to parts of the file system...
    
    [IMBAccessRightsController sharedAccessRightsController];
    
	[XPCService runServiceWithConnectionHandler:^(XPCConnection* inConnection)
	{
		[inConnection setEventHandler:^(XPCMessage* inMessage, XPCConnection* inReplyConnection)
		{
            dispatch_semaphore_wait(dispatch_semaphore(), DISPATCH_TIME_FOREVER);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];
                
                @try
                {
                    XPCMessage* reply = [inMessage invoke];
                    if (reply) [inReplyConnection sendMessage:reply];
                }
                @catch (NSException* inException)
                {
                    NSString* text = [NSString stringWithFormat:@"Uncaught exception %@: %@\n\n%@\n\n",
                                      inException.name,
                                      inException.reason,
                                      [[inException callStackSymbols] componentsJoinedByString:@"\n"]];
                    
                    NSLog(@"%@",text);
                    [inReplyConnection sendLog:text];
                }
                
                [pool2 drain];
                dispatch_semaphore_signal(dispatch_semaphore());
            });
		}];
	}];
	
	[pool1 drain];
	return 0;
}


//----------------------------------------------------------------------------------------------------------------------


