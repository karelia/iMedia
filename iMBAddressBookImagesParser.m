/*
 iMedia Browser <http://kareia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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

/*

 The idea here is to show images of people in your address book who have pictures associated with them.
 
 SORT OF WORKS, BUT THERE ARE PROBLEMS:
 
 * We really should parse all the cards into the top level, since some records may not exist
   in groups.  (The AddressBookParser would have the same issue).
 
 * There is no image path, since the images are created from data, so you can't drag.
   I'm not sure how to deal with this - maybe any place that asks for the image path (other than
   for generating the thumbnail, which we already have) should check if there is an image path,
   and if not, writing it out to a temporary file or something.
 
 * Since entries can live in more than one group, the combined view should only show the entries
   ONCE but we're seeing multiple versions of the same people.
 
 */



#import "iMBAddressBookImagesParser.h"
#import "iMedia.h"
#import <AddressBook/AddressBook.h>

@implementation iMBAddressBookImagesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}

- (NSMutableDictionary *)recordForPerson:(ABPerson *)cur
{
	NSData *imageData = [cur imageData];
	if (!imageData) return nil;
	NSImage *image = [[[NSImage alloc] initWithData:imageData] autorelease];
	if (!image) return nil;
	
	NSMutableDictionary *rec = [NSMutableDictionary dictionary];
	NSString *firstName = [cur valueForProperty:kABFirstNameProperty];
	NSString *lastName = [cur valueForProperty:kABLastNameProperty];
	NSString *company = [cur valueForProperty:kABOrganizationProperty];
	
	NSMutableString *name = [NSMutableString string];
	if (firstName && ![firstName isEqualToString:@""]) [name appendString:firstName];
	if (lastName && ![lastName isEqualToString:@""])
	{
		if (![name isEqualToString:@""]) [name appendString:@" "];
		[name appendString:lastName];
	}
	if ([name isEqualToString:@""] && company && ![company isEqualToString:@""])
	{
		[name appendString:company];
	}
	[rec setObject:name forKey:@"Caption"];
	[rec setObject:image forKey:@"CachedThumb"];
	
	// NOTE: no path!
	
	return rec;
}

- (iMBLibraryNode *)recursivelyParseGroup:(ABGroup *)group
{
	iMBLibraryNode *node = [[iMBLibraryNode alloc] init];
	[node setName:[group valueForProperty:kABGroupNameProperty]];
	[node setIconName:@"ABGroup"];
	
	NSMutableArray *people = [NSMutableArray array];
	NSEnumerator *e = [[group members] objectEnumerator];
	ABPerson *cur;
	
	while (cur = [e nextObject])
	{
		NSDictionary *record = [self recordForPerson:cur];
		if (nil != record)
		[people addObject:record];
	}
	
	[node setAttribute:people forKey:@"Images"];
	
	// append any sub groups
	NSEnumerator *subGroupEnum = [[group subgroups] objectEnumerator];
	ABGroup *subGroup;
	
	while (subGroup = [subGroupEnum nextObject])
	{
		[node addItem:[self recursivelyParseGroup:subGroup]];
	}
	
	return [node autorelease];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"Address Book", @"Root Node Name of address book")];
	[root setIconName:@"com.apple.AddressBook:"];
	
	ABAddressBook *ab = [ABAddressBook sharedAddressBook];
	NSEnumerator *groupEnum = [[ab groups] objectEnumerator];
	NSMutableArray *parentGroups = [NSMutableArray array];
	ABGroup *group;
	
	while (group = [groupEnum nextObject])
	{
		if ([[group parentGroups] count] == 0)
		{
			[parentGroups addObject:group];
		}
	}
	
	groupEnum = [parentGroups objectEnumerator];
	
	while (group = [groupEnum nextObject])
	{
		[root addItem:[self recursivelyParseGroup:group]];
	}
	
	// add ourselves to the root
	ABPerson *me = [ab me];
	NSMutableArray *a = [NSMutableArray arrayWithObject:[self recordForPerson:me]];
	[root setAttribute:a forKey:@"Images"];
	
	return [root autorelease];
}

@end
