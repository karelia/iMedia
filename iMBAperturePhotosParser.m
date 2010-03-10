/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


#import "iMBAperturePhotosParser.h"
#import "iMediaConfiguration.h"
#import "iMBLibraryNode.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMResultSet.h"

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

//	CONFIGURATION
//	
//	If you switch off both defines below you get the same contents as the Aperture
//	tree in iPhoto.
//
//	These settings could be part of the iMedia browser preferences:

//	Shows the 'Aperture Library', knot which holds all images from Aperture not
//	just the "top of the stack" images.
//#define SHOW_ALL_IMAGES_FOLDER

//	Shows a top level knot named "Aperture" which is the root of all other knots.
//#define SHOW_TOP_LEVEL_APERTURE_KNOT


@interface iMBAperturePhotosParser (Private)

+ (NSString*)pathForVolumeNamed:(NSString *)name;
+ (NSString*)pathForVolumeUUID:(NSString *)uuid;
+ (NSString*)cloneDatabase:(NSString*)databasePath;

@end


@implementation iMBAperturePhotosParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[iMediaConfiguration registerParser:[self class] forMediaType:@"photos"];

    [pool release];
}

- (id)init
{
	if (self = [super init])
	{
	}
	return self;
}

- (BOOL)proceedForVersion:(int)versionInteger
{
	return YES;
}

- (BOOL)shouldSkipAlbumType:(NSString*)albumType forVersion:(int)versionInteger
{
	BOOL skipAlbum = NO;
	
	//	'99': library knot holding all images, not just the "top of the stack" images
#ifndef SHOW_ALL_IMAGES_FOLDER
	skipAlbum = skipAlbum || [albumType isEqualToString:@"99"];
#endif
	
	if (versionInteger == 3) {
		skipAlbum = skipAlbum || [albumType isEqualToString:@"3"];
		skipAlbum = skipAlbum || [albumType isEqualToString:@"5"];
		skipAlbum = skipAlbum || [albumType isEqualToString:@"94"];
		skipAlbum = skipAlbum || [albumType isEqualToString:@"97"];
		skipAlbum = skipAlbum || [albumType isEqualToString:@"98"];
	}
	
	return skipAlbum;
}

- (BOOL)shouldSkipMediaType:(NSString*)mediaType forVersion:(int)versionInteger
{
	return (![@"Image" isEqualToString:mediaType]);
}

- (BOOL)wantsPreviewMediaType:(NSString*)mediaType forVersion:(int)versionInteger
{	
	return NO;
}

