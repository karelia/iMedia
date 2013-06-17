/*
 *   iMedia Browser Framework <http://karelia.com/imedia/>
 *
 *   Copyright (c) 2005-2013 by Karelia Software et al.
 *
 *   iMedia Browser is based on code originally developed by Jason Terhorst,
 *   further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 *   The new architecture for version 2.0 was developed by Peter Baumgartner.
 *   Contributions have also been made by Matt Gough, Martin Wennerberg and others
 *   as indicated in source files.
 *
 *   The iMedia Browser Framework is licensed under the following terms:
 *
 *   Permission is hereby granted, free of charge, to any person obtaining a copy
 *   of this software and associated documentation files (the "Software"), to deal
 *   in all or substantial portions of the Software without restriction, including
 *   without limitation the rights to use, copy, modify, merge, publish,
 *   distribute, sublicense, and/or sell copies of the Software, and to permit
 *   persons to whom the Software is furnished to do so, subject to the following
 *   conditions:
 *
 *   Redistributions of source code must retain the original terms stated here,
 *   including this list of conditions, the disclaimer noted below, and the
 *   following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 *
 *   Redistributions in binary form must include, in an end-user-visible manner,
 *   e.g., About window, Acknowledgments window, or similar, either a) the original
 *   terms stated here, including this list of conditions, the disclaimer noted
 *   below, and the aforementioned copyright notice, or b) the aforementioned
 *   copyright notice and a link to karelia.com/imedia.
 *
 *   Neither the name of Karelia Software, nor Sandvox, nor the names of
 *   contributors to iMedia Browser may be used to endorse or promote products
 *   derived from the Software without prior and express written permission from
 *   Karelia Software or individual contributors, as appropriate.
 *
 *   Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 *   "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 *   LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 *   AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 *   LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 *   CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 *   SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */


// ----------------------------------------------------------------------------------------------------------------------


// Author: Pierre Bernard


// ----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "FMDatabase.h"
#import "IMBFolderObject.h"
#import "IMBLightroom5Parser.h"
#import "IMBLightroomObject.h"
#import "IMBLightroomRuleScanner.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSData+SKExtensions.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "SBUtilities.h"
#import <Quartz/Quartz.h>


#define LOAD_SMART_COLLECTIONS 0


// ----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBLightroom5Parser ()

@end


// ----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBLightroom5Parser


// ----------------------------------------------------------------------------------------------------------------------


// Unique identifier for this parser...

+ (NSString *)identifier
{
	return @"com.karelia.imedia.Lightroom5";
}

// The bundle identifier of the Lightroom app this parser is based upon

+ (NSString *)lightroomAppBundleIdentifier
{
	return @"com.adobe.Lightroom5";
}

// ----------------------------------------------------------------------------------------------------------------------


- (BOOL)checkDatabaseVersion
{
	NSNumber *databaseVersion = [self databaseVersion];

	if (databaseVersion != nil) {
		long databaseVersionLong = [databaseVersion longValue];

		if (databaseVersionLong < 500006) {
			return NO;
		}
		else if (databaseVersionLong >= 600000) {
			return NO;
		}
	}

	return YES;
}

#if LOAD_SMART_COLLECTIONS

// This method populates an existing smart collection node with objects (image files). The essential part is id_local stored
// in the attributes dictionary. It determines the correct database query...

