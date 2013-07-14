//
//  Palvelukartta.m
//
//  Created by Rasmus Sten on 2011-10-29.
//  Copyright (c) 2011 Rasmus Sten. All rights reserved.
//

#include <stdlib.h>
#import "Palvelukartta.h"

@implementation Palvelukartta

@synthesize delegate;
@synthesize debug;
@synthesize pkRestURL;

NSString* ctostr(NSURLConnection* c);

- (id) init {
    self = [super init];
    if (self) {
        unitForConnection = [[NSMutableDictionary alloc] init];
        dataForConnection = [[NSMutableDictionary alloc] init];
        attemptsForConnection = [[NSMutableDictionary alloc] init];
        urlForConnection = [[NSMutableDictionary alloc] init];
        remainingConnections = [[NSMutableSet alloc] init];
        callbackForConnection = [[NSMutableDictionary alloc] init];
        self.pkRestURL = @PK_BASE_URL;
        if (getenv("PK_BASE_URL") != NULL) {
            self.pkRestURL = [NSString stringWithCString:getenv("PK_BASE_URL") encoding:NSUTF8StringEncoding];
        }
        if (getenv("PK_DEBUG") != NULL) {
            self.debug = YES;
        }
        DLOG(@"PK object %@ init", self);
    }
    return self;
}

- (void) dealloc {
    DLOG(@"PK object %@ dealloc", self);
}

- (void) cancelAll {
    NSURLConnection *connection;
    for(connection in remainingConnections){
        DLOG(@"Cancelling URL: %@, connection %@", [urlForConnection objectForKey:ctostr(connection)], connection);
        [connection cancel];
    }    
    
}

- (void) loadUnit:(NSNumber*) unitIdObj {
    int unitId = [unitIdObj intValue];
    NSURL *uniturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@unit/%d", self.pkRestURL, unitId]];
    NSURLConnection *c = [self newConnection:uniturl];
    [unitForConnection setValue:[NSNumber numberWithInt:unitId] forKey:ctostr(c)];
}

- (NSURLConnection*) newConnection:(NSURL*) url {
    NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    [urlForConnection setValue:url forKey:ctostr(connection)];
    [remainingConnections addObject:connection];    
    DLOG(@"PK %@ requesting URL %@ (connection: %@)", self, url, connection);
    return connection;
}

- (void) loadAllServices:(void (^) (NSArray*, NSError*)) block
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@service/", self.pkRestURL]];
    servicesListConnection = [self newConnection:url];
    callbackForConnection[ctostr(servicesListConnection)] = block;
}
                              
- (void) loadServices:(int) ofType withBlock:(void (^) (NSArray*, NSError*)) block {
    NSURL *unitlisturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@service/%d", self.pkRestURL, ofType]];
    DLOG(@"Requesting service URL %@", unitlisturl);

    listConnection=[self newConnection:unitlisturl];
    callbackForConnection[ctostr(listConnection)] = block;
}

- (void)connectRetry:(NSTimer*)theTimer
{
    NSURLConnection *connection = theTimer.userInfo;
    DLOG(@"retrying connection %@", connection);
    NSNumber *unitId = [unitForConnection valueForKey:ctostr(connection)];
    [remainingConnections removeObject:connection];
    NSURLConnection *newConnection = [self newConnection:[urlForConnection valueForKey:ctostr(connection)]];
    [unitForConnection setValue:unitId forKey:ctostr(newConnection)];
    [unitForConnection removeObjectForKey:ctostr(connection)];
    [urlForConnection removeObjectForKey:ctostr(connection)];
    [dataForConnection removeObjectForKey:ctostr(connection)];

    callbackForConnection[ctostr(newConnection)] = callbackForConnection[ctostr(connection)];
    [callbackForConnection removeObjectForKey:ctostr(connection)];

    NSNumber *count = [attemptsForConnection valueForKey:ctostr(connection)];
    if (count == nil) {
        count = [NSNumber numberWithInt:2];
    } else {
        count = [NSNumber numberWithInt:count.intValue + 1];
    }
    [attemptsForConnection removeObjectForKey:ctostr(connection)];
    [attemptsForConnection setValue:count forKey:ctostr(newConnection)];
    
}