+ (NSDictionary*)enhancedRecordForRecord:(NSDictionary*)record
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *masterPath = nil;
	NSString *previewPath = [record valueForKey:@"ImagePath"];
	NSString *basePath = [[previewPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
	
	NSRange range = [previewPath rangeOfString:@".aplibrary/"];
	NSString *libraryPath = [previewPath substringToIndex:(range.location + range.length)];
	NSString *databasePath = [[libraryPath stringByAppendingPathComponent:@"Database"] stringByAppendingPathComponent:@"Library.apdb"];
	
	if ([fileManager fileExistsAtPath:databasePath]) {
		// We are looking at Aperture 3
		NSString *readOnlyDatabasePath = [iMBAperturePhotosParser cloneDatabase:databasePath];
		FMDatabase *database = [FMDatabase databaseWithPath:readOnlyDatabasePath];
		
		if ([database open]) {
			NSString *masterUUID = nil;
			NSString *imagePath = nil;
			NSString *fileVolumeUUID = nil;
			NSString *diskUUID = nil;
			
			NSString *versionUUID = [record valueForKey:@"VersionUUID"];
			FMResultSet *masterUUIDResult =
				[database executeQuery:@"SELECT masterUuid, rawMasterUuid, nonRawMasterUuid FROM rkversion WHERE uuid = ?", versionUUID];
			
			if ([masterUUIDResult next]) {
				masterUUID = [masterUUIDResult stringForColumn:@"rawMasterUuid"];
				
				if (masterUUID  == nil) {
					masterUUID = [masterUUIDResult stringForColumn:@"nonRawMasterUuid"];

					if (masterUUID  == nil) {
						masterUUID = [masterUUIDResult stringForColumn:@"masterUuid"];
					}
				}
			}
			
			[masterUUIDResult close];		
			
			if (masterUUID != nil) {
				FMResultSet *imagePathResult = [database executeQuery:@"SELECT fileVolumeUuid, imagePath FROM rkmaster WHERE uuid = ?", masterUUID];
				
				if ([imagePathResult next]) {
					imagePath =[imagePathResult stringForColumn:@"imagePath"];
					fileVolumeUUID =[imagePathResult stringForColumn:@"fileVolumeUuid"];
				}
				
				[imagePathResult close];		
				
				if (fileVolumeUUID != nil) {
					FMResultSet *diskUUIDResult = [database executeQuery:@"SELECT diskUuid FROM rkvolume WHERE uuid = ?", fileVolumeUUID];
					
					if ([diskUUIDResult next]) {
						diskUUID = [diskUUIDResult stringForColumn:@"diskUuid"];
					}
					
					[diskUUIDResult close];		
				}
			}

			if (imagePath != nil) {
				if (fileVolumeUUID != nil) {
					if (diskUUID != nil) {
						NSString *volumePath = [iMBAperturePhotosParser pathForVolumeUUID:diskUUID];
						NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
						
						if ([fileManager fileExistsAtPath:fullPath]) {
							masterPath = fullPath;
						}
					}
				}
				else {
					NSString *mastersPath = [libraryPath stringByAppendingPathComponent:@"Masters"];
					NSString *fullPath = [mastersPath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}					
				}
			}
			
			[database close];
		}		
	}
	else {
		// Aperture 2 or prior
		// Look for the master within the library
		NSString *infoPath = [[basePath stringByAppendingPathComponent:@"OriginalVersionInfo"] stringByAppendingPathExtension:@"apversion"];
		NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPath];
		NSString *masterName = [infoDict objectForKey:@"fileName"];
		
		if (masterName != nil) {
			NSString *localPath = [basePath stringByAppendingPathComponent:masterName];
			
			if ([fileManager fileExistsAtPath:localPath]) {
				masterPath = localPath;
			}
			else {
				NSString *apFile = [localPath stringByAppendingPathExtension:@"apfile"];
				NSDictionary *apDict = [NSDictionary dictionaryWithContentsOfFile:apFile];
				NSString *imagePath = [apDict objectForKey:@"imagePath"];
				
				if (imagePath != nil) {
					NSDictionary *volumeInfo = [apDict objectForKey:@"volumeInfo"];
					NSString *volumeName = [volumeInfo objectForKey:@"volumeName"];
					NSString *volumePath = [iMBAperturePhotosParser pathForVolumeNamed:volumeName];
					NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}
				}
			}
		}
		
		if (masterPath == nil) { // The master file is a referenced external file	
			NSRange range = [previewPath rangeOfString:@".aplibrary/"];
			NSString *libraryPath = [previewPath substringToIndex:(range.location + range.length)];
			NSString *databasePath = [[libraryPath stringByAppendingPathComponent:@"Aperture.aplib"] stringByAppendingPathComponent:@"Library.apdb"];
			FMDatabase *database = [FMDatabase databaseWithPath:databasePath];
			
			if ([database open]) {
				NSString *fileUUID = nil;
				NSString *imagePath = nil;
				NSString *fileVolumeUUID = nil;
				NSString *volumeName = nil;
				
				NSString *versionUUID = [record valueForKey:@"VersionUUID"];
				FMResultSet *fileUUIDResult = [database executeQuery:@"SELECT zfileuuid FROM zrkversion WHERE zuuid = ?", versionUUID];
				
				if ([fileUUIDResult next]) {
					fileUUID = [fileUUIDResult stringForColumn:@"zfileuuid"];
				}
				
				[fileUUIDResult close];		
				
				if (fileUUID != nil) {
					FMResultSet *imagePathResult = [database executeQuery:@"SELECT zimagepath FROM zrkfile WHERE zuuid = ?", fileUUID];
					
					if ([imagePathResult next]) {
						imagePath =[imagePathResult stringForColumn:@"zimagepath"];
					}
					
					[imagePathResult close];		
					
					FMResultSet *fileVolumeUUIDResult = [database executeQuery:@"SELECT zfilevolumeuuid FROM zrkfile WHERE zuuid = ?", fileUUID];
					
					if ([fileVolumeUUIDResult next]) {
						fileVolumeUUID =[fileVolumeUUIDResult stringForColumn:@"zfilevolumeuuid"];
					}
					
					[fileVolumeUUIDResult close];		
					
					if (fileVolumeUUID != nil) {
						FMResultSet *volumeNameResult = [database executeQuery:@"SELECT zname FROM zrkvolume WHERE zuuid = ?", fileVolumeUUID];
						
						if ([volumeNameResult next]) {
							volumeName = [volumeNameResult stringForColumn:@"zname"];
						}
						
						[volumeNameResult close];		
					}
				}
				else { // We may be looking at a pre-2.0 library
					NSMutableString *imagePathQuery = [NSMutableString string];
					
					[imagePathQuery appendString:@"SELECT zimagepath FROM zrkfile"];
					[imagePathQuery appendString:@" WHERE z_pk = ("];
					[imagePathQuery appendString:@"    SELECT zoriginalfile FROM zrkmaster"];
					[imagePathQuery appendString:@"     WHERE z_pk = ("];
					[imagePathQuery appendString:@"        SELECT zmaster FROM zrkversion"];
					[imagePathQuery appendString:@"         WHERE zuuid = ?"];
					[imagePathQuery appendString:@"      )"];
					[imagePathQuery appendString:@" )"];
					
					FMResultSet *imagePathResult = [database executeQuery:imagePathQuery, versionUUID];
					
					if ([imagePathResult next]) {
						imagePath = [imagePathResult stringForColumn:@"zimagepath"];
					}
					
					[imagePathResult close];
					
					if (imagePath != nil) {
						NSMutableString *volumeNameQuery = [NSMutableString string];
						
						[volumeNameQuery appendString:@"SELECT zname FROM zrkvolume"];
						[volumeNameQuery appendString:@" WHERE z_pk = ("];
						[volumeNameQuery appendString:@"    SELECT zfilevolume FROM zrkfile"];
						[volumeNameQuery appendString:@"     WHERE z_pk = ("];
						[volumeNameQuery appendString:@"        SELECT zoriginalfile FROM zrkmaster"];
						[volumeNameQuery appendString:@"         WHERE z_pk = ("];
						[volumeNameQuery appendString:@"            SELECT zmaster FROM zrkversion"];
						[volumeNameQuery appendString:@"             WHERE zuuid = ?"];
						[volumeNameQuery appendString:@"         )"];
						[volumeNameQuery appendString:@"     )"];
						[volumeNameQuery appendString:@" )"];
						
						FMResultSet *volumeNameResult = [database executeQuery:volumeNameQuery, versionUUID];
						
						if ([volumeNameResult next]) {
							volumeName  =[volumeNameResult stringForColumn:@"zname"];
						}
						
						[volumeNameResult close];		
					}
				}
				
				if (imagePath != nil) {
					NSString *volumePath = [iMBAperturePhotosParser pathForVolumeNamed:volumeName];
					NSString *fullPath = [volumePath stringByAppendingPathComponent:imagePath];
					
					if ([fileManager fileExistsAtPath:fullPath]) {
						masterPath = fullPath;
					}
				}
				
				[database close];
			}
		}
	}
	
	if (masterPath != nil) {
		NSMutableDictionary *enhancedRecord = [NSMutableDictionary dictionaryWithDictionary:record];
		
		[enhancedRecord setObject:masterPath forKey:@"OriginalPath"];
		[enhancedRecord setObject:masterPath forKey:@"MasterPath"];
		
		return enhancedRecord;
	}
	
	return record;
}

