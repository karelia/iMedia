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

#import "IMBImageCaptureParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBConfig.h"
#import "IMBLibraryController.h"
#import "IMBNodeObject.h"
#import "IMBObjectPromise.h"
#import "IMBOperationQueue.h"
#import <Carbon/Carbon.h>
#import <Quartz/Quartz.h>

//----------------------------------------------------------------------------------------------------------------------

@interface  IMBMTPObjectPromise : IMBRemoteObjectPromise
{ 
	long long _bytesTotal;
	long long _bytesDone;
	
}
@property (assign,readonly) long long bytesTotal;
@property (assign,readonly) long long bytesDone;

- (id) initWithObjects:(NSArray *)inObjects;
@end

@interface IMBImageCaptureParser (internal)
- (void) installNotification;
- (void) uninstallNotification;
- (BOOL) _isAppropriateICAType:(uint32_t) inType;
- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode;
- (void) _gotICANotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary;
- (IMBNode *) _nodeForDevicelist;
- (IMBNode *) _nodeForDevice:(NSDictionary *) anDevice;
- (IMBNode *) _nodeForTempDevice:(NSDictionary *) anDevice;
@end

#ifdef __DEBUGGING__
#define DEBUGLOG( fmt, ... ) NSLog( fmt, __VA_ARGS__ )
#else
#define DEBUGLOG( fmt, ... ) {}
#endif


//----------------------------------------------------------------------------------------------------------------------

// class to proxy thumbnails that get lazily downloaded 
@interface MTPVisualObject: IMBObject
{
}
- (void) _gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr;

@end

//----------------------------------------------------------------------------------------------------------------------

@implementation IMBImageCaptureParser

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[pool release];
}

#pragma mark 
#pragma mark Parser Methods

- (id) initWithMediaType:(NSString *) anType
{
	self = [super initWithMediaType:anType];
	if (self != nil) {		
		loadingDevices = [NSMutableDictionary new];
		
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
	[loadingDevices release];
	self.mediaSource = nil;
	[super dealloc];
}

- (IMBObjectPromise*) objectPromiseWithObjects:(NSArray*)inObjects 
{
	IMBMTPObjectPromise *promise = [[IMBMTPObjectPromise alloc] initWithObjects:inObjects];
	return [promise autorelease];
}

- (NSString *) identifierForICAObject:(id) anObjectID
{
	NSString* parserClassName = NSStringFromClass([self class]);
	if( ![anObjectID isKindOfClass:[NSString class]] )
		anObjectID = [anObjectID stringValue];
	NSString *path = [anObjectID stringByStandardizingPath];
	
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,path];	
}
	  
// copy a given node

- (IMBNode *) nodeCopy:(const IMBNode*)inOldNode
{		
	IMBNode* newNode = [[IMBNode alloc] init];
	
	newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = inOldNode.mediaSource;
	newNode.identifier = inOldNode.identifier; 
	newNode.name = inOldNode.name;
	newNode.icon = inOldNode.icon;
	newNode.parser = self;
	newNode.leaf = inOldNode.leaf;
	newNode.group = inOldNode.group;
	newNode.groupType = kIMBGroupTypeNone;
	
	// Enable ICA Event watching for all nodes...
	newNode.watcherType = kIMBWatcherTypeFirstCustom;
	newNode.watchedPath = inOldNode.watchedPath;
	
	[self populateNode:newNode options:0 error:nil];
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
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeImage];
			break;
		case kICAFileMovie:
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeMovie];
			break;
		case kICAFileAudio:
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeAudio];
			break;
	}
	return isOurType;
}

- (void) _addICAObject:(NSDictionary *) anItem toArray:(NSMutableArray *) objectArray
{	
	uint32_t type = [[anItem valueForKey:@"file"] intValue];
	NSUInteger index = 0;

	if( [self _isAppropriateICAType:type] )
	{
		MTPVisualObject* object = [MTPVisualObject new];
		object.location = [[anItem valueForKey:@"icao"] stringValue];
		object.name = [anItem valueForKey:@"ifil"];
		object.metadata = anItem;
		object.parser = self;
		object.index = index++;

		[objectArray addObject:object];
		
		[object release];
	}
}

