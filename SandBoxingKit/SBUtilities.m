//
//  SBUtilities.m
//  SandboxingKit
//
//  Created by Jörg Jacobsen on 2/16/12. Copyright 2012 SandboxingKit.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

// Author: Peter Baumgartner, Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "SBUtilities.h"
#import <Security/SecCode.h>
#import <Security/SecRequirement.h>
#import <sys/types.h>
#import <pwd.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Sandbox Check


// Check if the host app is sandboxed. This code is based on suggestions from the FrameworksIT mailing list...

BOOL SBIsSandboxed()
{
	static BOOL sIsSandboxed = NO;
	static dispatch_once_t sIsSandboxedToken = 0;

    dispatch_once(&sIsSandboxedToken,
    ^{
		if (NSAppKitVersionNumber >= 1138) // Are we running on Lion?
		{
			SecCodeRef codeRef = NULL;
			SecCodeCopySelf(kSecCSDefaultFlags,&codeRef);

			if (codeRef != NULL)
			{
				SecRequirementRef reqRef = NULL;
				SecRequirementCreateWithString(CFSTR("entitlement[\"com.apple.security.app-sandbox\"] exists"),kSecCSDefaultFlags,&reqRef);

				if (reqRef != NULL)
				{
					OSStatus status = SecCodeCheckValidity(codeRef,kSecCSDefaultFlags,reqRef);
					
					if (status == noErr)
					{
						sIsSandboxed = YES;
					};
				}
			}
		}
    });
	
	return sIsSandboxed;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Directory Access


// Replacement function for NSHomeDirectory...

NSString* SBHomeDirectory()
{
	struct passwd* passInfo = getpwuid(getuid());
	char* homeDir = passInfo->pw_dir;
	return [NSString stringWithUTF8String:homeDir];
}


// Convenience function for getting a path to an application container directory...

NSString* SBApplicationContainerHomeDirectory(NSString* inBundleIdentifier)
{
    NSString* bundleIdentifier = inBundleIdentifier;
    
    if (bundleIdentifier == nil) 
    {
        bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    NSString* appContainerDir = SBHomeDirectory();
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Library"];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Containers"];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:bundleIdentifier];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Data"];
    
    return appContainerDir;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Preferences Access


// Private function to read contents of a prefs file at given path into a dinctionary...

static NSDictionary* _SBPreferencesDictionary(NSString* inHomeFolderPath,NSString* inPrefsFileName)
{
    NSString* path = [inHomeFolderPath stringByAppendingPathComponent:@"Library"];
    path = [path stringByAppendingPathComponent:@"Preferences"];
    path = [path stringByAppendingPathComponent:inPrefsFileName];
    path = [path stringByAppendingPathExtension:@"plist"];
    
   return [NSDictionary dictionaryWithContentsOfFile:path];
}


// Private function to access a certain value in the prefs dictionary...

static CFTypeRef _SBGetValue(NSDictionary* inPrefsFileContents,CFStringRef inKey)
{
    CFTypeRef value = NULL;

    if (inPrefsFileContents) 
    {
        id tmp = [inPrefsFileContents objectForKey:(NSString*)inKey];
    
        if (tmp)
        {
            value = (CFTypeRef) tmp;
            CFRetain(value);
        }
    }
    
    return value;
}


// High level function that should be used instead of CFPreferencesCopyAppValue, because in  
// sandboxed apps we need to work around problems of CFPreferencesCopyAppValue returning NULL...

CFTypeRef SBPreferencesCopyAppValue(CFStringRef inKey,CFStringRef inBundleIdentifier)
{
    CFTypeRef value = NULL;
    NSString* path;
    
    // First try the official API. If we get a value, then use it...
    
    if (value == nil)
    {
        value = CFPreferencesCopyAppValue((CFStringRef)inKey,(CFStringRef)inBundleIdentifier);
    }
    
    // In sandboxed apps that may have failed tough, so try a workaround. If the app has the entitlement
    // com.apple.security.temporary-exception.files.absolute-path.read-only for a wide enough part of the
    // file system, we can read the prefs file ourself and parse it manually...
    
    if (value == nil)
    {
        path = SBHomeDirectory();
        NSDictionary* prefsFileContents = _SBPreferencesDictionary(path,(NSString*)inBundleIdentifier);
        value = _SBGetValue(prefsFileContents,inKey);
    }

    // It's possible that the other app is sandboxed as well, so we may need look for the prefs file 
    // in its container directory...
    
    if (value == nil)
    {
        path = SBApplicationContainerHomeDirectory((NSString*)inBundleIdentifier);
        NSDictionary* prefsFileContents = _SBPreferencesDictionary(path,(NSString*)inBundleIdentifier);
        value = _SBGetValue(prefsFileContents,inKey);
    }
    
    return value;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark XPC Abstraction


// Prototype for XPCConnection instance method to silence compiler warning on untyped connection object (which is  
// used because of weak linking XPCKit)...

@interface NSObject()
-(void) sendSelector:(SEL)inSelector withTarget:(id)inTarget object:(id)inObject returnValueHandler:(SBReturnValueHandler)inReturnHandler;
@end


//----------------------------------------------------------------------------------------------------------------------


// Dispatch a message with optional argument object to a target object asynchronously. When connnection (which must 
// be an XPCConnection) is supplied the message will be transferred to an XPC service for execution. Please note  
// that inTarget and inObject must conform to NSCoding for this to work, or they cannot be sent across the connection. 
// When connection is nil (e.g. running on Snow Leopard) message will be dispatched asynchronously via GCD, but the 
// behaviour will be similar...

void SBPerformSelectorAsync(id inConnection,id inTarget,SEL inSelector,id inObject,SBReturnValueHandler inReturnHandler)
{
    // If we are running sandboxed on Lion (or newer), then send a request to perform selector on target to our XPC
    // service and hand the results to the supplied return handler block...
    
    if (inConnection && [inConnection respondsToSelector:@selector(sendSelector:withTarget:object:returnValueHandler:)])
    {
        [inConnection sendSelector:inSelector
                        withTarget:inTarget
                            object:inObject
                returnValueHandler:inReturnHandler];
    }
    
    // If we are not sandboxed (e.g. running on Snow Leopard) we'll just do the work directly (but asynchronously)
    // via GCD queues. Once again the result is handed over to the return handler block. Please note that we are 
	// copying inTarget and inObject so they are dispatched under same premises as XPC (XPC uses archiving)...
   
    else
    {
        id targetCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:inTarget]];
        id objectCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:inObject]];
        
        dispatch_queue_t currentQueue = dispatch_get_current_queue();
        dispatch_retain(currentQueue);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^()
		{
			NSError* error = nil;
			id result = nil;

			if (objectCopy)
			{
				result = [targetCopy performSelector:inSelector withObject:objectCopy withObject:(id)&error];
			} 
			else
			{
				result = [targetCopy performSelector:inSelector withObject:(id)&error];
			}

			// Copy the results and send them back to the caller. This provides the exact same workflow as with XPC.
			// This is extremely useful for debugging purposes, but leads to a performance hit in non-sandboxed
			// host apps. For this reason the following line may be commented out once our code base is stable...
			
			result = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:result]];
			
			dispatch_async(currentQueue,^()
			{
				inReturnHandler(result,error);
				dispatch_release(currentQueue);
			});
	   });
    }
}


//----------------------------------------------------------------------------------------------------------------------


// Here's the same thing as an Objective-C wrapper (for those devs that do not like using pure C functions)...
 							
@implementation NSObject (SBPerformSelectorAsync)

- (void) performAsyncSelector:(SEL)inSelector withObject:(id)inObject onConnection:(id)inConnection completionHandler:(SBReturnValueHandler)inCompletionHandler
{
	SBPerformSelectorAsync(inConnection,self,inSelector,inObject,inCompletionHandler);
}

@end


//----------------------------------------------------------------------------------------------------------------------



