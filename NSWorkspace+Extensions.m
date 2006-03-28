//
//  NSWorkspace+Extensions.m
//  iMediaBrowse
//
//  Created by Jason Jobe on 3/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSWorkspace+Extensions.h"


@implementation NSWorkspace (iMediaExtensions)

-(NSImage*)iconForAppWithBundleIdentifier:(NSString*)bundleID;
{
  NSString *path = [self absolutePathForAppBundleWithIdentifier:bundleID];
  return [self iconForFile:path];
}

@end
