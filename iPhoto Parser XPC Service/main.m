//
//  main.m
//  iPhoto Parser XPC Service
//
//  Created by Jörg Jacobsen on 09.03.12.
//  Copyright (c) 2012 Jacobsen Software Engineering. All rights reserved.
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>
#import <XPCKit/XPCKit.h>

int main(int argc, const char *argv[])
{
	[XPCService runServiceWithConnectionHandler:^(XPCConnection *connection){
		[connection sendLog:@"TestService received a connection"];
        
		[connection setEventHandler:^(XPCMessage *message, XPCConnection *connection){
			[connection sendLog:[NSString stringWithFormat:@"TestService received a message! %@", message]];
            
            // Got an invocable incoming message?
            
            XPCMessage *reply = [message invoke];
            
            // Otherwise, we define the semantics of the incoming message here
            
            if (!reply)
            {
                reply = [XPCMessage messageReplyForMessage:message];
                
                // Treat more operations here...
                
            }
            
            [connection sendMessage:reply];
            
		}];
	}];
	return 0;
}