// ---------------------------------------------------------------------------------------------------------------------
- (NSImage *) _getThumbnailSync:(id) anObject
{
	NSImage *image = NULL;
	NSData *data = NULL;
    ICACopyObjectThumbnailPB    pb = { 0  };
    
    pb.header.refcon   = 0L; // (unsigned long) self;
    pb.thumbnailFormat = kICAThumbnailFormatTIFF; // gives transparency
    // use the ICAObject out of the mDeviceDictionary
    pb.object          = [anObject intValue];
	pb.thumbnailData   = (CFDataRef*) &data;
    
    // asynchronous call - callback proc will get called when call completes
    /*err =*/ ICACopyObjectThumbnail( &pb, NULL );
	if (noErr == pb.header.err)
    {
        // got the thumbnail data, now create an image...
        // NSData * data  = (NSData*)*(pb.thumbnailData);		
        image = [[NSImage alloc] initWithData:data];
		[image setScalesWhenResized:YES];
		[image setSize:NSMakeSize(16.0,16.0)];
		[data release];
		DEBUGLOG( @"%s -> %@", __PRETTY_FUNCTION__, self );
    }
	return [image autorelease];
}

// recursive creation of subtree nodes 
// R: object had children

- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode
{
	DEBUGLOG( @"%s\n inNode %@",__PRETTY_FUNCTION__, inNode );

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
				subnode.wantsRecursiveObjects = YES;
				
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
	DEBUGLOG( @"%s\n inNode %@",__PRETTY_FUNCTION__, inNode );

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

			NSArray *devices = [propertiesDict valueForKey:(NSString *)kICADevicesArrayKey];
			if( devices ) // we retrieved a device list
			{
				NSMutableArray *subnodes = [NSMutableArray array];
				NSMutableArray *deviceIdentifiers = [NSMutableArray array];
				
				// we handled the root node. populate subnodes
				for( NSDictionary *anDevice in devices )
				{
					[deviceIdentifiers addObject:[anDevice valueForKey:@"icao"]];

					IMBNode* subnode = [self _nodeForDevice:anDevice];
					subnode.parentNode = inNode;
					[subnodes addObject:subnode];
				}

				inNode.subNodes = subnodes;
				inNode.objects = [NSArray array]; // prevent endless loop
				
				// now add any unlisted devices with an placeholder node
				NSArray *loadingIdentifiers = [loadingDevices allKeys];
				for( id anKey in loadingIdentifiers )
				{
					if( ![deviceIdentifiers containsObject:anKey] )
					{
						[subnodes addObject:[self _nodeForTempDevice:[loadingDevices objectForKey:anKey]]];
					}
				}
				
			}
			else 
				[self _addICATree:[(NSDictionary *)propertiesDict valueForKey:@"tree"] toNode:inNode];
				
			CFRelease( propertiesDict );
		}	
	}
	
	if (outError) *outError = error;
	return error == nil;
}

// populate the node for the device list

- (IMBNode *) _nodeForDevicelist
{
	DEBUGLOG( @"%s",__PRETTY_FUNCTION__ );
	
	BOOL showsGroupNodes = [IMBConfig showsGroupNodes];
	
	NSString* path = [self.mediaSource stringByStandardizingPath];
	NSString* name = NSLocalizedStringWithDefaultValue(
													   @"Devices",
													   nil,IMBBundle(),
													   @"Devices",
													   @"Caption for Image Capture Root node");
	
	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[IMBNode alloc] init];
	
	// newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = path;
	newNode.identifier = [self identifierForICAObject:self.mediaSource];
	
	newNode.name = showsGroupNodes ? [name uppercaseString] : name;
	newNode.parser = self;
	newNode.leaf = NO;
	
	if( !showsGroupNodes ) 
		newNode.icon = [[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Image Capture.app"];
	
	newNode.group = showsGroupNodes;
	newNode.groupType = kIMBGroupTypeNone;
	
	// Enable ICA Event watching for all nodes...
	newNode.watcherType = kIMBWatcherTypeFirstCustom;
	newNode.watchedPath = path;
	
	[self populateNode:newNode options:0 error:nil];
	return [newNode autorelease];
}

// populate the node for an single device

- (IMBNode *) _nodeForDevice:(NSDictionary *) anDevice
{
	DEBUGLOG( @"%s: device %@",__PRETTY_FUNCTION__, anDevice );

	NSString* parserClassName = NSStringFromClass([self class]);
	
	IMBNode* subnode = [IMBNode new];
	
	subnode.mediaSource = [anDevice valueForKey:@"icao"];
	
	subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,subnode.mediaSource];
	NSString *name = [anDevice valueForKey:@"ICAUserdefinedName"];
	if( !name || ![name length] )
		name = [anDevice valueForKey:@"ifil"];
	subnode.name = name;
	subnode.icon = [self _getThumbnailSync:subnode.mediaSource]; 
	subnode.parser = self;
	subnode.leaf = NO;
	subnode.wantsRecursiveObjects = YES;
	
	subnode.attributes = anDevice;
	return [subnode autorelease];
}

