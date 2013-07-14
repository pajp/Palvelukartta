//
//  PalvelukarttaDelegate.h
//
//  Created by Rasmus Sten on 2011-10-29.
//  Copyright (c) 2011-2012 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PalvelukarttaDelegate <NSObject>
- (void) serviceListLoaded:(NSArray*) list;
- (void) unitLoaded:(NSDictionary*) unit;
- (void) networkError:(int) unitId;
@end
