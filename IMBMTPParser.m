/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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

//  Created by Thomas Engelmeier on 25.07.09.
//  Copyright 2009 Thomas Engelmeier. All rights reserved.


//----------------------------------------------------------------------------------------------------------------------


#import "IMBMTPParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBLibraryController.h"
#import <Carbon/Carbon.h>
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


@interface IMBMTPParser (internal)
- (void) installNotification;
- (void) uninstallNotification;
- (BOOL) _isAppropriateICAType:(uint32_t) inType;
- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode;
- (void) _handleNotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary;
@end


//----------------------------------------------------------------------------------------------------------------------


// class to proxy thumbnails that get lazily downloaded 
@interface MTPVisualObject: IMBVisualObject
{
	BOOL _isLoading;
}
@property (readwrite, assign) BOOL isLoading;

- (void) gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr;

@end


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBMTPParser

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBPhotosMediaType];
	[pool release];
}

#pragma mark 
#pragma mark Parser Methods

- (id) initWithMediaType:(NSString *) anType
{
	self = [super initWithMediaType:anType];
	if (self != nil) {		
		// we prepopulate the root mediasource with the ICA ID of the list of cameras
		ICAGetDeviceListPB deviceListPB;
		memset( &deviceListPB, 0, sizeof( ICAGetDeviceListPB ));		
		OSStatus err = ICAGetDeviceList((ICAGetDeviceListPB *)&deviceListPB, NULL);
		if( err == noErr )
		{
			self.mediaSource = [[NSNumber numberWithInt:deviceListPB.object] stringValue];
			[self installNotification];
		}
	}
	return self;
}

- (void) dealloc
{
	[self uninstallNotification];
	self.mediaSource = nil;
	[super dealloc];
}

- (NSString *) identifierForICAObject:(id) anObjectID
{
	NSString* parserClassName = NSStringFromClass([self class]);
	if( ![anObjectID isKindOfClass:[NSString class]] )
		anObjectID = [anObjectID stringValue];
	NSString *path = [anObjectID stringByStandardizingPath];
	
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,path];	
}
	  