- (IMBNode *) _nodeForTempDevice:(NSDictionary *) anDevice
{
	DEBUGLOG( @"%s\n temp %@",__PRETTY_FUNCTION__, anDevice );

	NSString* parserClassName = NSStringFromClass([self class]);
	
	IMBNode* subnode = [IMBNode new];
	
	subnode.mediaSource = [anDevice valueForKey:@"icao"];
	
	subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,subnode.mediaSource];
	NSString *name = NSLocalizedString( @"Loading...", @"Caption for loading camera" );
	subnode.name = name;
	//	subnode.icon = [self _getThumbnailSync:subnode.mediaSource]; 
	subnode.parser = self;
	subnode.group = NO;
	subnode.leaf = YES;
	subnode.wantsRecursiveObjects = NO;
	subnode.loading = YES;
	
	subnode.attributes = anDevice;
	return [subnode autorelease];
}

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	DEBUGLOG( @"%s: old %@",__PRETTY_FUNCTION__, inOldNode );

	NSError* error = nil;
	
	// note: if inOldNode is nil, this represents the device list root object
	IMBNode* newNode = nil;
	
	if( inOldNode )
	{
		newNode = [[self nodeCopy:inOldNode] autorelease];
		// already done in copyNode:
		// if ( [inOldNode.subNodes count] || [inOldNode.objects count]  )
		// { 	// If the old node had subnodes, then look for subnodes in the new node...
		// 	[self populateNode:newNode options:inOptions error:&error];
		// }
	}
	else
		newNode = [self _nodeForDevicelist];
	
	if (outError) *outError = error;
	return newNode;
}

#pragma mark Image Capture

// watching:
static void ICANotificationCallback(CFStringRef notificationType, CFDictionaryRef notificationDictionary)
{
	id self_ = [[(NSDictionary *)notificationDictionary valueForKey:@"ICARefconKey"] pointerValue];
	[self_ _gotICANotification:(NSString *)notificationType withDictionary:(NSDictionary *)notificationDictionary];
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
							
							
	pb.notificationProc	 = ICANotificationCallback;
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
	pb.notificationProc	 = ICANotificationCallback;
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
- (void) _gotICANotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary
{
	DEBUGLOG( @"%s: %@",__PRETTY_FUNCTION__, aNotification );
	DEBUGLOG( @"%@", aDictionary );
	id objectID = nil;
	// for those hardcoded string constants, probably a == comparison instead of a full isEqualTo: would be sufficient
	// trigger node change notifications:
	
	if( [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceConnectionProgress] ||
		[aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceAdded] ||
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceRemoved] )
	{ // the device list object changed..
		objectID = [aDictionary valueForKey:(NSString *)kICANotificationDeviceListICAObjectKey];
	}	

	// it might be a good idea to lock the dictionary access here	
	// it seems the 100% read notification arrives directly AFTER the device added notification 
	if( [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceConnectionProgress] )
	{ 
		/* keys set: 
		 ICAContentCatalogPercentCompletedKey,			 
		 ICANotificationDeviceICAObjectKey == ICANotificationICAObjectKey,
		 ICANotificationDeviceListICAObjectKey
		 */ 
		
		@synchronized( loadingDevices ) 
		{
			id percentCompleted = [aDictionary valueForKey:(NSString *) kICANotificationPercentDownloadedKey];
			if( [percentCompleted intValue] < 100 )
			{
				id deviceID = [aDictionary objectForKey:(NSString *)kICANotificationDeviceICAObjectKey];
			// from some point ICAUserdefinedName is also set. reload?
				NSDictionary *deviceDict = 
					[NSDictionary dictionaryWithObjectsAndKeys:
						percentCompleted, kICANotificationPercentDownloadedKey,
						deviceID, @"icao",
					 nil];
				[loadingDevices setObject:deviceDict forKey:deviceID];
			}
			else 
			{
				[loadingDevices setObject:nil forKey:objectID];
			}
		}  // end  lock
	}
	
	if( !objectID && 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreAdded] || 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreRemoved] )
	{ // Reload the device:
		objectID =  [aDictionary valueForKey:(NSString *)kICANotificationDeviceICAObjectKey];
	} 
	
	if( objectID )
	{
//		NSString *identifier = [self identifierForICAObject:objectID];
		
		// find it in the node tree
		IMBLibraryController *libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
		
		IMBNode *rootNode = [libController rootNodeForParser:self];
		[libController reloadNode:rootNode parser:self];
	}
 
}
@end 

