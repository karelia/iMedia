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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroom4Parser.h"
#import "IMBLightroomObject.h"
#import "FMDatabase.h"
#import "IMBNode.h"
#import "IMBFolderObject.h"
#import "IMBObject.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "SBUtilities.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBLightroom4Parser ()

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBLightroom4Parser


//----------------------------------------------------------------------------------------------------------------------


// Check if Lightroom is installed...

+ (NSString*) lightroomPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.adobe.Lightroom4"];
}


// Unique identifier for this parser...

+ (NSString*) identifier
{
	return @"com.karelia.imedia.Lightroom4";
}


//----------------------------------------------------------------------------------------------------------------------


// Return an array to Lightroom library files...

+ (NSArray*) libraryPaths
{
	NSMutableArray* libraryPaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList = SBPreferencesCopyAppValue((CFStringRef)@"recentLibraries20",(CFStringRef)@"com.adobe.Lightroom4");
	
	if (recentLibrariesList) {
        [self parseRecentLibrariesList:(NSString*)recentLibrariesList into:libraryPaths];
        CFRelease(recentLibrariesList);
	}
	
    if ([libraryPaths count] == 0) {
		CFPropertyListRef activeLibraryPath = SBPreferencesCopyAppValue((CFStringRef)@"libraryToLoad20",(CFStringRef)@"com.adobe.Lightroom4");
		
		if (activeLibraryPath) {
			CFRelease(activeLibraryPath);
		}
    }
    
	return libraryPaths;
}

- (BOOL) checkDatabaseVersion
{
	NSNumber *databaseVersion = [self databaseVersion];
	
	if (databaseVersion != nil) {
		long databaseVersionLong = [databaseVersion longValue];
		
		if (databaseVersionLong < 400020) {
			return NO;
		}
		else if (databaseVersionLong >= 500000) {
			return NO;
		}
	}
	
	return YES;
}

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = [self.mediaSource path];
	FMDatabase* database = [FMDatabase databaseWithPath:databasePath];
	
//	[database setTraceExecution:YES];
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* mainDatabasePath = [self.mediaSource path];
	NSString* rootPath = [mainDatabasePath stringByDeletingPathExtension];
	NSString* previewPackagePath = [[NSString stringWithFormat:@"%@ Previews", rootPath] stringByAppendingPathExtension:@"lrdata"];
	NSString* previewDatabasePath = [[previewPackagePath stringByAppendingPathComponent:@"previews"] stringByAppendingPathExtension:@"db"];
	FMDatabase* database = [FMDatabase databaseWithPath:previewDatabasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

@end
