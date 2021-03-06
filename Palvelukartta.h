//
//  Palvelukartta.h
//
//  Created by Rasmus Sten on 2011-10-29.
//  Copyright (c) 2011-2012 Rasmus Sten. All rights reserved.
//

#define DLOG(...) if (self.debug) NSLog(__VA_ARGS__);

// "http://www.hel.fi/palvelukarttaws/rest/v1/service/8920"
// "http://www.hel.fi/palvelukarttaws/rest/v1/unit/%@"

#define PK_V2_SERVICE_PUBLIC_TOILETS 25402
#define PK_V2_BASE_URL "http://www.hel.fi/palvelukarttaws/rest/v2/"

@interface Palvelukartta : NSObject
{
    NSURLConnection *listConnection;
    NSURLConnection *servicesListConnection;
    NSMutableDictionary *unitForConnection;
    NSMutableDictionary *dataForConnection;
    NSMutableDictionary *urlForConnection;
    NSMutableDictionary *attemptsForConnection;
    NSMutableDictionary *callbackForConnection;
    NSMutableSet *remainingConnections;
}

- (void) loadAllServices:(void (^) (NSArray*, NSError*)) block;
- (void) loadServices:(int) ofType withBlock:(void (^) (NSArray*, NSError*)) block;
- (void) loadUnit:(NSNumber*) unitId withBlock:(void (^) (NSDictionary*, NSNumber*, NSError*)) block;
- (void) cancelAll;
- (unsigned long) connectionsPending;
- (NSURLConnection*) newConnection:(NSURL*) url;
+ (NSString*) localizedStringForProperty:(NSString*) property inUnit:(NSDictionary*) unit;
+ (NSArray*) sortedServices:(NSArray*) list;
+ (void) populateServiceChildren:(NSArray*) list withIdMap:(NSDictionary*) services;

@property (nonatomic) BOOL debug;
@property (nonatomic, retain) NSObject *delegate;
@property (nonatomic, retain) NSString *pkRestURL;

@end