- (IMBNode *) nodeCopy:(IMBNode*)inOldNode
{
	NSString* path = inOldNode ? inOldNode.mediaSource : self.mediaSource;
	path = [path stringByStandardizingPath];
	
	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[[IMBNode alloc] init] autorelease];
	
	newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = path;
	newNode.identifier = [self identifierForICAObject:self.mediaSource];
	newNode.name = NSLocalizedString( @"Camera Devices", @"Caption for Image Capture Root node" ); 
	newNode.icon = inOldNode.icon;
	if ( !newNode.icon ) {
		newNode.icon = [[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Image Capture.app"];
	}
	newNode.parser = self;
	newNode.leaf = NO;
	
	// Enable ICA Event watching for all nodes...
	newNode.watcherType = kIMBWatcherTypeFirstCustom;
	newNode.watchedPath = path;
	
	return newNode;
}

- (IMBNode*) nodeWithOldNode:(IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	// note: if inOldNode is nil, this represents the device list root object
	IMBNode* newNode = [self nodeCopy:inOldNode];
	
	// If the old node had subnodes, then look for subnodes in the new node...
	
	if ([inOldNode.subNodes count] || [inOldNode.objects count] )
	{
		[self populateNode:newNode options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) _isAppropriateICAType:(uint32_t) inType
{
	BOOL isOurType = NO;
	switch( inType )
	{
/* 		case kICADevice:
		case kICADeviceCamera:
		case kICADeviceScanner:
		case kICADeviceMFP:
		case kICADevicePhone:
		case kICADevicePDA:
		case kICADeviceOther:
		case kICAList:	
		case kICADirectory: 
		case kICAFile: 
		case kICAFileFirmware:
		case kICAFileOther:
 */ 
		case kICAFileImage:
			isOurType = [self.mediaType isEqualTo:kIMBPhotosMediaType];
			break;
		case kICAFileMovie:
			isOurType = [self.mediaType isEqualTo:kIMBMoviesMediaType];
			break;
		case kICAFileAudio:
			isOurType = [self.mediaType isEqualTo:kIMBMusicMediaType];
			break;
	}
	return isOurType;
}

- (void) _addICAObject:(NSDictionary *) anItem toArray:(NSMutableArray *) objectArray
{	
	uint32_t type = [[anItem valueForKey:@"file"] intValue];
	if( [self _isAppropriateICAType:type] )
	{
		IMBObject* object = [MTPVisualObject new];
		object.value = [[anItem valueForKey:@"icao"] stringValue];
		object.name = [anItem valueForKey:@"ifil"];
		object.metadata = anItem;
		[objectArray addObject:object];
		
		[object release];
	}
}

// ---------------------------------------------------------------------------------------------------------------------
- (NSImage *) _getThumbnailSync:(id) anObject
{
	NSImage *image = NULL;
	NSData *data = NULL;
    OSErr   err;
    ICACopyObjectThumbnailPB    pb = { 0  };
    
    pb.header.refcon   = 0L; // (unsigned long) self;
    pb.thumbnailFormat = kICAThumbnailFormatTIFF; // gives transparency
    // use the ICAObject out of the mDeviceDictionary
    pb.object          = [anObject intValue];
	pb.thumbnailData   = &data;
    
    // asynchronous call - callback proc will get called when call completes
    err = ICACopyObjectThumbnail( &pb, NULL );
	if (noErr == pb.header.err)
    {
        // got the thumbnail data, now create an image...
        // NSData * data  = (NSData*)*(pb.thumbnailData);		
        image = [[NSImage alloc] initWithData:data];
		[data release];
		NSLog( @"Received Thumbnail %@", self );
    }
	return [image autorelease];
}

// recursive creation of subtree nodes 
// R: object had children

- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode
{
	NSMutableArray *subnodes = [NSMutableArray array];
	NSMutableArray *objects = [NSMutableArray array];
	
	for( NSDictionary *anItem in subItems )
	{ // subitems
		uint32_t type = [[anItem valueForKey:@"file"] intValue];
		NSString *name = [anItem valueForKey:@"ifil"];
		
		if( type == kICADirectory )
		{
			if( [name length] )
			{
				NSString *imageCaptureID = [anItem valueForKey:@"icao"];
				
				IMBNode* subnode = [IMBNode new];
				subnode.parentNode = inNode;
				
				subnode.mediaSource = imageCaptureID;
				subnode.identifier = [self identifierForICAObject:imageCaptureID];
				subnode.name = name;
				// test implementation:
				if( [anItem valueForKey:@"thuP"] )
					subnode.icon = [self _getThumbnailSync:imageCaptureID];
				if( !subnode.icon )
					subnode.icon = [[NSWorkspace sharedWorkspace] iconForFileType:@"'fldr'"];
				// subnode.icon = [anItem valueForKey:(NSString *)kICAThumbnailPropertyKey];
				subnode.parser = self;
				subnode.attributes = anItem;	
				
				
				BOOL hasSubnodes = [self _addICATree:[anItem valueForKey:@"tree"] toNode:subnode];
				subnode.leaf = !hasSubnodes;
				
				[subnodes addObject:subnode];
				[subnode release];	
			}
			else 
			{
				// TE: On my Lumix, nameless containers are basically an logical group of related media. 
				// i.e. Movie plus poster image
				
				// options would be: 
				// a.) synthesize an name from the top level object
				// b.) strip the top level object and use the UTI filter to insert it in the current node
				// As iMedia is using a filtered rep, option b makes more sense
				
				NSArray *subObjects = [anItem valueForKey:@"tree"];
				NSMutableArray *tmpObjects = [NSMutableArray array];
				
				for( NSDictionary *tmpObject in subObjects )
					[self _addICAObject:tmpObject toArray:tmpObjects];
				// tbd: test if really only one object remained
				// tbd2: test if an problem occurs with later handled removal notificatons
				[objects addObjectsFromArray:tmpObjects];
				
			}

		}
		else {
			[self _addICAObject:anItem toArray:objects];			
		}
		
	}
	inNode.subNodes = subnodes;
	inNode.objects = objects;
	return [subnodes count] > 0;
	
}


// Scan the our folder for subfolders and add a subnode for each one we find...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	if( !inNode.objects ||
		!inNode.subNodes )
	{ // only populate if empty
		
		ICAObject object = [inNode.mediaSource intValue];

		ICACopyObjectPropertyDictionaryPB copyObjectsPB; 
		memset( &copyObjectsPB, 0, sizeof(ICACopyObjectPropertyDictionaryPB));

		NSDictionary *propertiesDict = NULL;
		copyObjectsPB.object = object;
		copyObjectsPB.theDict = (CFDictionaryRef *) &propertiesDict; 
		OSStatus err = ICACopyObjectPropertyDictionary(&copyObjectsPB, NULL);
		 
		if (err == noErr && noErr == copyObjectsPB.header.err )
		{
			NSLog( @"%@", propertiesDict );

			// the objects are in copyObjectsPB->theDict 
			NSArray *devices = [propertiesDict valueForKey:(NSString *)kICADevicesArrayKey];
			if( devices )
			{
				NSMutableArray *subnodes = [NSMutableArray array];

				// we handled the root node. populate subnodes
				for( NSDictionary *anDevice in devices )
				{
					NSString* parserClassName = NSStringFromClass([self class]);
					
					IMBNode* subnode = [IMBNode new];
					subnode.parentNode = inNode;
					
					subnode.mediaSource = [anDevice valueForKey:@"icao"];
					subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,subnode.mediaSource];
					NSString *name = [anDevice valueForKey:@"ICAUserdefinedName"];
					if( !name || ![name length] )
						name = [anDevice valueForKey:@"ifil"];
					subnode.name = name;
					subnode.icon = [self _getThumbnailSync:subnode.mediaSource]; 
					subnode.parser = self;
					subnode.leaf = NO;
					
					subnode.attributes = anDevice;
					[subnodes addObject:subnode];
					[subnode release];
				}
				inNode.subNodes = subnodes;
				inNode.objects = [NSArray array]; // prevent endless loop
			}
			else 
				[self _addICATree:[(NSDictionary *)propertiesDict valueForKey:@"tree"] toNode:inNode];
				
			CFRelease( propertiesDict );
		}	
	}
	
	if (outError) *outError = error;
	return error == nil;
}

