//
//  NSBundle+iMedia.h
//  iMediaBrowse
//
//  Created by Matthew Tonkin on 7/05/08.
//  Copyright 2008 Matthew Tonkin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSBundle (iMedia)

- (BOOL)loadNibNamed:(NSString *)aNibName owner:(id)owner;

@end
