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

#define PRINT(...) p([NSString stringWithFormat:__VA_ARGS__])

- (void) servicesLoaded:(NSArray*) list {
    NSLog(@"servicesLoaded: %@", list);
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
    PRINT(@"Name: %@\n", [Palvelukartta localizedStringForProperty:@"name" inUnit:unit]);
    PRINT(@"Address: %@\n", [Palvelukartta localizedStringForProperty:@"street_address" inUnit:unit]);
}
@end

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        Palvelukartta *palvelukartta = [[Palvelukartta alloc] init];        
        SimpleDelegate* del = [[SimpleDelegate alloc] init];
        del.pk = palvelukartta;
        palvelukartta.delegate = del;
        [palvelukartta loadServices:PK_SERVICE_PUBLIC_TOILETS];
        while ([palvelukartta connectionsPending] > 0) {
            PRINT(@"*** Running runloop (%d connections pending) ***\n", [palvelukartta connectionsPending]);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        }
        [palvelukartta release];
        [del release];
        PRINT(@"------------------------------\nAll done!\n");
        
    }
    return 0;
}

