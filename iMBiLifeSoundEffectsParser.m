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

#import "iMBiLifeSoundEffectsParser.h"
#import "iMedia.h"
#import "iMBMusicFolder.h"

@implementation iMBiLifeSoundEffectsParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"music"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:@"/Library/Audio/Apple Loops/Apple/iLife Sound Effects/"])
	{
		
	}
	return self;
}

- (iMBLibraryNode *)parseDatabase
{
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:[self databasePath]]) return nil;
	
	iMBMusicFolder *parser = [[iMBMusicFolder alloc] initWithContentsOfFile:[self databasePath]];
	[parser setParseMetaData:NO];
	[parser setUnknownArtist:LocalizedStringInThisBundle(@"Apple Loop", @"Artist")];
	
	iMBLibraryNode *sfx = [parser parseDatabase];
	[sfx setName:LocalizedStringInThisBundle(@"iLife Sound Effects", @"iLife Sound Effects folder name")];
	[sfx setIconName:@"MBSoundEffect"];
	[parser release];
	
	return sfx;
}

@end
