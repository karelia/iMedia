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

- (iMBLibraryNode *)recursivelyParseGroup:(ABGroup *)group
{
	iMBLibraryNode *node = [[iMBLibraryNode alloc] init];
	[node setName:[group valueForProperty:kABGroupNameProperty]];
	[node setIconName:@"folder"];
	
	NSMutableArray *people = [NSMutableArray array];
	NSEnumerator *e = [[group members] objectEnumerator];
	ABPerson *cur;
	NSString *imgPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"contact" ofType:@"png"];
	NSImage *noAvatarImage = [[NSImage alloc] initWithContentsOfFile:imgPath];
	
	while (cur = [e nextObject])
	{
		NSString *firstName = [cur valueForProperty:kABFirstNameProperty];
		NSString *lastName = [cur valueForProperty:kABLastNameProperty];
		ABMultiValue *emails = [cur valueForProperty:kABEmailProperty];
		NSString *home = nil;
		if ([emails indexForIdentifier:kABEmailHomeLabel] != NSNotFound)
		{
			home = [emails valueAtIndex:[emails indexForIdentifier:kABEmailHomeLabel]];
		}
		NSString *work = nil;
		if ([emails indexForIdentifier:kABEmailWorkLabel] != NSNotFound)
		{
			work = [emails valueAtIndex:[emails indexForIdentifier:kABEmailWorkLabel]];
		}
		NSData *iconData = [cur imageData];
		NSImage *icon = nil;
		
		if (iconData)
		{
			icon = [[NSImage alloc] initWithData:iconData];
		}
		else
		{
			icon = [noAvatarImage retain];
		}
		
		NSMutableDictionary *rec = [NSMutableDictionary dictionary];
		
		if (firstName) [rec setObject:firstName forKey:@"FirstName"];
		if (lastName) [rec setObject:lastName forKey:@"LastName"];
		[rec setObject:[NSString stringWithFormat:@"%@ %@", firstName, lastName] forKey:@"Caption"];
		[rec setObject:[NSString stringWithFormat:@"%@ %@", firstName, lastName] forKey:@"ThumbPath"];
		[rec setObject:[NSString stringWithFormat:@"%@ %@", firstName, lastName] forKey:@"ImagePath"];
#warning TODO: it will probably be much faster NOT to load any thumbnails until they are actually needed, THEN cache them.
		[rec setObject:icon forKey:@"CachedThumb"];
		NSMutableArray *emls = [NSMutableArray array];
		if (home) [emls addObject:home];
		if (work) [emls addObject:work];
		[rec setObject:emls forKey:@"EmailAddresses"];
		
		[people addObject:rec];
		
		[icon release];
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
	[root setIcon:[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:@"com.apple.AddressBook"]];
	
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
	
	return [root autorelease];
}

@end