- (void)populateObjectsForSmartCollectionNode:(IMBNode *)inNode
{
	// Add object array, even if nothing is found in database, so that we do not cause endless loop...

	if (inNode.objects == nil) {
		inNode.objects				= [NSMutableArray array];
		inNode.displayedObjectCount = 0;
	}

	FMDatabase	*database				= self.database;

	if (database == nil) {
		return;
	}

	NSNumber	*collectionId			= [self idLocalFromAttributes:inNode.attributes];

	NSString	*rulesQuery				= [[self class] smartCollectionRulesQuery];
	FMResultSet *rulesResults			= [database executeQuery:rulesQuery, collectionId];
	NSString	*rulesString			= nil;

	if ([rulesResults next]) {
		rulesString = [rulesResults stringForColumn:@"content"];
	}

	[rulesResults close];

	if (rulesString == nil) {
		return;
	}

	NSScanner	*ruleScanner			= [NSScanner lightroomRulesScannerWithString:rulesString];
	id			rules					= nil;

	if (! [ruleScanner scanLightroomRules:&rules]) {
		return;
	}

	if (! [rules isKindOfClass:[NSDictionary class]]) {
		return;
	}

	NSArray		*s						= [rules objectForKey:@"s"];

	if (! [s isKindOfClass:[NSArray class]]) {
		return;
	}

	NSArray		*objectMatchArguments	= nil;
	NSString	*objectMatchClause		= [[self class] smartCollectionObjectMatchClause:s arguments:&objectMatchArguments];

	if (objectMatchClause == nil) {
		return;
	}

	if (objectMatchArguments == nil) {
		objectMatchArguments = [NSArray array];
	}

	NSString	*sortTypeQuery			= [[self class] smartCollectionSortTypeQuery];
	FMResultSet *sortTypeResults		= [database executeQuery:sortTypeQuery, collectionId];
	NSString	*sortTypeString			= nil;

	if ([sortTypeResults next]) {
		sortTypeString = [sortTypeResults stringForColumn:@"content"];
	}

	[sortTypeResults close];


	NSString	*sortDirectionQuery		= [[self class] smartCollectionSortDirectionQuery];
	FMResultSet *sortDirectionResults	= [database executeQuery:sortDirectionQuery, collectionId];
	NSString	*sortDirectionString	= nil;

	if ([sortDirectionResults next]) {
		sortDirectionString = [sortDirectionResults stringForColumn:@"content"];
	}

	[sortDirectionResults close];


	NSString	*objectQuery			= [[self class] smartCollectionObjectsQuery:objectMatchClause
														 sortTypeString:sortTypeString
													sortDirectionString:sortDirectionString];

	if (objectQuery == nil) {
		return;
	}

	FMResultSet *results				= [database executeQuery:objectQuery withArgumentsInArray:objectMatchArguments];

	NSUInteger	index					= 0;

	while ([results next]) {
		NSString	*absolutePath	= [results stringForColumn:@"absolutePath"];
		NSString	*filename		= [results stringForColumn:@"idx_filename"];
		NSNumber	*idLocal		= [NSNumber numberWithLong:[results longForColumn:@"id_local"]];
		NSNumber	*fileHeight		= [NSNumber numberWithDouble:[results doubleForColumn:@"fileHeight"]];
		NSNumber	*fileWidth		= [NSNumber numberWithDouble:[results doubleForColumn:@"fileWidth"]];
		NSString	*orientation	= [results stringForColumn:@"orientation"];
		NSString	*caption		= [results stringForColumn:@"caption"];
		NSString	*pyramidPath	= ([results hasColumnWithName:@"pyramidPath"] ? [results stringForColumn:@"pyramidPath"] : nil);
		NSString	*name			= caption != nil ? caption : filename;
		NSString	*path			= [absolutePath stringByAppendingString:filename];

		if (pyramidPath == nil) {
			pyramidPath = [self pyramidPathForImage:idLocal];
		}

		if ([self canOpenImageFileAtPath:path]) {
			NSMutableDictionary *metadata	= [NSMutableDictionary dictionary];

			[metadata setObject:path forKey:@"MasterPath"];
			[metadata setObject:idLocal forKey:@"idLocal"];
			[metadata setObject:path forKey:@"path"];
			[metadata setObject:fileHeight forKey:@"height"];
			[metadata setObject:fileWidth forKey:@"width"];
			[metadata setObject:orientation forKey:@"orientation"];

			if (name) {
				[metadata setObject:name forKey:@"name"];
			}

			IMBObject			*object		= [self objectWithPath:path
												idLocal:idLocal
												   name:name
											pyramidPath:pyramidPath
											   metadata:metadata
												  index:index++];
			[(NSMutableArray *)inNode.objects addObject : object];
			inNode.displayedObjectCount++;
		}
	}

	[results close];
}

