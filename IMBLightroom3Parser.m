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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBLightroom3Parser.h"

#import <Quartz/Quartz.h>

#import "FMDatabase.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBObject.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBPreferencesCopyAppValue.h"


@interface IMBLightroom3Parser ()

+ (NSString*) cloneDatabase:(NSString*)databasePath;

@end


@implementation IMBLightroom3Parser

//----------------------------------------------------------------------------------------------------------------------


// Check if Lightroom is installed...

+ (NSString*) lightroomPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.adobe.Lightroom3"];
}


// Return an array to Lightroom library files...

+ (NSArray*) libraryPaths
{
	NSMutableArray* libraryPaths = [NSMutableArray array];
    
	CFStringRef recentLibrariesList = IMBPreferencesCopyAppValue((CFStringRef)@"recentLibraries20",(CFStringRef)@"com.adobe.Lightroom3");
	
	if (recentLibrariesList) {
        [self parseRecentLibrariesList:(NSString*)recentLibrariesList into:libraryPaths];
        CFRelease(recentLibrariesList);
	}
	
    if ([libraryPaths count] == 0) {
		CFPropertyListRef activeLibraryPath = IMBPreferencesCopyAppValue((CFStringRef)@"libraryToLoad20",(CFStringRef)@"com.adobe.Lightroom3");
		
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
		
		if (databaseVersionLong < 300025) {
			return NO;
		}
		else if (databaseVersionLong >= 400000) {
			return NO;
		}
	}
	
	return YES;
}

- (FMDatabase*) libraryDatabase
{
	NSString* databasePath = (NSString*)self.mediaSource;
	NSString* readOnlyDatabasePath = [[self class] cloneDatabase:databasePath];
	FMDatabase* database = [FMDatabase databaseWithPath:readOnlyDatabasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

- (FMDatabase*) previewsDatabase
{
	NSString* mainDatabasePath = (NSString*)self.mediaSource;
	NSString* rootPath = [mainDatabasePath stringByDeletingPathExtension];
	NSString* previewPackagePath = [[NSString stringWithFormat:@"%@ Previews", rootPath] stringByAppendingPathExtension:@"lrdata"];
	NSString* previewDatabasePath = [[previewPackagePath stringByAppendingPathComponent:@"previews"] stringByAppendingPathExtension:@"db"];
	FMDatabase* database = [FMDatabase databaseWithPath:previewDatabasePath];
	
	[database setLogsErrors:YES];
	
	return database;
}

+ (NSString*)cloneDatabase:(NSString*)databasePath
{
	// BEGIN ugly hack to work around Lightroom locking its database
	
	NSString *basePath = [databasePath stringByDeletingPathExtension];	
	NSString *pathExtension = [databasePath pathExtension];	
	NSString *readOnlyDatabasePath = [[NSString stringWithFormat:@"%@-readOnly", basePath] stringByAppendingPathExtension:pathExtension];
	
	NSFileManager *fileManager = [NSFileManager imb_threadSafeManager];
	BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
	NSError* error;
	
	if ([fileManager fileExistsAtPath:readOnlyDatabasePath]) {
		error = nil;
		NSDictionary *attributesOfCopy = [fileManager attributesOfItemAtPath:readOnlyDatabasePath error:&error];
		if (!attributesOfCopy) NSLog (@"Unable to fetch attributes from %@: %@", readOnlyDatabasePath, error.localizedDescription);
		NSDate *modDateOfCopy = [attributesOfCopy fileModificationDate];
		
		error = nil;
		NSDictionary *attributesOfOrig = [fileManager attributesOfItemAtPath:databasePath error:&error];
		if (attributesOfOrig) NSLog (@"Unable to fetch attributes from %@: %@", databasePath, error.localizedDescription);
		NSDate *modDateOfOrig = [attributesOfOrig fileModificationDate];
		
		if (NSOrderedSame == [modDateOfOrig compare:modDateOfCopy]) {
			needToCopyFile = NO;
		}
	}
	
	if (needToCopyFile) {
		(void) [fileManager removeItemAtPath:readOnlyDatabasePath error:&error];
        
        error = nil;    // needed for if either path is nil
		BOOL copied = (nil != databasePath)
					&& (nil != readOnlyDatabasePath)
					&& [fileManager copyItemAtPath:databasePath toPath:readOnlyDatabasePath error:&error];
		
		if (!copied) {
			NSLog (@"Unable to copy database file at %@: %@", databasePath, error.localizedDescription);
		}
	}
	
	// END ugly hack
	
	return readOnlyDatabasePath;
}

@end
