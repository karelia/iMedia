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

#import "IMBLightroomRuleScanner.h"


static NSString *const	lightroomStartString		= @"{";
static NSString *const	lightroomStopString			= @"}";
static NSString *const	lightroomSeparatorString	= @",";
static NSString *const	lightroomQuoteString		= @"\"";
static NSString *const	lightroomEscapeString		= @"\\";
static NSString *const	lightroomAssignString		= @"=";


@implementation NSScanner (IMBLightroomRuleScanner)

+ (NSScanner *)lightroomRulesScannerWithString:(NSString *)string
{
	NSScanner *scanner = [NSScanner scannerWithString:string];

	[scanner setCharactersToBeSkipped:nil];

	return scanner;
}

- (BOOL)scanLightroomRules:(id *)rules
{
	NSMutableArray		*array		= [NSMutableArray array];
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	while (1) {
		[self scanLightroomWhiteSpace];

		NSUInteger scanLoaction = [self scanLocation];

		if ([self scanLightroomStartString]) {
			id nestedRules = nil;

			if (! [self scanLightroomRules:&nestedRules]) {
				return NO;
			}

			if (! [self scanLightroomStopString]) {
				return NO;
			}

			[array addObject:nestedRules];

			dictionary = nil;
		}
		else if ([self scanLightroomStopString]) {
			[self setScanLocation:scanLoaction];

			break;
		}
		else {
			NSString	*key	= nil;
			id			value	= nil;

			if (! [self scanLightroomString:&key]) {
				return NO;
			}

			[self scanLightroomWhiteSpace];

			if (! [self scanLightroomKeyValueSeparator]) {
				return NO;
			}

			[self scanLightroomWhiteSpace];

			if ([self scanLightroomStartString]) {
				if (! [self scanLightroomRules:&value]) {
					return NO;
				}

				if (! [self scanLightroomStopString]) {
					return NO;
				}
			}
			else if (! [self scanLightroomString:&value]) {
				return NO;
			}

			if ((key == nil) || (value == nil)) {
				return NO;
			}

			[array addObject:[NSDictionary dictionaryWithObject:value forKey:key]];

			if ([dictionary objectForKey:key] == nil) {
				[dictionary setObject:value forKey:key];
			}
			else {
				dictionary = nil;
			}
		}

		[self scanLightroomWhiteSpace];

		if (! [self scanLightroomSeparatorString]) {
			break;
		}
	}

	if (rules != NULL) {
		if (dictionary != nil) {
			*rules = dictionary;
		}
		else {
			*rules = array;
		}
	}

	return YES;
}

- (BOOL)scanLightroomString:(NSString **)string
{
	NSUInteger location = [self scanLocation];

	if ([self scanLightroomQuoteString]) {
		[self setScanLocation:location];

		return [self scanLightroomQuotedString:string];
	}

	return [self scanLightroomPlainString:string];
}

- (BOOL)scanLightroomPlainString:(NSString **)string
{
	static NSCharacterSet	*stopCharsCharacterSet	= nil;
	static dispatch_once_t	onceToken				= 0;

	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *mutableCharacterSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy] autorelease];

		[mutableCharacterSet addCharactersInString:lightroomSeparatorString];
		[mutableCharacterSet addCharactersInString:lightroomEscapeString];

		stopCharsCharacterSet = [mutableCharacterSet copy];
	});

	NSMutableString			*scannedString			= [NSMutableString string];

	while (1) {
		NSString	*fragment;

		if (! [self scanUpToCharactersFromSet:stopCharsCharacterSet intoString:&fragment]) {
			break;
		}

		[scannedString appendString:fragment];

		NSUInteger	location = [self scanLocation];

		if ([self scanLightroomEscapeString]) {
			if ([self scanLightroomEscapeString]) {
				[scannedString appendString:lightroomEscapeString];
			}
			else {
				[self setScanLocation:location];

				if (! [self scanLightroomEscapeSequence:&fragment]) {
					return NO;
				}

				[scannedString appendString:fragment];
			}
		}
	}

	if ([scannedString length] > 0) {
		if (string != NULL) {
			*string = scannedString;
		}

		return YES;
	}

	return NO;
}

