//
//  Palvelukartta.h
//
//  Created by Rasmus Sten on 2011-10-29.
//  Copyright (c) 2011-2012 Rasmus Sten. All rights reserved.
//

#import "SBJson.h"
#import "PalvelukarttaDelegate.h"

#define PK_V2_SERVICE_PUBLIC_TOILETS 25402
#define PK_V2_BASE_URL "http://www.hel.fi/palvelukarttaws/rest/v2/"

@interface Palvelukartta : NSObject
{
    NSObject <PalvelukarttaDelegate> *delegate;
    NSString *pkRestURL;
    NSURLConnection *listConnection;
    NSURLConnection *servicesListConnection;
    NSMutableDictionary *unitForConnection;
    NSMutableDictionary *dataForConnection;
    NSMutableDictionary *urlForConnection;
    NSMutableDictionary *attemptsForConnection;
    NSMutableSet *remainingConnections;
}

- (void) loadAllServices;
- (void) loadServices:(int) ofType;
- (void) loadUnit:(NSNumber*) unitId;
- (void) cancelAll;
- (NSURLConnection*) doConnection:(NSURL*) url;


@property (nonatomic, retain) NSObject *delegate;

@end