@implementation MTPVisualObject

// ---------------------------------------------------------------------------------------------------------------------
static void ICAThumbnailCallback (ICAHeader* pbHeader)
{
    // we use the refcon to get back to the ICAHandler
    MTPVisualObject * handler = (MTPVisualObject *)pbHeader->refcon;
    if (handler)
        [handler _gotThumbnailCallback: (ICACopyObjectThumbnailPB*) pbHeader];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		// properties of the baseclass -> no need for implementing dealloc
		self.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
		self.imageVersion = 1;
	}
	return self;
}


// ---------------------------------------------------------------------------------------------------------------------
- (void) _gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr
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
		DEBUGLOG( @"Received Thumbnail %@", self );
    }
}

// ---------------------------------------------------------------------------------------------------------------------
- (void) _getThumbnail
{
	self.isLoading = YES;
    ICACopyObjectThumbnailPB    pb = { };
    
    pb.header.refcon   = (unsigned long) self;
    pb.thumbnailFormat = kICAThumbnailFormatJPEG;
    // use the ICAObject out of the mDeviceDictionary
    pb.object          = (ICAObject)[self.location integerValue];
    
    ICACopyObjectThumbnail(&pb, ICAThumbnailCallback );
	
	DEBUGLOG( @"Loading Thumbnail %@", self );
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

#pragma mark -
//------------------------------

@interface  IMBMTPDownloadOperation : NSOperation
{ 
	NSString *downloadFolderPath;
	NSString *receivedFilePath;
	ICAObject objectID;
	long long fileSize;
	id delegate;
}
@property (nonatomic, assign, readonly) ICAObject objectID;
@property (nonatomic, assign, readonly) id delegate;
@property (nonatomic, assign) long long fileSize;

@property (nonatomic, copy)		NSString *downloadFolderPath; 
@property (nonatomic, copy)		NSString *receivedFilePath;
@end

@implementation IMBMTPDownloadOperation
@synthesize delegate;
@synthesize fileSize; 
@synthesize objectID;
@synthesize downloadFolderPath;
@synthesize receivedFilePath;

- (id) initWithObject:(IMBObject *) anObject delegate:(id) aDelegate
{
	self = [super init];
	if (self != nil) {
		objectID = [anObject.location intValue];
		// NSLog( @"File metadata: %@", anObject.metadata );
		fileSize = [[anObject.metadata valueForKey:@"isiz"] longLongValue];
		delegate = aDelegate;
	}
	return self;
}

- (void) dealloc 
{
	[super dealloc];
}

- (void) main
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
/*	NSString* downloadFolderPath = self.downloadFolderPath;
	NSString* filename = [[self.remoteURL path] lastPathComponent];
	NSString* localFilePath = [downloadFolderPath stringByAppendingPathComponent:filename]; */ 
	
	NSLog( @"Downloading file %x", objectID );
	
	do // prepare for multiple files
	{
		
		FSRef downloadFolder, fileFSRef; 
		if( CFURLGetFSRef ( (CFURLRef)[NSURL fileURLWithPath:self.downloadFolderPath], &downloadFolder ) )
			; // we have an destination 
		else {
			return ; // error. No place to download. return 
		}
		
		ICADownloadFilePB pb = { 0 };
		pb.header.refcon   = (unsigned long) self;
		OSStatus err;
		
		pb.object          = objectID;
		pb.dirFSRef		   = &downloadFolder; //  FSRef of destination directiory
		pb.fileType = pb.fileCreator = 0; // not used any more
		pb.rotationAngle = 0; //  Rotation angle in steps of 90 degress.
		pb.fileFSRef = &fileFSRef; // don't care where the file ends up
	
		err = ICADownloadFile(&pb, nil);
		if( !err ) 
		{
			if( [delegate respondsToSelector:@selector( operationDidFinish: )] )
				[(id)delegate operationDidFinish:self];
		}
		
		if( err )
		{
			if( [delegate respondsToSelector:@selector( operation:didReceiveError: )])
				[(id)delegate operation:self didReceiveError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
		}
		
		NSURL *fileURL = (NSURL *)CFURLCreateFromFSRef( kCFAllocatorDefault, &fileFSRef );
		self.receivedFilePath = [fileURL path];
		[fileURL release];
		
		NSLog( @"Did download file %x to %@ (error:%i)", objectID, self.receivedFilePath, err );
	}while( 0 );
	
	[pool release];
}

- (long long) bytesDone 
{
	return 0LL;
}

- (NSString *) localPath 
{
	return nil;
}

@end

//----------------------------------------------------------------------------------------------------------------------

#pragma mark - 
// FIXME: relies on private methods of IMBRemoteObjectPromise

@implementation IMBMTPObjectPromise
@synthesize bytesTotal = _bytesTotal;
@synthesize bytesDone = _bytesDone;

- (void) _loadObjects:(NSArray*)inObjects
{	
	// Retain self until all download operations have finished. We are going to release self in the   
	// didFinish: and didReceiveError: delegate messages...
	
	[self retain];
	
	// Show the progress, which is indeterminate for now as we do not know the file sizes yet...
	
	[self _prepareProgress];
	
	// Create all download operations...
	
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBNodeObject class]])
		{
			// id objectID = [(IMBObject *)object location];
			IMBMTPDownloadOperation* op = [[IMBMTPDownloadOperation alloc] initWithObject:object delegate:self];
			op.downloadFolderPath = self.downloadFolderPath;
			[self.downloadOperations addObject:op];
			[op release];
		}
	}
	
	// Get combined file sizes so that the progress bar can be configured...
	
	_totalBytes = 0;
	
	for (IMBMTPDownloadOperation* op in self.downloadOperations)
	{
		_totalBytes += [op fileSize];
	}
	
	// Start downloading...
	
	for (IMBMTPDownloadOperation* op in self.downloadOperations)
	{
		[[IMBOperationQueue sharedQueue] addOperation:op];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) cancel:(id)inSender
{
	// Cancel outstanding operations...
	
	for (IMBMTPDownloadOperation* op in self.downloadOperations)
	{
		[op cancel];
	}
	
	// Trash any files that we already have...
	
	NSFileManager* mgr = [NSFileManager threadSafeManager];
	
	/*	
	 for (NSURL* url in self.localURLs)
	 {
		 if ([url isFileURL])
		 {
			 NSError* error = nil;
			 [mgr removeItemAtPath:[url path] error:&error];
		 }
	 }
	 */ 
	
	// Cleanup...
	
	[self _cleanupProgress];
	
	[self performSelectorOnMainThread:@selector(_didFinish) 
						   withObject:nil 
						waitUntilDone:YES 
								modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	
	[self release];
}


//----------------------------------------------------------------------------------------------------------------------


// We received some data, so display the current progress...
/* 
- (void) operationDidReceiveData:(IMBMTPDownloadOperation*)inOperation
{
	_currentBytes = 0;
	
	for (IMBMTPDownloadOperation* op in self.downloadOperations)
	{
		_currentBytes += [op bytesDone];
	}
	
	double fraction = (double)_currentBytes / (double)_totalBytes;
	[self _displayProgress:fraction];
}
*/ 

// A download has finished. Store the path to the downloaded file. Once all downloads are complete, we can hide 
// the progress UI, Notify the delegate and release self...

- (void) operationDidFinish:(IMBMTPDownloadOperation*)inOperation
{
	// [self.localFiles addObject:inOperation.localPath];
	_objectCountLoaded++;
	
	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self _cleanupProgress];
		
		[self performSelectorOnMainThread:@selector(_didFinish) 
							   withObject:nil 
							waitUntilDone:YES 
									modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
		[self release];
	}	  
}


// If an error has occured in one of the downloads, then store the error instead of the file path, but everything 
// else is the same as in the previous method...

- (void) operation:(IMBMTPDownloadOperation*)inOperation didReceiveError:(NSError *) anError
{
	// [self.localFiles addObject:anError];
	self.error = anError;
	_objectCountLoaded++;
	
	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self _cleanupProgress];
		
		[self performSelectorOnMainThread:@selector(_didFinish) 
							   withObject:nil 
							waitUntilDone:YES 
									modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
		[self release];
	}	  
}

@end
