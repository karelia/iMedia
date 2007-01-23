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

#import "NSFileManager+iMedia.h"


@implementation NSFileManager (iMedia)

- (BOOL)isPathHidden:(NSString *)path
{
	// exit early
	if ([[path lastPathComponent] hasPrefix:@"."]) return YES;
	
	BOOL isHidden = NO;
//	OSStatus ret;
//	NSURL *url = [NSURL fileURLWithPath:path];
//	LSItemInfoRecord rec;
//	
//	ret = LSCopyItemInfoForURL((CFURLRef)url, kLSRequestAllInfo, &rec);
//	if (ret == noErr)
//	{
//		if (rec.flags & kLSItemInfoIsInvisible)
//		{
//			isHidden = YES;
//		}
//	}
	return isHidden;
}


// Returns a path for caching a file at the given key (such as a file name or other unique descriptor)
// This is not like the NSURLRequest method, which seems to make a 72-bit (9-byte) hash
// and then possibly deal with collisions.  They go like this:  ~/Library/Caches/ nibble / nibble / Uint32-Uint32
// We will instead just do an SHA1 to get a pretty darn unique hash, then use the first two nibbles like they do,
// and then the rest, in hex.

#include <openssl/sha.h>

#define SHA1_CTX			SHA_CTX
#define SHA1_DIGEST_LENGTH	SHA_DIGEST_LENGTH

- (NSString *)cachePathForKey:(NSString *)aKey
{
	NSData *keyData = [aKey dataUsingEncoding:NSUTF8StringEncoding];
	// Calculate SHA1 for the key to give a nice unique hash
	static char __HEHexDigits[] = "0123456789abcdef";
	unsigned char digestString[2*SHA1_DIGEST_LENGTH];
	unsigned int i;
	SHA1_CTX ctx;
	unsigned char digest[SHA1_DIGEST_LENGTH];
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, [keyData bytes], [keyData length]);
	SHA1_Final(digest, &ctx);
	for(i=0; i<SHA1_DIGEST_LENGTH; i++)
	{
		digestString[2*i]   = __HEHexDigits[digest[i] >> 4];
		digestString[2*i+1] = __HEHexDigits[digest[i] & 0x0f];
	}

	// construct path
	static NSString *sBasePath = nil;
	if (nil == sBasePath)
	{
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
		if ([libraryPaths count])
		{
			sBasePath = [[libraryPaths objectAtIndex:0] copy];
		}
		else	// shouldn't happen but just in case, use home directory 
		{
			NSLog(@"could not find caches directory; using home directory");
			sBasePath = [NSHomeDirectory() copy];
		}
	}

	NSString *sha1String = [[[NSString alloc] initWithBytes:(const char *)digestString length:(unsigned)2*SHA1_DIGEST_LENGTH encoding:NSASCIIStringEncoding] autorelease];
	NSString *result = [NSString stringWithFormat:@"%@/%02d/%02d/%s",
		sBasePath, digest[0], digest[1], [sha1String substringFromIndex:2]];
	NSLog(@"%@ = %%@", sha1String, result);
	return result;
}

@end