#pragma mark Image Capture

// watching:
static void HandleICANotification(CFStringRef notificationType, CFDictionaryRef notificationDictionary)
{
	id self_ = [[(NSDictionary *)notificationDictionary valueForKey:@"ICARefconKey"] pointerValue];
	[self_ _handleNotification:(NSString *)notificationType withDictionary:(NSDictionary *)notificationDictionary];
}

// ———————————————————————————————————————————————————————————————————————————
// - installNotification:
// ———————————————————————————————————————————————————————————————————————————
- (void)installNotification
{
	assert( sizeof(id) <= sizeof(unsigned long)); // make sure we can store self in the refcon
    ICARegisterForEventNotificationPB pb;
    OSErr	err;
	
    memset(&pb, 0, sizeof(ICARegisterForEventNotificationPB));
    pb.header.refcon = (unsigned long)self;
    pb.objectOfInterest  = 0;	// all objects
    pb.eventsOfInterest	 = (CFArrayRef)[NSArray arrayWithObjects:
							// object level:
							///	kICANotificationTypeObjectAdded,  // when the device is connected, first a flood of those notifications arrives
								(NSString *) kICANotificationTypeObjectRemoved, 
								(NSString *) kICANotificationTypeObjectInfoChanged,
							// memory card level:
								(NSString *) kICANotificationTypeStoreAdded,
								(NSString *) kICANotificationTypeStoreRemoved,
								// kICANotificationTypeStoreFull,
								// kICANotificationTypeStoreInfoChanged,
							// device level:
								(NSString *) kICANotificationTypeDeviceAdded, // issued after all object info is retrieved
								(NSString *) kICANotificationTypeDeviceRemoved,  // issued immediately when the device goes off
								(NSString *) kICANotificationTypeDeviceInfoChanged, // issued when another driver takes over 
								(NSString *) kICANotificationTypeDeviceWasReset, 
							//	kICANotificationTypeDevicePropertyChanged, 
// the following two constants are tagged as appearing from 10.5 on in the 10.6
// but in reality they appear in the 10.6 SDK 										
//								(NSString *) kICANotificationTypeDeviceStatusInfo, 
//								(NSString *) kICANotificationTypeDeviceStatusError,
							// kICANotificationTypeCaptureComplete,
							// kICANotificationTypeRequestObjectTransfer, 
							// kICANotificationTypeTransactionCanceled, 
								(NSString *) kICANotificationTypeUnreportedStatus, 
							// kICANotificationTypeProprietary,
								(NSString *) kICANotificationTypeDeviceConnectionProgress, // useful for setting up a badge? 
							nil];
							
							
	pb.notificationProc	 = HandleICANotification;
	pb.options = NULL;
    err = ICARegisterForEventNotification(&pb, NULL);
    if (noErr == err) 
    {
        NSLog(@"ICA notification callback registered");
    }
}

