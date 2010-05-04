//
//  BONDIGeolocation.h
//  PhoneGapLib
//
//  Created by sph on 06.04.10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Location.h"

extern NSInteger const PERMISSION_DENIED;
extern NSInteger const POSITION_UNAVAILABLE;
extern NSInteger const TIMEOUT;

@interface BONDIGeolocation : PhoneGapCommand <CLLocationManagerDelegate>  {
	CLLocationManager *locationManager;
    BOOL              __locationStarted;
}

@property (nonatomic, retain) CLLocationManager *locationManager;

@end