+ (NSString*)pathForVolumeNamed:(NSString *)name
{
	if (name != nil) {
		HFSUniStr255 volumeName;
		FSRef volumeFSRef;
		unsigned int volumeIndex = 1;
		
		while (FSGetVolumeInfo(kFSInvalidVolumeRefNum, volumeIndex++, NULL, kFSVolInfoNone, NULL, &volumeName, &volumeFSRef) == noErr) {
			if ([[NSString stringWithCharacters:volumeName.unicode length:volumeName.length] isEqualToString:name]) {
				NSURL *url = [(NSURL *)CFURLCreateFromFSRef(NULL, &volumeFSRef) autorelease];
				
				return [url path];
			}
		}
		
		return [@"/Volumes" stringByAppendingPathComponent:name];
	}
	
	return @"/";
}


+ (NSString*)pathForVolumeUUID:(NSString *)uuid
{
	if (uuid != nil) {
		NSString *path = @"/usr/sbin/diskutil";

		NSMutableArray *arguments = [NSMutableArray array];
		
		[arguments addObject:@"info"];
		[arguments addObject:@"-plist"];
		[arguments addObject:uuid];
		
		NSTask *task = [[NSTask alloc] init];
		
		[task setLaunchPath:path];	
		[task setArguments:arguments];
		
		NSPipe *outputPipe = [NSPipe pipe];
		NSPipe *errorPipe = [NSPipe pipe];
		
		[task setStandardOutput:outputPipe];
		[task setStandardError:errorPipe];
		
		NSFileHandle *outputFileHandle = [outputPipe fileHandleForReading];
		NSFileHandle *errorFileHandle = [errorPipe fileHandleForReading];
		
		@try {
			[task launch];
			[task waitUntilExit];
		}
		@catch (NSException *localException) {
			NSLog(@"Caught %@: %@", [localException name], [localException reason]);

			return nil;
		}
		
		NSData *outputData = [outputFileHandle readDataToEndOfFile];
		NSData *errorData = [errorFileHandle readDataToEndOfFile];
		NSString *result = nil;
		
		if ((errorData != nil) && [errorData length]) {
			NSLog(@"Got error message: %@",  [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease]);
		}
		
		if ([task terminationStatus] == noErr) {
			if ((outputData != nil) && [outputData length]) {
				result = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease];
			}
		}
		
		[outputFileHandle closeFile];
		[errorFileHandle closeFile];
		
		[task release];
		
		if (result != nil) {
			NSDictionary *volumeInfo = [result propertyList];
			NSString *mountPoint = [volumeInfo objectForKey:@"MountPoint"];
			
			return mountPoint;
		}
	}
	
	return nil;
}