- (void) uninstallNotification
{
	ICARegisterForEventNotificationPB pb;
    OSErr	err;
	
    memset(&pb, 0, sizeof(ICARegisterForEventNotificationPB));
    pb.header.refcon = (unsigned long)self;
    pb.objectOfInterest  = 0;	// all objects
    pb.eventsOfInterest	 = NULL;
	pb.notificationProc	 = HandleICANotification;
	pb.options = NULL;
    err = ICARegisterForEventNotification(&pb, NULL);
    if (noErr == err) 
    {
        NSLog(@"ICA notification callback unregistered");
    }
}


// ———————————————————————————————————————————————————————————————————————————
// - handleNotification:
// ———————————————————————————————————————————————————————————————————————————
- (void) _handleNotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary
{
	NSLog( @"ICANotification %@: %@", aNotification, aDictionary );
	
	id objectID = nil;
	// for those hardcoded string constants, probably a == comparison instead of a full isEqualTo: would be sufficient
	// trigger node change notifications:
	if( [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceAdded] ||
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceRemoved] )
	{ // the device list object changed..
		objectID = [aDictionary valueForKey:(NSString *)kICANotificationDeviceListICAObjectKey];
	}	
	
	if( !objectID && 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreAdded] || 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreRemoved] )
	{ // Reload the device:
		objectID =  [aDictionary valueForKey:(NSString *)kICANotificationDeviceICAObjectKey];
	} 
	
	if( objectID )
	{
		NSString *identifier = [self identifierForICAObject:objectID];
		
		// find it in the node tree
		IMBLibraryController *libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
		
		// trigger change notification
		IMBNode *changedNode = [libController nodeWithIdentifier:identifier];
		if( changedNode )
			[libController reloadNode:changedNode];
	}
 
 //    [self updateFiles];
}
@end 


// ---------------------------------------------------------------------------------------------------------------------
static void MyThumbnailCallback (ICAHeader* pbHeader)
{
    // we use the refcon to get back to the ICAHandler
    MTPVisualObject * handler = (MTPVisualObject *)pbHeader->refcon;
    if (handler)
        [handler gotThumbnailCallback: (ICACopyObjectThumbnailPB*) pbHeader];
}
 
@implementation MTPVisualObject
@synthesize isLoading = _isLoading;

- (id) init
{
	self = [super init];
	if (self != nil) {
		self.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
		self.imageVersion = 1;
	}
	return self;
}

// ---------------------------------------------------------------------------------------------------------------------
- (void) gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr
{
	self.isLoading = NO;
    if (noErr == pbPtr->header.err)
    {
        // got the thumbnail data, now create an image...
        NSData * data  = (NSData*)*(pbPtr->thumbnailData);		
        // NSImage* image = [[NSImage alloc] initWithData: data];
		
		self.imageRepresentation = data;
		self.imageVersion = self.imageVersion + 1;
		
        // [image release];
        [data release];
		NSLog( @"Received Thumbnail %@", self );
    }
}

// ---------------------------------------------------------------------------------------------------------------------
- (void) _getThumbnail
{
	self.isLoading = YES;
    OSErr                       err;
    ICACopyObjectThumbnailPB    pb = { };
    
    pb.header.refcon   = (unsigned long) self;
    pb.thumbnailFormat = kICAThumbnailFormatJPEG;
    // use the ICAObject out of the mDeviceDictionary
    pb.object          = (ICAObject)[self.value integerValue];
    
    // asynchronous call - callback proc will get called when call completes
    err = ICACopyObjectThumbnail(&pb, MyThumbnailCallback);
	
	NSLog( @"Loading Thumbnail %@", self );
    // ... error handling ...
}


- (NSImage *) imageRepresentation
{
	if ( !_imageRepresentation && !self.isLoading  ) {
		[self _getThumbnail];
	}
	return _imageRepresentation;
}

// UNEXPECTED behavior of the baseclass
- (NSString*) imageRepresentationType
{
	return _imageRepresentationType;
}


@end
