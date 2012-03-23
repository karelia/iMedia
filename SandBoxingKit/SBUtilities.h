//
//  SBSandboxUtilities.h
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


#import <Cocoa/Cocoa.h>


//----------------------------------------------------------------------------------------------------------------------


// Returns YES if the app is running in a sandbox...

BOOL SBIsSandboxed(void);

// Replacement function for NSHomeDirectory: Always return the REAL home directory of the current
// user, even if the app is sandboxed...

NSString* SBHomeDirectory(void);

// Convenience function for getting a path to an application container directory. Returns the home
// directory of a given sandboxed app container. User nil for the current application...

NSString* SBApplicationContainerHomeDirectory(NSString* inBundleIdentifier);

// High level function that should be used instead of CFPreferencesCopyAppValue, because in  
// sandboxed apps we need to work around problems of CFPreferencesCopyAppValue returning NULL...
 
CFTypeRef SBPreferencesCopyAppValue(CFStringRef inKey,CFStringRef inBundleIdentifier);


//----------------------------------------------------------------------------------------------------------------------
