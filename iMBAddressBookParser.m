/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 */

#import "iMBAddressBookParser.h"
#import "iMBLibraryNode.h"
#import "iMediaBrowser.h"
#import <AddressBook/AddressBook.h>
#import "iMedia.h"

@implementation iMBAddressBookParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[iMediaBrowser registerParser:[self class] forMediaType:@"contacts"];
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:nil])
	{
		
	}
	return self;
}

- (NSMutableDictionary *)recordForPerson:(ABPerson *)cur
{
	NSString *firstName = [cur valueForProperty:kABFirstNameProperty];
	NSString *lastName = [cur valueForProperty:kABLastNameProperty];
	ABMultiValue *emails = [cur valueForProperty:kABEmailProperty];
	
	NSMutableDictionary *rec = [NSMutableDictionary dictionary];
	
	if (firstName) [rec setObject:firstName forKey:@"FirstName"];
	if (lastName) [rec setObject:lastName forKey:@"LastName"];
	[rec setObject:[NSString stringWithFormat:@"%@ %@", firstName, lastName] forKey:@"Caption"];
	
	NSMutableArray *emls = [NSMutableArray array];
	
	int i;
	for (i = 0; i < [emails count]; i++)
	{
		[emls addObject:[emails valueAtIndex:i]];
	}
	[rec setObject:emls forKey:@"EmailAddresses"];
	[rec setObject:cur forKey:@"ABPerson"];
	
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
		[people addObject:[self recordForPerson:cur]];
	}
	
	[node setAttribute:people forKey:@"People"];
	
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
	[root setIconName:@"com.apple.AddressBook"];
	
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
	[root setAttribute:a forKey:@"People"];
	
	return [root autorelease];
}

@end