+ (NSString *)smartCollectionObjectMatchClause:(NSArray *)rules arguments:(NSArray **)outArguments
{
	NSString		*combine	= @"union";
	NSMutableArray	*arguments	= [NSMutableArray array];
	NSMutableArray	*clauses	= [NSMutableArray array];

	for (id rule in rules) {
		if ([rule isKindOfClass:[NSArray class]]) {
			NSArray		*nestedArguments	= nil;
			NSString	*nestedclause		= [self smartCollectionObjectMatchClause:rule arguments:&nestedArguments];

			if (nestedclause == nil) {
				return nil;
			}

			[clauses addObject:nestedclause];
			[arguments addObject:nestedArguments];
		}
		else if ([rule isKindOfClass:[NSDictionary class]]) {
			if ([rule count] == 1) {
				NSString *value = [rule objectForKey:@"combine"];

				if (value != nil) {
					combine = value;

					continue;
				}
			}

			NSString	*criteria	= [rule objectForKey:@"criteria"];
			NSString	*operation	= [rule objectForKey:@"operation"];
			NSString	*value		= [rule objectForKey:@"value"];
			NSString	*value2		= [rule objectForKey:@"value2"];

			if ((criteria == nil) || (operation == nil) || (value == nil)) {
				NSLog(@"Failed to make sense of Lightroom smart collection rule: %@", rule);

				return nil;
			}

			NSUInteger propertyCount = 3;

			if (value2 != nil) {
				NSLog(@"value2: %@", value2);

				propertyCount += 1;
			}

			if ([rule count] > propertyCount) {
				NSMutableDictionary *unknownProperties = [NSMutableDictionary dictionaryWithDictionary:rule];

				[unknownProperties removeObjectForKey:@"criteria"];
				[unknownProperties removeObjectForKey:@"operation"];
				[unknownProperties removeObjectForKey:@"value"];
				[unknownProperties removeObjectForKey:@"value2"];
				//				[unknownProperties removeObjectForKey:@"value2"];

				NSLog(@"Ignored unknown Lightroom smart collection rule properties: %@", unknownProperties);
			}


			if ([criteria isEqualToString:@"keywords"]) {
				// contains == any
				// contains all == all
				// contains words == words
				// doesn't contain == noneOf
				// begins with == beginsWith
				// ends with == endsWith
				// are empty == empty
				// aren't empty == notEmpty
			}
			else if ([criteria isEqualToString:@"rating"]) {
				// in range
				// value 2
			}
			else if ([criteria isEqualToString:@"pick"]) {
			}
			else if ([criteria isEqualToString:@"proxyStatus"]) {
				// isTrue, value true
				// isFalse, value true
			}
			else if ([criteria isEqualToString:@"labelColor"]) {
				criteria	= @"colorLabels";

				if ([value isEqual:@"none"]) {
					NSString *clause = [NSString stringWithFormat:@"%@ == ''", criteria];

					[clauses addObject:clause];

					continue;
				}
				else if ([value isEqual:@"custom"]) {
					NSMutableArray *subclauses = [NSMutableArray arrayWithCapacity:6];

					[subclauses addObject:[NSString stringWithFormat:@"%@ <> ''", criteria]];

					for (unsigned int i = 1; i < 6; i++) {
						NSString	*labelKey	= [NSString stringWithFormat:@"label%d", i];
						CFStringRef labelName	= SBPreferencesCopyAppValue((CFStringRef)labelKey,
																			(CFStringRef)[[self class] lightroomAppBundleIdentifier]);

						if (labelName != NULL) {
							[subclauses addObject:[NSString stringWithFormat:@"%@ <> ?", criteria]];
							[arguments addObject:(NSString*)labelName];

							CFRelease(labelName);
						}
					}

					[clauses addObject:[NSString stringWithFormat:@"( %@ )", [subclauses componentsJoinedByString:@" AND "]]];

					continue;
				}

				NSString	*labelKey	= [NSString stringWithFormat:@"label%@", value];
				CFStringRef labelName	= SBPreferencesCopyAppValue((CFStringRef)labelKey,
																	(CFStringRef)[[self class] lightroomAppBundleIdentifier]);

				value		= [(NSString *)labelName autorelease];
			}
			else if ([criteria isEqualToString:@"folder"]) {
			}
			else if ([criteria isEqualToString:@"collection"]) {
			}
			else if ([criteria isEqualToString:@"publishCollection"]) {
			}
			else if ([criteria isEqualToString:@"publishedVia"]) {
			}
			else if ([criteria isEqualToString:@"filename"]) {
			}
			else if ([criteria isEqualToString:@"copyname"]) {
			}
			else if ([criteria isEqualToString:@"fileFormat"]) {
			}
			else if ([criteria isEqualToString:@"captureTime"]) {
				//				operation = "==",
				//				value = "2013-06-17",
				//				value2 = "2013-06-17",
			}
			else if ([criteria isEqualToString:@"fastLoadDNG"]) {
			}
			else if ([criteria isEqualToString:@"all"]) {
				// any searchable text
			}

			if ([criteria isEqualToString:@"empty"]) {
				NSString *clause = [NSString stringWithFormat:@"( %@ IS NULL OR %@ == '' )", criteria, criteria];

				[clauses addObject:clause];
			}
			else if ([criteria isEqualToString:@"notEmpty"]) {
				NSString *clause = [NSString stringWithFormat:@"( %@ NOT NULL AND %@ <> '' )", criteria, criteria];

				[clauses addObject:clause];
			}
			else if (value != nil) {
				NSString *clause = [NSString stringWithFormat:@"%@ %@ ?", criteria, operation];

				[clauses addObject:clause];

				[arguments addObject:value];
			}
			else {
				NSLog(@"No value specified Lightroom smart collection rule: %@", rule);

				return nil;
			}
		}
	}

	if (outArguments != NULL) {
		*outArguments = arguments;
	}

	NSUInteger clauseCount = [clauses count];

	if (clauseCount == 0) {
		return @"";
	}
	else if (clauseCount == 1) {
		if ([combine isEqualToString:@"exclude"]) {
			return [NSString stringWithFormat:@"NOT ( %@ )", [clauses objectAtIndex:0]];
		}
		else {
			return [clauses objectAtIndex:0];
		}
	}
	else {
		if ([combine isEqualToString:@"union"]) {
			return [clauses componentsJoinedByString:@" OR "];
		}
		else if ([combine isEqualToString:@"interset"]) {
			return [clauses componentsJoinedByString:@" AND "];
		}
		else if ([combine isEqualToString:@"exclude"]) {
			return [NSString stringWithFormat:@"NOT ( %@ )", [clauses componentsJoinedByString:@" OR "]];
		}
		else {
			NSLog(@"Failed to make sense of Lightroom smart collection combiner: %@", combine);

			return nil;
		}
	}

	return nil;
}