+ (NSString*)cloneDatabase:(NSString*)databasePath
{
	// BEGIN ugly hack to work around Aperture locking its database

	NSString *basePath = [databasePath stringByDeletingPathExtension];	
	NSString *pathExtension = [databasePath pathExtension];	
	NSString *readOnlyDatabasePath = [[NSString stringWithFormat:@"%@-readOnly", basePath] stringByAppendingPathExtension:pathExtension];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
	
	if ([fileManager fileExistsAtPath:readOnlyDatabasePath]) {
		NSDictionary *attributesOfCopy = [fileManager fileAttributesAtPath:readOnlyDatabasePath traverseLink:YES];
		NSDate *modDateOfCopy = [attributesOfCopy fileModificationDate];
		
		NSDictionary *attributesOfOrig = [fileManager fileAttributesAtPath:databasePath traverseLink:YES];
		NSDate *modDateOfOrig = [attributesOfOrig fileModificationDate];
		
		if (NSOrderedSame == [modDateOfOrig compare:modDateOfCopy]) {
			needToCopyFile = NO;
		}
	}
	
	if (needToCopyFile) {
		(void) [fileManager removeFileAtPath:readOnlyDatabasePath handler:nil];
		BOOL copied = [fileManager copyPath:databasePath toPath:readOnlyDatabasePath handler:nil];
		
		if (!copied) {
			NSLog(@"Unable to copy database file at %@", databasePath);
		}
	}
	
	// END ugly hack
	
	return readOnlyDatabasePath;
}

@end