// clean up a failed connection
- (void) failConnection:(NSURLConnection *)connection withError:(NSError *) error;
{
    NSNumber *unit = [unitForConnection valueForKey:ctostr(connection)];

    [connection cancel];
    [urlForConnection setValue:nil forKey:ctostr(connection)];
    [attemptsForConnection setValue:nil forKey:ctostr(connection)];
    [remainingConnections removeObject:connection];

    void (^callback)(NSArray*, NSError*) = callbackForConnection[ctostr(connection)];
    if (callback != nil) {
        DLOG(@"calling callback %@", callback);
        callback(nil, error);
        [callbackForConnection removeObjectForKey:ctostr(connection)];
    }

    if (unit == nil) {
        if (delegate != nil) [delegate networkError:-1];
    } else {
        if (delegate != nil) [delegate networkError:[unit intValue]];
    }
}


- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSNumber *attempts = [attemptsForConnection valueForKey:ctostr(connection)];
    NSURL *url = [urlForConnection valueForKey:ctostr(connection)];
    DLOG(@"connection fail: connection: %@, attempts: %@, url: %@, error: %@", connection, attempts, url, error);
    if ([attempts intValue] > 3) {
        DLOG(@"giving up on url %@, %@", url, connection);
        
        [self failConnection:connection withError:error];
    } else {
        DLOG(@"connection failed with error %@, attempts=%d", error, [attempts intValue]);
        [NSTimer scheduledTimerWithTimeInterval:[attempts intValue]*2.0 target:self selector:@selector(connectRetry:) userInfo:connection repeats:NO];
    }
}


NSString* ctostr(NSURLConnection* c) {
    return [NSString stringWithFormat:@"%p", c];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newdata
{
    NSMutableData *data = [dataForConnection objectForKey:ctostr(connection)];
    //NSLog(@"Appended %d bytes to data buffer for %@", [newdata length], connection);
    [data appendData:newdata];
}

- (unsigned long) connectionsPending {
    return [remainingConnections count];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSError *error = nil;
    NSData *data = [dataForConnection objectForKey:ctostr(connection)];
    //NSLog(@"connectionDidFinishLoading:%@ (%@)", connection, ctostr(connection));
    if (!data) {
        [NSException raise:@"Null data buffer" format:@"connectionDidFinishLoading but no data object for %@ exists", ctostr(connection)];
    }
    if ([data length] == 0) {
        DLOG(@"connectionDidFinishLoading but data buffer is empty for %@ (URL: %@)", ctostr(connection),
              [urlForConnection valueForKey:ctostr(connection)]);
        [self connection:connection didFailWithError:[NSError errorWithDomain:@"nu.dll.sv.empty-reply-error" code:1 userInfo:nil]];

        [dataForConnection removeObjectForKey:ctostr(connection)];
        [remainingConnections removeObject:connection];
        return;
    }
    NSObject *_response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!_response) {
        NSLog(@"JSON deserialization error: %@", error);
    }
    if (connection == listConnection) {
        NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*) _response];
        NSArray *units = [response objectForKey:@"unit_ids"];
        void (^callback)(NSArray*, NSError*) = callbackForConnection[ctostr(connection)];
        DLOG(@"received units: %@, callback: %@", units, callback);
        callback(units, nil);
        [callbackForConnection removeObjectForKey:ctostr(connection)];
        listConnection = nil;
    } else if (connection == servicesListConnection) {
        NSMutableArray* _services = [NSMutableArray arrayWithArray:(NSArray*) _response];
        for (int i=0; i < [_services count]; i++) {
            _services[i] = [NSMutableDictionary dictionaryWithDictionary:_services[i]];
            DLOG(@"service %@: %@", [[_services objectAtIndex:i] objectForKey:@"id"], [[_services objectAtIndex:i] objectForKey:@"name_sv"]);
        }
        void (^callback)(NSArray*, NSError*) = callbackForConnection[ctostr(connection)];
        [callbackForConnection removeObjectForKey:ctostr(connection)];
        callback(_services, nil);
        servicesListConnection = nil;
    } else {
        NSNumber *unitId = [unitForConnection objectForKey:[NSString stringWithFormat:@"%p", connection]];
        if (unitId) {
            NSMutableDictionary *response =  [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*) _response];
            if (delegate != nil) [delegate unitLoaded:response];
            //NSLog(@"Unit loaded, remaining: %@", remainingObjects);
        } else {
            [NSException raise:@"unexpected" format:@"Connection not recognized: %@", connection];            
        }
    }

    [dataForConnection setValue:nil forKey:ctostr(connection)];
    [remainingConnections removeObject:connection];
    [callbackForConnection removeObjectForKey:ctostr(connection)];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *hr = (NSHTTPURLResponse*) response;
    if (hr.statusCode != 200) {
        DLOG(@"Error: HTTP response code %ld", (long)hr.statusCode);
        [self failConnection:connection withError:[NSError errorWithDomain:@"Palvelukartta error" code:hr.statusCode userInfo:nil]];
    }
    //NSNumber *u = [unitForConnection valueForKey:ctostr(connection)];
    //NSLog(@"connection %@ (unit: %d) response: %d, headers: %@", ctostr(connection), u != nil ? [u intValue] : -1, hr.statusCode, [hr allHeaderFields]);

    NSMutableData *data = [dataForConnection objectForKey:ctostr(connection)];
    if (data) {
        [data setLength:0];
    } else {
        data = [[NSMutableData alloc] init];
        [dataForConnection setValue:data forKey:ctostr(connection)];
        //NSLog(@"created new data buffer for connection %@", ctostr(connection));
        
    }
}

