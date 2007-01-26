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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBUserPicturesParser.h"
#import "iMedia.h"
#import "iMBPicturesFolder.h"

@implementation iMBUserPicturesParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:@"/Library/User Pictures/"])
	{
		;
	}
	return self;
}

- (iMBLibraryNode *)parseDatabase
{
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:[self databasePath]]) return nil;
	
	iMBPicturesFolder *parser = [[[iMBPicturesFolder alloc] initWithContentsOfFile:[self databasePath]] autorelease];	
	iMBLibraryNode *db = [parser parseDatabase];
	if (db)
	{
		[db setName:LocalizedStringInThisBundle(@"User Pictures", @"folder name")];
		[db setIconName:@"folder"];
	}	
	return db;
}

@end