- (BOOL)scanLightroomQuotedString:(NSString **)string
{
	if (! [self scanLightroomQuoteString]) {
		return NO;
	}

	static NSCharacterSet	*stopCharsCharacterSet	= nil;
	static dispatch_once_t	onceToken				= 0;

	dispatch_once(&onceToken, ^{
		NSMutableCharacterSet *mutableCharacterSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy] autorelease];

		[mutableCharacterSet addCharactersInString:lightroomQuoteString];
		[mutableCharacterSet addCharactersInString:lightroomEscapeString];

		stopCharsCharacterSet = [mutableCharacterSet copy];
	});

	NSMutableString			*scannedString			= [NSMutableString string];

	while (1) {
		NSString	*fragment;

		if (! [self scanUpToCharactersFromSet:stopCharsCharacterSet intoString:&fragment]) {
			break;
		}

		[scannedString appendString:fragment];

		NSUInteger	location = [self scanLocation];

		if ([self scanLightroomEscapeString]) {
			if ([self scanLightroomEscapeString]) {
				[scannedString appendString:lightroomEscapeString];
			}
			else if ([self scanLightroomQuoteString]) {
				[scannedString appendString:lightroomQuoteString];
			}
			else {
				[self setScanLocation:location];

				if (! [self scanLightroomEscapeSequence:&fragment]) {
					return NO;
				}

				[scannedString appendString:fragment];
			}
		}
	}

	if (! [self scanLightroomQuoteString]) {
		return NO;
	}

	if (string != NULL) {
		*string = scannedString;
	}
	
	return YES;
}

- (BOOL)scanLightroomEscapeSequence:(NSString **)string
{
	if (![self scanLightroomEscapeString]) {
		return NO;
	}

	if ([self isAtEnd]) {
		return NO;
	}

	NSString	*scannedString	= nil;

	NSUInteger	location		= [self scanLocation];
	unichar		currentChar		= [[self string] characterAtIndex:location];

	[self setScanLocation:(location + 1)];

	switch (currentChar) {
		case '\\':
			scannedString	= @"\\";
			break;

		case '/':
			scannedString	= @"/";
			break;

		case 'b':
			scannedString	= @"\b";
			break;

		case 'f':
			scannedString	= @"\f";
			break;

		case 'n':
			scannedString	= @"\n";
			break;

		case 'r':
			scannedString	= @"\r";
			break;

		case 't':
			scannedString	= @"\t";
			break;

		case 'u':
		{
			if (![self scanLightroomUnicodeSequence:&scannedString]) {
				return NO;
			}

			break;
		}

		default:
			scannedString	= [NSString stringWithFormat:@"\\%C", currentChar];
			break;
	}

	if (scannedString != nil) {
		if (string != NULL) {
			*string = scannedString;
		}

		return YES;
	}

	return NO;
}

- (BOOL)scanLightroomUnicodeSequence:(NSString **)string
{
	NSUInteger				scanLocation			= [self scanLocation];
	NSString				*scanString				= [self string];
	NSUInteger				scanStringLength		= [scanString length];
	NSUInteger				hexStringLength			= 4;

	if ((scanLocation + hexStringLength) > scanStringLength) {
		return NO;
	}

	NSString				*hexString				= [scanString substringWithRange:NSMakeRange(scanLocation, hexStringLength)];
	NSCharacterSet			*hexStringCharacterSet	= [NSCharacterSet characterSetWithCharactersInString:hexString];

	static NSCharacterSet	*hexLegalCharacterSet	= nil;
	static dispatch_once_t	onceToken				= 0;

	dispatch_once(&onceToken, ^{
		hexLegalCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"] retain];
	});

	if (! [hexLegalCharacterSet isSupersetOfSet:hexStringCharacterSet]) {
		return NO;
	}

	unsigned int			hexValue;

	if (! [self scanHexInt:hexValue]) {
		return NO;
	}

	if (string != NULL) {
		*string = [NSString stringWithFormat:@"%C", (unichar)hexValue];
	}

	return YES;
}

- (BOOL)scanLightroomStartString
{
	return [self scanString:lightroomStartString intoString:NULL];
}

- (BOOL)scanLightroomStopString
{
	return [self scanString:lightroomStopString intoString:NULL];
}

- (BOOL)scanLightroomSeparatorString
{
	return [self scanString:lightroomSeparatorString intoString:NULL];
}

- (BOOL)scanLightroomQuoteString
{
	return [self scanString:lightroomQuoteString intoString:NULL];
}

- (BOOL)scanLightroomEscapeString
{
	return [self scanString:lightroomEscapeString intoString:NULL];
}

- (BOOL)scanLightroomKeyValueSeparator
{
	return [self scanString:lightroomAssignString intoString:NULL];
}

- (BOOL)scanLightroomWhiteSpace
{
	NSCharacterSet *acceptedCharacterSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];

	return [self scanUpToCharactersFromSet:acceptedCharacterSet intoString:NULL];
}

@end