+ (NSString*) localizedStringForProperty:(NSString*) property inUnit:(NSDictionary*) unit {
    NSString* language = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    NSString* str = [unit objectForKey:[NSString stringWithFormat:@"%@_%@", property, language]];
    if (str == nil) {
        str = [unit objectForKey:[NSString stringWithFormat:@"%@_fi", property]];
    }
    return str;
}

+ (NSArray*) sortedServices:(NSArray*) list {
    return [list sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[Palvelukartta localizedStringForProperty:@"name" inUnit:obj1] localizedCaseInsensitiveCompare:
                [Palvelukartta localizedStringForProperty:@"name" inUnit:obj2]];
    }];
}

+ (void) populateServiceChildren:(NSArray*) list withIdMap:(NSDictionary*) services {
    // first populate a dictionary mapping service IDs to
    // the service dict objects, by enumerating the list
    [list enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //NSLog(@"storing service id %@: %@", [obj valueForKey:@"id"], obj);
        [services setValue:obj forKey:[NSString stringWithFormat:@"%@", [((NSDictionary*) obj) valueForKey:@"id"]]];
    }];
    // then enumerate the list again, and for each service, lookup the
    // corresponding dict from the mapping generated above, and add that
    // dict as a value in the first service dict
    [list enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* srv = (NSDictionary*) obj;
        NSMutableArray* children = [srv valueForKey:@"children"];
        if (children == nil) {
            children = [[NSMutableArray alloc] init];
            [srv setValue:children forKey:@"children"];
        }
        NSArray* childIds = (NSArray*) [srv valueForKey:@"child_ids"];
        if (childIds != nil) {
            [childIds enumerateObjectsUsingBlock:^(id childid, NSUInteger idx, BOOL *stop) {
                NSDictionary* child = [services valueForKey:[NSString stringWithFormat:@"%@", childid]];
                if (child != nil) {
                    [children addObject:child];
                } else {
                    NSLog(@"no dict found for id %@", childid);
                }
            }];
        }
    }];
}


@end
