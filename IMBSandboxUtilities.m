/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#import "IMBSandboxUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


// Replacement function for NSHomeDirectory...

NSString* IMBHomeDirectory()
{
    return [NSString stringWithFormat:@"/Users/%@",NSUserName()];
}


// Convenience function for getting a path to an application container directory...

NSString* IMBApplicationContainerHomeDirectory(NSString* inBundleIdentifier)
{
    NSString* bundleIdentifier = inBundleIdentifier;
    
    if (bundleIdentifier == nil) 
    {
        bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    }
    
    NSString* appContainerDir = IMBHomeDirectory();
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Library"];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Containers"];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:bundleIdentifier];
    appContainerDir = [appContainerDir stringByAppendingPathComponent:@"Data"];
    
    return appContainerDir;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


// Private function to read contents of a prefs file at given path into a dinctionary...

static NSDictionary* _IMBPreferencesDictionary(NSString* inHomeFolderPath,NSString* inPrefsFileName)
{
    NSString* path = [inHomeFolderPath stringByAppendingPathComponent:@"Library"];
    path = [path stringByAppendingPathComponent:@"Preferences"];
    path = [path stringByAppendingPathComponent:inPrefsFileName];
    path = [path stringByAppendingPathExtension:@"plist"];
    
   return [NSDictionary dictionaryWithContentsOfFile:path];
}


// Private function to access a certain value in the prefs dictionary...

static CFTypeRef _IMBGetValue(NSDictionary* inPrefsFileContents,CFStringRef inKey)
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

CFTypeRef IMBPreferencesCopyAppValue(CFStringRef inKey,CFStringRef inBundleIdentifier)
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
        path = IMBHomeDirectory();
        NSDictionary* prefsFileContents = _IMBPreferencesDictionary(path,(NSString*)inBundleIdentifier);
        value = _IMBGetValue(prefsFileContents,inKey);
    }

    // It's possible that the other app is sandboxed as well, so we may need look for the prefs file 
    // in its container directory...
    
    if (value == nil)
    {
        path = IMBApplicationContainerHomeDirectory((NSString*)inBundleIdentifier);
        NSDictionary* prefsFileContents = _IMBPreferencesDictionary(path,(NSString*)inBundleIdentifier);
        value = _IMBGetValue(prefsFileContents,inKey);
    }
    
    return value;
}


//----------------------------------------------------------------------------------------------------------------------
