//
//  EpegWrapper.h
//  Epeg
//
//  Created by Marc Liyanage on Fri Jan 16 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EpegWrapper : NSObject {

	
}

+ (NSImage *)imageWithPath:(NSString *)path boundingBox:(NSSize)boundingBox;
+ (NSImage *)imageWithPath2:(NSString *)path boundingBox:(NSSize)boundingBox;

@end
