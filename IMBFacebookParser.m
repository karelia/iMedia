//
//  IMBFacebookParser.m
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import "IMBFacebookParser.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>

#define FACEBOOK_APP_ID_XPC_SERVICE @"325097450927004"
#define FACEBOOK_APP_ID_APP_PROCESS @"421570721265438"

@interface IMBFacebookParser ()

@property (retain) ACAccountStore *accountStore;
@property (retain) ACAccount *account;

@end

@implementation IMBFacebookParser

@synthesize accountStore=_accountStore;
@synthesize account=_account;

#pragma mark - Objects Lifecycle

- (void)dealloc
{
    IMBRelease(_account);
    IMBRelease(_accountStore);
    [super dealloc];
}


#pragma mark - Mandatory overrides from superclass

- (IMBNode*) unpopulatedTopLevelNode: (NSError**) outError
{
//    // Running in app process or XPC service?
//    NSString *facebookAppId = FACEBOOK_APP_ID_APP_PROCESS;
//    
//    if (outError) *outError = nil;     // Ensure out-parameter is properly initialized
//    
//    // This method must return synchronously with all necessary requests to facebook being already returned.
//    // Use NSCondition and BOOL for that matter.
//    
//    NSCondition *authenticationCond = [[NSCondition alloc] init];
//    __block BOOL authenticationDone = NO;
//    
//    [authenticationCond lock];
//    
//    self.accountStore = [[ACAccountStore alloc] init];
//    
//    NSLog(@"%@", [self.accountStore accounts]);
//
//    ACAccountType *facebookAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
//    
//    NSArray *facebookPermissions = [NSArray arrayWithObjects:@"email", nil];
//    
//    NSDictionary *facebookClientAccessInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                              facebookAppId, ACFacebookAppIdKey,
//                                              //ACFacebookAudienceOnlyMe, ACFacebookAudienceKey,
//                                              facebookPermissions, ACFacebookPermissionsKey, nil];
//    
//    [self.accountStore requestAccessToAccountsWithType:facebookAccountType options:facebookClientAccessInfo completion:^(BOOL granted, NSError *error) {
//        if (granted) {
//            NSLog(@"Facebook access basically granted!!!");
//            
//            NSArray *facebookPermissions = [NSArray arrayWithObjects:
//                                            @"user_photos", @"friends_photos",
//                                            nil];
//            NSDictionary *subseqFacbookClientAccessInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                                           facebookAppId, ACFacebookAppIdKey,
//                                                           //ACFacebookAudienceOnlyMe, ACFacebookAudienceKey,
//                                                           facebookPermissions, ACFacebookPermissionsKey, nil];
//            [self.accountStore requestAccessToAccountsWithType:facebookAccountType options:subseqFacbookClientAccessInfo completion:^(BOOL granted, NSError *error) {
//                if (granted) {
//                    NSLog(@"Facebook access totally granted!!!");
//                    NSArray *accounts = [self.accountStore accountsWithAccountType:facebookAccountType];
//                    self.account = [accounts lastObject];
//                } else {
//                    NSLog(@"No total Facebook access granted :-((");
//                    *outError = error;
//                }
//                [authenticationCond lock];
//                authenticationDone = YES;
//                [authenticationCond signal];
//                [authenticationCond unlock];
//            }];
//        } else {
//            NSLog(@"No basic Facebook access granted :-((");
//            *outError = error;
//        }
//    }];
//    
//    while (!authenticationDone) {
//        [authenticationCond wait];
//    }
//    [authenticationCond unlock];
//    
//    if (outError && *outError) {
//        return nil;
//    }
//    
//    // Facebook user name will be part of Node name. Get user name from Facebook.
//    
//    NSURL *meURL = [NSURL URLWithString:@"https://graph.facebook.com/me"];
//    NSDictionary *params = @{ @"fields" : @"id,name"};
//    
//    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
//                                            requestMethod:SLRequestMethodGET
//                                                      URL:meURL
//                                               parameters:params];
//    request.account = self.account;
//    
//    NSURLResponse *urlResponse = nil;
//    NSError *error = nil;
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:[request preparedURLRequest]
//                                                 returningResponse:&urlResponse
//                                                             error:&error];
//    if (error) {
//        NSLog(@"%@ Access to me failed:%@", [[NSRunningApplication currentApplication] bundleIdentifier], error);
//        *outError = error;
//        return nil;
//    }
//    
//    NSDictionary *me = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
//    
//    // Account for expired session
//    
//    __block IMBNode *node = nil;
//    if ([self isSessionExpired:me])
//    {
//        NSCondition *condition = [[NSCondition alloc] init];
//        __block BOOL conditionDone = NO;
//        
//        [condition lock];
//        
//        [self.accountStore renewCredentialsForAccount:self.account completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
//            
//            [condition lock];
//            conditionDone = YES;
//            [condition signal];
//            [condition unlock];
//            
//            node = [self unpopulatedTopLevelNode:outError];
//        }];
//        while (!conditionDone) {
//            [condition wait];
//        }
//        [condition unlock];
//        
//        return node;
//    }
//    
//    NSLog(@"Facebook returned me: %@",me);
//    
//    NSString *myName = [me objectForKey:@"name"];
//    NSString *myID = [me objectForKey:@"id"];
    
    //------------------------------------------------------------------
    
	//	load Facebook icon...
	NSBundle* ourBundle = [NSBundle bundleForClass:[IMBNode class]];
    
    // Use method imageForResource: if available to take advantage of
    // possibly additionally available high res representations
    
    NSString *iconName = @"facebook_logo";
    NSImage *icon;
    if ([ourBundle respondsToSelector:@selector(imageForResource:)])
    {
        icon = [ourBundle imageForResource:iconName];
    } else {
        NSURL *imageURL = [ourBundle URLForImageResource:iconName];
        icon = [[[NSImage alloc] initWithContentsOfURL:imageURL] autorelease];
    }
	
    //  create an empty root node (unpopulated and without subnodes)...
	IMBNode *node = [[[IMBNode alloc] initWithParser:self topLevel:YES] autorelease];
	node.groupType = kIMBGroupTypeInternet;
	node.icon = icon;
	node.identifier = [self identifierForPath:@""];
	node.isIncludedInPopup = YES;
	node.isLeafNode = NO;
	node.mediaSource = nil;
	node.accessibility = kIMBResourceNoPermission;      // TODO/JJ: Be more elaborate here
    
    NSString *nodeName, *myName = nil;
    if (node.accessibility == kIMBResourceIsAccessible) {
        nodeName = [NSString stringWithFormat:@"Facebook (%@)", myName];
    } else {
        nodeName = @"Facebook";
    }
    node.name = nodeName;
	
	return node;
}

