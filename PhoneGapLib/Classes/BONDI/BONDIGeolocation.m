//
//  BONDIGeolocation.m
//  PhoneGapLib
//
//  Created by sph on 06.04.10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "BONDIGeolocation.h"

NSInteger const PERMISSION_DENIED = 1;
NSInteger const POSITION_UNAVAILABLE = 2;
NSInteger const TIMEOUT = 3;

@implementation BONDIGeolocation

@synthesize locationManager;

-(PhoneGapCommand*) initWithWebView:(UIWebView*)theWebView
{
    self = (BONDIGeolocation*)[super initWithWebView:(UIWebView*)theWebView];
    if (self) {
        self.locationManager = [[[CLLocationManager alloc] init] autorelease];
        self.locationManager.delegate = self; // Tells the location manager to send updates to this object
    }
    return self;
}

- (void)createCallbackDelayed:(NSTimer*)timer {
	NSLog(@"BONDIGeolocation.createCallbackDelayed");
	NSArray *callbackInfo = [timer userInfo];
	if (callbackInfo) {
		NSString *callback = nil, *function = nil, *string = nil;
		callback = [callbackInfo objectAtIndex:0];
		function = [callbackInfo objectAtIndex:1];
		string = [callbackInfo objectAtIndex:2];
		
		NSString* jsString;
		if (![function isEqualToString:@""])
			jsString = [[NSString alloc] initWithFormat:@"%@(%@);", callback, function];
		else if (string)
			jsString = [[NSString alloc] initWithFormat:@"%@(\"%@\");", callback, string];
		NSLog(@"%@",jsString);
		[webView stringByEvaluatingJavaScriptFromString:jsString];
		[jsString release];
	}
}


- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    long long epoch = [newLocation.timestamp timeIntervalSince1970] * 1000.0; // seconds -> milliseconds
	NSString* coords =  [NSString stringWithFormat:@"coords: { latitude: %f, longitude: %f, altitude: %f, heading: null, speed: null, accuracy: %f, altitudeAccuracy: null }",
						 newLocation.coordinate.latitude,
						 newLocation.coordinate.longitude,
						 newLocation.altitude,
						 newLocation.horizontalAccuracy
						 ];
	
	NSArray *callbackInfo = [NSArray arrayWithObjects:@"bondi.geolocation.setLocation",[NSString stringWithFormat:@"{ timestamp: %lld, %@ }",epoch,coords],@"", nil];		
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
	
}

- (NSString *)start:(NSMutableArray*)arguments
		   withDict:(NSMutableDictionary*)options
{
	if ([self.locationManager locationServicesEnabled] != YES)
	{   
		NSArray *callbackInfo = [NSArray arrayWithObjects:@"bondi.geolocation.setError", [NSString stringWithFormat:@"{ code: %i, message: '%@' }",POSITION_UNAVAILABLE,@"Location Services Not Enabled"], @"", nil];		
		[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}
    
    // Tell the location manager to start notifying us of location updates
    [self.locationManager startUpdatingLocation];
    __locationStarted = YES;
	
	
	if ([options objectForKey:@"desiredAccuracy"]) { //TODO: enablehighaccuracy
        int desiredAccuracy_num = [(NSString *)[options objectForKey:@"desiredAccuracy"] integerValue];
        CLLocationAccuracy desiredAccuracy = kCLLocationAccuracyBest;
        if (desiredAccuracy_num < 10)
            desiredAccuracy = kCLLocationAccuracyBest;
        else if (desiredAccuracy_num < 100)
            desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        else if (desiredAccuracy_num < 1000)
            desiredAccuracy = kCLLocationAccuracyHundredMeters;
        else if (desiredAccuracy_num < 3000)
            desiredAccuracy = kCLLocationAccuracyKilometer;
        else
            desiredAccuracy = kCLLocationAccuracyThreeKilometers;
        
        self.locationManager.desiredAccuracy = desiredAccuracy;
    }
	return nil;
}

- (NSString *)stop:(NSMutableArray*)arguments
		  withDict:(NSMutableDictionary*)options
{
    if (__locationStarted == NO)
        return nil;
    if ([self.locationManager locationServicesEnabled] != YES)
        return nil;
    
    [self.locationManager stopUpdatingLocation];
    __locationStarted = NO;
	return nil;
}

@end
