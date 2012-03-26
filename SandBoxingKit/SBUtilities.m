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

// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#import "SBUtilities.h"
#import <Security/SecCode.h>
#import <Security/SecRequirement.h>
#import <sys/types.h>
#import <pwd.h>


//----------------------------------------------------------------------------------------------------------------------


// Check if the host app is sandboxed. This code is based on suggestions from the FrameworksIT mailing list...

BOOL SBIsSandboxed()
{
	static BOOL sIsSandboxed = NO;
	static dispatch_once_t sIsSandboxedToken = 0;

#warning App will not work on OS X 10.7 to 10.7.2 because it will still be sandboxed but not return accordingly
    if (!IMBRunningOnLion1073OrNewer()) {
        return NO;
    }
    
    dispatch_once(&sIsSandboxedToken,
    ^{
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
    });
	
	return sIsSandboxed;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


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


// Dispatch a message with optional argument object to a target object asynchronously.
// When connnection (which must be an XPCConnection) is not nil the message will be transfered
// to XPC service for execution (i.e. target and object must conform to NSCoding when connection is not nil).
// When connection is nil (e.g. running on Snow Leopard) message will be dispatched asynchronously via GCD.

void SBPerformSelectorAsync(id inConnection,
                            id inTarget, SEL inSelector, id inObject,
                            SBReturnValueHandler inReturnHandler)
{
    // If we are running sandboxed on Lion (or newer), then send a request to perform selector on target to our XPC
    // service and hand the results to the supplied return handler block...
    
    if (inConnection && [inConnection respondsToSelector:@selector(sendSelector:withTarget:Object:returnValueHandler:)] )
    {
        [inConnection sendSelector:inSelector
                        withTarget:inTarget
                            object:inObject
                returnValueHandler:inReturnHandler];
    }
    
    // If we are not sandboxed (e.g. running on Snow Leopard) we'll just do the work directly (but asynchronously)
    // via GCD queues. Once again the result is handed over to the return handler block...
    
    else
    {
        // Copy target and object so they are dispatched under same premises as XPC (XPC uses archiving)
        
        id targetCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:inTarget]];
        id objectCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:inObject]];
        
        dispatch_queue_t currentQueue = dispatch_get_current_queue();
        dispatch_retain(currentQueue);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^()
                       {
                           NSError* error = nil;
                           id result = nil;
                           
                           if (objectCopy) {
                               result = [targetCopy performSelector:inSelector withObject:objectCopy withObject:(id)&error];
                           } else {
                               result = [targetCopy performSelector:inSelector withObject:(id)&error];
                           }
                           
                           dispatch_async(currentQueue,^()
                                          {
                                              inReturnHandler(result, error);
                                              dispatch_release(currentQueue);
                                          });
                       });
    }
}


