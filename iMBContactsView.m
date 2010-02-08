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

#import "iMBContactsView.h"
#import "iMediaConfiguration.h"
#import "NSPasteboard+iMedia.h"
#import "MUPhotoView.h"

#import <AddressBook/AddressBook.h>


@implementation iMBContactsView

- (void)loadViewNib
{
	[super loadViewNib];
	finishedInit = YES; // so we know when the abstract view has finished so awakeFromNib doesn't get called twice
	[NSBundle loadNibNamed:@"Contacts" owner:self];
}

- (void)awakeFromNib
{
    if ( finishedInit )
    {
        [super awakeFromNib];

        [photoView setShowCaptions:[[iMediaConfiguration sharedConfiguration] prefersFilenamesInPhotoBasedBrowsers]];
    }
}

- (void)dealloc
{
    [mySelection release];
    [myImages release];
    [myFilteredImages release];
    [mySearchString release];
    
    [super dealloc];
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSString *p = [[NSBundle bundleForClass:[self class]] pathForResource:@"contacts" ofType:@"png"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
		[_toolbarIcon setSize:NSMakeSize(32,32)];
	}
	return _toolbarIcon;
}

- (NSString *)mediaType
{
	return @"contacts";
}

- (NSString *)name
{
	return LocalizedStringInIMedia(@"Contacts", @"Name of Data Type");
}

- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	
	[pboard declareTypes:types owner:nil];
	
	NSArray *content = nil; //[oLinkController arrangedObjects];
	NSEnumerator *e = [rows objectEnumerator];
	NSNumber *cur;
	NSMutableArray *urls = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
    	
	while (cur = [e nextObject])
	{
        unsigned int contextIndex = [cur unsignedIntValue];
		NSDictionary *link = [content objectAtIndex:contextIndex];
		NSString *loc = [link objectForKey:@"URL"];
		
		NSURL *url = [NSURL URLWithString:loc];
		[urls addObject:url];
        
        [titles addObject:[link objectForKey:@"Name"]];
        
	}
 	[pboard writeURLs:urls files:nil names:titles];

	return YES;
}

- (void)writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSMutableArray *types = [NSMutableArray array]; // OLD BEHAVIOR: arrayWithArray:[pboard types]];
	[types addObjectsFromArray:[NSPasteboard fileAndURLTypes]];
	[types addObjectsFromArray:[NSArray arrayWithObjects:@"ABPeopleUIDsPboardType", @"Apple VCard pasteboard type", nil]];
   [types addObject:iMBNativePasteboardFlavor]; // Native iMB Data
	[pboard declareTypes:types  owner:nil];
	NSMutableArray *vcards = [NSMutableArray array];
	NSMutableArray *urls = [NSMutableArray array];
	NSMutableArray *files = [NSMutableArray array];
    NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *uids = [NSMutableArray array];
	
	NSEnumerator *e = [items objectEnumerator];
	NSDictionary *cur;
	NSString *dir = NSTemporaryDirectory();
	[[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
   NSMutableArray* nativeDataArray = [NSMutableArray arrayWithCapacity:[items count]];
	while (cur = [e nextObject])
	{
		ABPerson *person = [cur objectForKey:@"ABPerson"];
		NSData *vcard = [person vCardRepresentation];
		[vcards addObject:[[[NSString alloc] initWithData:vcard encoding:NSUTF8StringEncoding] autorelease]];
		NSString *vCardFile = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.vcf", [cur objectForKey:@"Caption"]]];
		[vcard writeToFile:vCardFile atomically:YES];
		[files addObject:vCardFile];
		[uids addObject:[person uniqueId]];
		
      [nativeDataArray addObject:cur];

		NSArray *emails = [cur objectForKey:@"EmailAddresses"];
		if ([emails count] > 0)
		{
			[urls addObject:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@",[emails objectAtIndex:0]]]];
		}
		else
		{
			[urls addObject:[NSURL fileURLWithPath:vCardFile]];
		}
		
        [titles addObject:[cur objectForKey:@"Caption"]];
	}
   NSDictionary* nativeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [self className], iMBControllerClassName,
                                             nativeDataArray, iMBNativeDataArray,
                                             nil];
   [pboard setData:[NSArchiver archivedDataWithRootObject:nativeData] forType:iMBNativePasteboardFlavor]; // Native iMB Data
 	[pboard writeURLs:urls files:nil names:titles];
	[pboard setPropertyList:[vcards componentsJoinedByString:@"\n"] forType:@"Apple VCard pasteboard type"];
	[pboard setPropertyList:uids forType:@"ABPeopleUIDsPboardType"];
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	[self writeItems:[playlist valueForKey:@"People"] toPasteboard:pboard];
}

@end
