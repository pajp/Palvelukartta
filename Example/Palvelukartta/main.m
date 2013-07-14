//
//  main.m
//  Palvelukartta
//
//  Created by Rasmus Sten on 2012-03-29.
//  Copyright (c) 2012 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Palvelukartta.h"


@interface SimpleDelegate: NSObject <PalvelukarttaDelegate>
@property (nonatomic, retain) Palvelukartta *pk;
@end

@implementation SimpleDelegate
@synthesize pk;

- (id) init {
    self = [super init];
    return self;
}

void p(NSString* s) {
    printf("%s", [s UTF8String]);
}

BOOL quiet = NO;

#define PRINT(...) if (!quiet) p([NSString stringWithFormat:__VA_ARGS__])

void printService(NSDictionary* srv, NSMutableSet* seen, int depth) {
    NSString* idStr = [NSString stringWithFormat:@"%@", [srv valueForKey:@"id"]];
    if ([seen containsObject:idStr]) {
        return;
    }
    [seen addObject:idStr];
    for (int i=0; i < depth; i++) {
        if (i == 0) printf("  +-");
        else printf("--");
    }
    if (depth > 0) printf(">  ");
    else printf("  ");
    PRINT(@"%@ (#%@)\n", [Palvelukartta localizedStringForProperty:@"name" inUnit:srv], idStr);
    NSArray* children = (NSArray*) [srv objectForKey:@"children"];

    [children enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        printService(obj, seen, depth+1);
    }];
}

- (void) networkError:(int) unitId {
    NSLog(@"Network error loading unit %d, aborting", unitId);
    exit(1);
}

- (void) serviceListLoaded:(NSArray*) list {
    PRINT(@"Received service list, requesting units...\n");
    [list enumerateObjectsUsingBlock:^(id object, NSUInteger isx, BOOL *stop) {
        [pk loadUnit:object];
    }];
}

- (void) unitLoaded:(NSDictionary*) unit {
    PRINT(@"------------------------------\n");
    if (pk.debug) {
        [unit enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            PRINT(@"%@: %@\n", key, obj);
        }];
    }
    PRINT(@"Name: %@\n", [Palvelukartta localizedStringForProperty:@"name" inUnit:unit]);
    NSString* address = [Palvelukartta localizedStringForProperty:@"street_address" inUnit:unit];
    if (address != nil) {
        PRINT(@"Address: %@\n", address);
    }
    NSArray* connections = (NSArray *) [unit objectForKey:@"connections"];
    NSArray* localizedKeys = [NSArray arrayWithObjects:@"name", @"www", nil];
    [connections enumerateObjectsUsingBlock:^(id connection, NSUInteger idx0, BOOL *stop) {
        [localizedKeys enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
            NSString *text = [Palvelukartta localizedStringForProperty:key inUnit:connection];
            if (text == nil) return;
            if (idx == 0) PRINT(@"\n\t");
            if (idx == 1) PRINT(@": ");
            PRINT(@"%@", text);
        }];
    }];
    PRINT(@"\n");
}
@end

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        Palvelukartta *palvelukartta = [[Palvelukartta alloc] init];
        SimpleDelegate* del = [[SimpleDelegate alloc] init];
        del.pk = palvelukartta;
        palvelukartta.delegate = del;
        NSMutableArray* arguments = [NSMutableArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
        [arguments removeObjectAtIndex:0];
        if (arguments.count == 1) {
            if ([[arguments objectAtIndex:0] isEqual:@"--quiet"]) {
                quiet = YES;
                [arguments removeObjectAtIndex:0];
            }
        }
        if (arguments.count == 0) {
            PRINT(@"Requesting information about public restrooms...\n");
            [palvelukartta loadServices:PK_SERVICE_PUBLIC_TOILETS];
        } else {
            if ([[arguments objectAtIndex:0] isEqual:@"--all-services"]) {
                PRINT(@"Requesting all services...\n");
                [palvelukartta loadAllServices:^(NSArray* list, NSError* error)  {
                    if (error != nil) {
                        PRINT(@"%@\n", [error localizedDescription]);
                        exit(1);
                    }
                    NSMutableDictionary *services = [[NSMutableDictionary alloc] init];
                    [Palvelukartta populateServiceChildren:list withIdMap:services];
                    NSMutableSet* displayed = [[NSMutableSet alloc] initWithCapacity:list.count];
                    [[Palvelukartta sortedServices:list] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        printService(obj, displayed, 0);
                    }];
                }];
            } else if ([[arguments objectAtIndex:0] isEqual:@"--service"] && arguments.count == 2) {
                int serviceId = [[arguments objectAtIndex:1] intValue];
                PRINT(@"Requesting information about service %d...\n", serviceId);
                [palvelukartta loadServices:serviceId];
            } else if ([[arguments objectAtIndex:0] isEqual:@"--unit"] && arguments.count == 2) {
                PRINT(@"Requesting information about unit %d...\n", [[arguments objectAtIndex:1] intValue]);
                [palvelukartta loadUnit:[NSNumber numberWithInt:[[arguments objectAtIndex:1] intValue]]];
            } else {
                PRINT(@"Illegal arguments: %@ .\n", arguments);
                exit(1);
            }
        }
        while ([palvelukartta connectionsPending] > 0) {
            if (palvelukartta.debug) PRINT(@"*** Running runloop (%ld connections pending) ***\n", [palvelukartta connectionsPending]);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        }
        PRINT(@"------------------------------\nAll done!\n");
        
    }
    return 0;
}