+ (NSString *)smartCollectionObjectsQuery:(NSString *)objectMatchClause sortTypeString:(NSString *)sortTypeString sortDirectionString:(NSString *)sortDirectionString
{
	NSString	*queryFormat	=
	@" SELECT arf.absolutePath || '/' || alf.pathFromRoot absolutePath,"
	@"        aif.idx_filename, ai.id_local, ai.captureTime, ai.fileHeight, ai.fileWidth, ai.orientation, "
	@"        iptc.caption"
	@" FROM Adobe_images ai"
	@" LEFT JOIN AgLibraryFile aif ON aif.id_local = ai.rootFile"
	@" INNER JOIN AgLibraryFolder alf ON aif.folder = alf.id_local"
	@" INNER JOIN AgLibraryRootFolder arf ON alf.rootFolder = arf.id_local"
	@" LEFT JOIN AgLibraryIPTC iptc on ai.id_local = iptc.image"
	@" WHERE ai.fileFormat <> 'VIDEO'"
	@" AND ( %@ )"
	@" ORDER BY ai.%@ %@";

	NSString	*sortAttribute	= sortTypeString;

	if (sortAttribute == nil) {
		sortAttribute = @"captureTime";
	}

	NSString	*sortOperator	= nil;

	if ((sortDirectionString == nil) || [sortDirectionString isEqualToString:@"ascending"]) {
		sortOperator = @"ASC";
	}
	else if ([sortDirectionString isEqualToString:@"descending"]) {
		sortOperator = @"DESC";
	}
	else {
		NSLog(@"Failed to make sense of Lightroom smart collection sort direction: %@", sortDirectionString);

		return nil;
	}

	return [NSString stringWithFormat:queryFormat, objectMatchClause, sortAttribute, sortOperator];
}