- (BOOL) populateNode:(IMBNode *)inParentNode error:(NSError **)outError
{
    if (outError) *outError = nil;     // Ensure out-parameter is properly initialized
    
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method,
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
	
    NSArray *connectionTypes = [NSArray arrayWithObjects:@"albums", @"friends", nil];
    
    NSArray *someSubnodes = nil;
    for (NSString *connectionType in connectionTypes)
    {
        someSubnodes   = [self nodeID:inParentNode.identifier connectedNodesByType:connectionType params:nil error:outError];
        
        if (*outError) {
            return NO;
        }
        
        NSString *ID, *name;
        IMBNode *subnode;
        for (NSDictionary *nodeDict in someSubnodes)
        {
            ID = [nodeDict objectForKey:@"id"];
            name = [nodeDict objectForKey:@"name"];
            
            // Create node for this album...
            
            subnode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
            
            subnode.isLeafNode = [connectionType isEqualToString:@"albums"];
            //        albumNode.icon = [self iconForAlbumType:albumType highlight:NO];
            //        albumNode.highlightIcon = [self iconForAlbumType:albumType highlight:YES];
            subnode.name = name;
            subnode.identifier = ID;
            
			// Keep a ref to the type of the subnode – so when later populating it we know how to deal with it
			
			subnode.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    connectionType, @"nodeType", nil];
            [subnodes addObject:subnode];
        }
    }
        
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	
    if (inParentNode.attributes && [[inParentNode.attributes objectForKey:@"nodeType"] isEqual:@"albums"])
    {
        // Get all photos from this album
        
        NSArray *photoDicts = [self nodeID:inParentNode.identifier connectedNodesByType:@"photos" params:@{ @"fields" : @"id,picture,images,source"} error:outError];
        
        IMBObject *object = nil;
        for (NSDictionary *photoDict in photoDicts)
        {
            object = [[IMBObject alloc] init];
			[objects addObject:object];
			[object release];
            
            object.parserIdentifier = [self identifier];
            
            NSArray *images = [photoDict objectForKey:@"images"];
            if ([images count] > 0) {
                object.location = [NSURL URLWithString:[[images objectAtIndex:0] objectForKey:@"source"]];
            } else {
                object.location = [NSURL URLWithString:[photoDict objectForKey:@"source"]];
            }
            object.accessibility = [self accessibilityForObject:object];
            object.imageLocation = [NSURL URLWithString:[photoDict objectForKey:@"picture"]];
            object.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
        }
    }
    
    inParentNode.objects = objects;
    
