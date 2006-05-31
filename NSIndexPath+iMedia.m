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

#import "NSIndexPath+iMedia.h"


@implementation NSIndexPath (iMedia)

- (BOOL)isSubPathOf:(NSIndexPath *)parentPath
{
	if ([parentPath length] < [self length]) // we should have at least 1 more index in our path if we are a sub path
	{
		unsigned int parentIndex;
		unsigned int myIndex;
		unsigned int i;
		
		for (i = 0; i < [parentPath length]; i++)
		{
			parentIndex = [parentPath indexAtPosition:i];
			myIndex = [self indexAtPosition:i];
			if (parentIndex != myIndex)
			{
				return NO;
			}
		}
		return YES;
	}
	return NO;
}

- (BOOL)isPeerPathOf:(NSIndexPath *)peerPath
{
	NSIndexPath *me = [self indexPathByRemovingLastIndex];
	NSIndexPath *other = [peerPath indexPathByRemovingLastIndex];
	
	return ([me length] > 0) && ([me compare:other] == NSOrderedSame);
}

@end