#endif

// ----------------------------------------------------------------------------------------------------------------------


#if LOAD_SMART_COLLECTIONS

+ (NSString *)rootCollectionNodesQuery
{
	NSString *query =
	@" SELECT alc.id_local, alc.parent, alc.name, alc.creationid"
	@" FROM AgLibraryCollection alc"
	@" WHERE (creationId = 'com.adobe.ag.library.collection' OR creationId = 'com.adobe.ag.library.group' OR creationId = 'com.adobe.ag.library.smart_collection') "
	@" AND alc.parent IS NULL";

	return query;
}

+ (NSString *)collectionNodesQuery
{
	NSString *query =
	@" SELECT alc.id_local, alc.parent, alc.name, alc.creationid"
	@" FROM AgLibraryCollection alc"
	@" WHERE (creationId = 'com.adobe.ag.library.collection' OR creationId = 'com.adobe.ag.library.group' OR creationId = 'com.adobe.ag.library.smart_collection') "
	@" AND alc.parent = ?";

	return query;
}

+ (NSString *)smartCollectionRulesQuery
{
	NSString *query =
	@" SELECT alcc.content"
	@" FROM AgLibraryCollectionContent alcc"
	@" WHERE alcc.collection = ?"
	@" AND alcc.owningModule = 'ag.library.smart_collection'";

	return query;
}

+ (NSString *)smartCollectionSortTypeQuery
{
	NSString *query =
	@" SELECT alcc.content"
	@" FROM AgLibraryCollectionContent alcc"
	@" WHERE alcc.collection = ?"
	@" AND alcc.owningModule = 'com.adobe.ag.library.sortType'";

	return query;
}

+ (NSString *)smartCollectionSortDirectionQuery
{
	NSString *query =
	@" SELECT alcc.content"
	@" FROM AgLibraryCollectionContent alcc"
	@" WHERE alcc.collection = ?"
	@" AND alcc.owningModule = 'com.adobe.ag.library.sortDirection'";

	return query;
}

+ (IMBLightroomNodeType)nodeTypeForCreationId:(NSString *)creationId
{
	if ([creationId isEqualToString:@"com.adobe.ag.library.smart_collection"]) {
		return IMBLightroomNodeTypeSmartCollection;
	}

	return IMBLightroomNodeTypeCollection;
}

#endif

// ----------------------------------------------------------------------------------------------------------------------


- (FMDatabase *)libraryDatabase
{
	NSString	*databasePath	= [self.mediaSource path];
	FMDatabase	*database		= [FMDatabase databaseWithPath:databasePath];

	//	[database setTraceExecution:YES];
	[database setLogsErrors:YES];

	return database;
}

- (FMDatabase *)previewsDatabase
{
	NSString	*mainDatabasePath		= [self.mediaSource path];
	NSString	*rootPath				= [mainDatabasePath stringByDeletingPathExtension];
	NSString	*previewPackagePath		= [[NSString stringWithFormat:@"%@ Previews", rootPath] stringByAppendingPathExtension:@"lrdata"];
	NSString	*previewDatabasePath	= [[previewPackagePath stringByAppendingPathComponent:@"previews"] stringByAppendingPathExtension:@"db"];
	FMDatabase	*database				= [FMDatabase databaseWithPath:previewDatabasePath];

	[database setLogsErrors:YES];

	return database;
}

// ----------------------------------------------------------------------------------------------------------------------


// This method must return an appropriate prefix for IMBObject identifiers. Refer to the method
// -[IMBParser iMedia2PersistentResourceIdentifierForObject:] to see how it is used. Historically we used class names as the prefix.
// However, during the evolution of iMedia class names can change and identifier string would thus also change.
// This is undesirable, as things that depend of the immutability of identifier strings would break. One such
// example are the object badges, which use object identifiers. To guarrantee backward compatibilty, a parser
// class must override this method to return a prefix that matches the historic class name...

- (NSString *)iMedia2PersistentResourceIdentifierPrefix
{
	return @"IMBLightroom5Parser";
}

@end
