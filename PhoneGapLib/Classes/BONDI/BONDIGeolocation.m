//
//  BONDIGeolocation.m
//  PhoneGapLib
//
//  Created by sph on 06.04.10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "BONDIGeolocation.h"


@implementation BONDIGeolocation


- (void)createCallbackDelayed:(NSTimer*)timer {
	NSLog(@"BONDIGeolocation.createCallbackDelayed");
	NSArray *callbackInfo = [timer userInfo];
	if (callbackInfo) {
		NSString *callback = nil, *string = nil;
		callback = [callbackInfo objectAtIndex:0];
		string = [callbackInfo objectAtIndex:1];
		
		NSString* jsString = [[NSString alloc] initWithFormat:@"%@(%@);", callback, string];
		NSLog(@"%@",jsString);
		[webView stringByEvaluatingJavaScriptFromString:jsString];
		[jsString release];
	}
	timer = nil;
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    int epoch = [newLocation.timestamp timeIntervalSince1970];

	NSString* coords =  [NSString stringWithFormat:@"coords: { latitude: %f, longitude: %f, altitude: %f, heading: null, speed: null, accuracy: %f, altitudeAccuracy: null }",
						 newLocation.coordinate.latitude,
						 newLocation.coordinate.longitude,
						 newLocation.altitude,
						 newLocation.horizontalAccuracy
						 ];
	
	NSArray *callbackInfo = [NSArray arrayWithObjects:@"navigator.geolocation.setLocation",[NSString stringWithFormat:@"{ timestamp: %d, %@ }",epoch,coords], nil];		
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
	
}

@end