//    IMBFlickrNode* inFlickrNode = (IMBFlickrNode*) inNode;
//    
//    if (inFlickrNode.isTopLevelNode) {
//        //  add subnodes...
//        NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
//        [subnodes addObject:[IMBFlickrNode flickrNodeForRecentPhotosForRoot:inFlickrNode parser:self]];
//        [subnodes addObject:[IMBFlickrNode flickrNodeForInterestingPhotosForRoot:inFlickrNode parser:self]];
//        
//        //  add objects...
//        inFlickrNode.objects = [NSMutableArray array];
//    } else {
//        if (SBIsSandboxed()) xpc_transaction_begin ();
//        
//        //	lazy initialize the flickr context...
//        if (_flickrContext == nil) {
//            //  failing to setup the Flickr API key and shared secret is an implementation error...
//            NSAssert (self.flickrAPIKey, @"Flickr API key property not set!");
//            NSAssert (self.flickrSharedSecret, @"Flickr shared secret property not set!");
//            _flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:self.flickrAPIKey sharedSecret:self.flickrSharedSecret];
//        }
//        
//        //  we have no subnodes...
//        [inFlickrNode mutableArrayForPopulatingSubnodes];
//        
//        //  run flickr request...
//        IMBFlickrSession* session = [[IMBFlickrSession alloc] initWithFlickrContext:_flickrContext];
//        [session executeFlickRequestForNode:inFlickrNode];
//        
//        //  evaluate the response...
//        if (!session.error) {
//#ifdef VERBOSE
//            NSLog (@"RESPONSE: %@", session.response);
//#endif
//            NSArray* objects = [session extractPhotosFromFlickrResponseForParserMessenger:(IMBFlickrParserMessenger*)inFlickrNode.parserMessenger];
//            inFlickrNode.objects = objects;
//        } else {
//            if (outError) *outError = [[session.error copy] autorelease];
//        }
//        [session release];
//        
//        if (SBIsSandboxed()) xpc_transaction_end ();
//    }
//    
    return YES;
}


//
//
- (id)thumbnailForObject:(IMBObject *)inObject error:(NSError **)outError
{
    if (inObject.imageLocation) {
		NSURL* url = (NSURL*)inObject.imageLocation;
        NSData* data = [NSData dataWithContentsOfURL:url];
        return data;
    }
    return nil;
}

//
//
- (NSDictionary *)metadataForObject:(IMBObject *)inObject error:(NSError **)outError
{
	if (outError) *outError = nil;
    
	return inObject.preliminaryMetadata;
}

//
//
- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
	NSURL* URL = inObject.URL;
	NSData* bookmark = nil;
	
    bookmark = [URL
                bookmarkDataWithOptions:0
                includingResourceValuesForKeys:nil
                relativeToURL:nil
                error:&error];
    
	if (outError) *outError = error;
	return bookmark;
}


#pragma mark - Utility Methods

- (NSArray *) nodeID:(NSString *)nodeID
connectedNodesByType:(NSString *)nodeType
              params:(NSDictionary *)params
               error:(NSError **)outError
{
    if (!params) params = @{ @"fields" : @"id,name"};
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/%@", nodeID, nodeType]];
    
    NSLog(@"Graph URL: %@", URL);
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
                                            requestMethod:SLRequestMethodGET
                                                      URL:URL
                                               parameters:params];
    request.account = self.account;
    
    NSURLResponse *urlResponse = nil;
    NSError *error = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:[request preparedURLRequest]
                                                 returningResponse:&urlResponse
                                                             error:&error];
    if (error) {
        NSLog(@"%@ Access to %@ failed:%@", [[NSRunningApplication currentApplication] bundleIdentifier], nodeType, error);
        *outError = error;
        return nil;
    }
    
    NSDictionary *responseDict = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    NSLog(@"Facebook returned %@: %@", nodeType, responseDict);
    
    NSArray *nodes = [responseDict objectForKey:@"data"];
    
    return nodes;
}


// Get albums for facebook node (node is supposedly me or any of my friends)
//
- (NSArray *)albumsForNodeWithID:(NSString *)nodeID error:(NSError **)outError
{
    return [self nodeID:nodeID connectedNodesByType:@"albums" params:nil error:outError];
}


// Get friends for facebook node (node is supposedly me)
//
- (NSArray *)friendsForNodeWithID:(NSString *)nodeID error:(NSError **)outError
{
    return [self nodeID:nodeID connectedNodesByType:@"friends" params:nil error:outError];
}


- (BOOL) isSessionExpired:(NSDictionary *)responseDict
{
    NSDictionary *error = [responseDict objectForKey:@"error"];
    if (error) {
        return [((NSNumber *)[error objectForKey:@"code"]) integerValue] == 190;
    }
    return NO;
}

@end
