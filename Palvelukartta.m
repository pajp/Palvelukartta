//
//  Palvelukartta.m
//
//  Created by Rasmus Sten on 2011-10-29.
//  Copyright (c) 2011 Rasmus Sten. All rights reserved.
//

#import "Palvelukartta.h"

@implementation Palvelukartta

@synthesize delegate;

NSString* ctostr(NSURLConnection* c);

- (id) init {
    self = [super init];
    if (self) {
        unitForConnection = [[NSMutableDictionary alloc] init];
        dataForConnection = [[NSMutableDictionary alloc] init];
        attemptsForConnection = [[NSMutableDictionary alloc] init];
        urlForConnection = [[NSMutableDictionary alloc] init];
        remainingConnections = [[NSMutableSet alloc] init]; 
        pkRestURL = @PK_BASE_URL;
        NSLog(@"PK object %@ init", self);
    }
    return self;
}

- (void) dealloc {
    NSLog(@"PK object %@ dealloc", self);
    [unitForConnection release];
    [dataForConnection release];
    [attemptsForConnection release];
    [urlForConnection release];
    [servicesListConnection release];
    [remainingConnections release];
    [listConnection release];
    [pkRestURL release];
    [delegate release];
    
    [super dealloc];
}

- (void) cancelAll {
    NSURLConnection *connection;
    for(connection in remainingConnections){
        NSLog(@"Cancelling URL: %@, connection %@", [urlForConnection objectForKey:ctostr(connection)], connection);
        [connection cancel];
    }    
    
}

- (void) loadUnit:(NSNumber*) unitIdObj {
    int unitId = [unitIdObj intValue];
    NSURL *uniturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@unit/%d", pkRestURL, unitId]];
    NSURLConnection *c = [self doConnection:uniturl];
    [unitForConnection setValue:[NSNumber numberWithInt:unitId] forKey:ctostr(c)];
}

- (NSURLConnection*) doConnection:(NSURL*) url {
    NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60.0];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    [urlForConnection setValue:url forKey:ctostr(connection)];
    [remainingConnections addObject:connection];    
    NSLog(@"PK %@ requesting URL %@ (connection: %@)", self, url, connection);
    return connection;
}

- (void) loadAllServices {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@service/", pkRestURL]];
    servicesListConnection = [self doConnection:url];
}
                              
- (void) loadServices:(int) ofType {
    NSURL *unitlisturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@service/%d", pkRestURL, ofType]];
    NSLog(@"Requesting service URL %@", unitlisturl);

    listConnection=[self doConnection:unitlisturl];        
}

- (void)connectRetry:(NSTimer*)theTimer
{
    NSURLConnection *connection = theTimer.userInfo;
    NSLog(@"retrying connection %@", connection);
    NSNumber *unitId = [unitForConnection valueForKey:ctostr(connection)]; 
    NSURLConnection *newConnection = [self doConnection:[urlForConnection valueForKey:ctostr(connection)]];
    [unitForConnection setValue:unitId forKey:ctostr(newConnection)];
    [unitForConnection removeObjectForKey:ctostr(connection)];
    [urlForConnection removeObjectForKey:ctostr(connection)];
    [dataForConnection removeObjectForKey:ctostr(connection)];
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
- (void) failConnection:(NSURLConnection *)connection
{
    NSNumber *unit = [unitForConnection valueForKey:ctostr(connection)];

    if (unit == nil) {
        if (delegate != nil) [delegate networkError:-1];
    } else {
        if (delegate != nil) [delegate networkError:[unit intValue]];
    }
    
    [connection cancel];
    [urlForConnection setValue:nil forKey:ctostr(connection)];
    [attemptsForConnection setValue:nil forKey:ctostr(connection)];
}


- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSNumber *attempts = [attemptsForConnection valueForKey:ctostr(connection)];
    NSURL *url = [urlForConnection valueForKey:ctostr(connection)];
    [remainingConnections removeObject:connection];
    NSLog(@"connection fail: connection: %@, attempts: %@, url: %@, error: %@", connection, attempts, url, error);
    if ([attempts intValue] > 3) {
        NSLog(@"giving up on url %@, %@", url, connection);
        [self failConnection:connection];
    } else {
        NSLog(@"connection failed with error %@, attempts=%d", error, [attempts intValue]);
        [NSTimer scheduledTimerWithTimeInterval:[attempts intValue]*2.0 target:self selector:@selector(connectRetry:) userInfo:connection repeats:NO];
    }

    
//    retryCount++;
//    NSLog(@"connection failed with error %@, retryCount=%d", error, retryCount);
//    if (retryCount < 5) {
//        [NSTimer scheduledTimerWithTimeInterval:retryCount*2.0
//                                         target:self
//                                       selector:@selector(connectRetry:)
//                                       userInfo:nil
//                                        repeats:NO];    
//    }
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

- (int) connectionsPending {
    return [remainingConnections count];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSData *data = [dataForConnection objectForKey:ctostr(connection)];
    //NSLog(@"connectionDidFinishLoading:%@ (%@)", connection, ctostr(connection));
    if (!data) {
        [NSException raise:@"Null data buffer" format:@"connectionDidFinishLoading but no data object for %@ exists", ctostr(connection)];
    }
    if ([data length] == 0) {
        NSLog(@"connectionDidFinishLoading but data buffer is empty for %@ (URL: %@)", ctostr(connection),
              [urlForConnection valueForKey:ctostr(connection)]);
        [self connection:connection didFailWithError:[NSError errorWithDomain:@"nu.dll.sv.empty-reply-error" code:1 userInfo:nil]];
        [data release];
        [parser release];
        [dataForConnection removeObjectForKey:ctostr(connection)];
        [remainingConnections removeObject:connection];
        return;
    }
    if (connection == listConnection) {
        NSMutableData *datacopy = [data mutableCopy];
        NSDictionary *response = [parser objectWithData:datacopy];
        NSArray *units = [response objectForKey:@"unit_ids"];
        NSLog(@"received units: %@, delegate: %@", units, delegate);
        if (delegate != nil) [delegate serviceListLoaded:units];
        [connection release];
        [datacopy release];
        listConnection = nil;
    } else if (connection == servicesListConnection) {
        NSArray *_services = [parser objectWithData:data];
        for (int i=0; i < [_services count]; i++) {
            NSLog(@"service %@: %@", [[_services objectAtIndex:i] objectForKey:@"id"], [[_services objectAtIndex:i] objectForKey:@"name_sv"]);
        }
        if (delegate != nil) [delegate servicesLoaded:_services];
        servicesListConnection = nil;
    } else {
        NSNumber *unitId = [unitForConnection objectForKey:[NSString stringWithFormat:@"%p", connection]];
        if (unitId) {
            NSDictionary *response = [parser objectWithData:data];
            if (delegate != nil) [delegate unitLoaded:response];
            //NSLog(@"Unit loaded, remaining: %@", remainingObjects);
        } else {
            [NSException raise:@"unexpected" format:@"Connection not recognized: %@", connection];            
        }
    }
    [data release];
    [parser release];
    [dataForConnection setValue:nil forKey:ctostr(connection)];
    [remainingConnections removeObject:connection];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *hr = (NSHTTPURLResponse*) response;
    if (hr.statusCode != 200) {
        NSLog(@"Error: HTTP response code %d", hr.statusCode);
        [self failConnection:connection];
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


@end
