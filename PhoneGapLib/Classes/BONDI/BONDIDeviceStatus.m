//
//  BONDIDeviceStatus.m
//  PhoneGapLib
//
//  Created by sph on 20.01.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BONDIDeviceStatus.h"
#import "BONDIErrorCodes.h"
#import "JSON.h"

@implementation BONDIDeviceStatus
@synthesize listeners, oldValues;

+ (id) sharedBONDIDeviceStatus
{
	static BONDIDeviceStatus *shared = nil;
	if (!shared){
		UIWebView *webView= [[[UIApplication sharedApplication] delegate] webView];
		shared = [[self alloc] initWithWebView:webView];
		shared.listeners = [[NSMutableArray alloc] init];
		shared.oldValues = [[NSMutableArray alloc] init];
	}
	return shared;
}

- (void)createCallback:(NSString*)callback withString1:(id)string1 withString2:(id)string2{
	NSLog(@"BONDIDeviceStatus.createCallback");
	if (callback) {
		NSString* jsString;
		jsString = [[NSString alloc] initWithFormat:@"%@(eval(%@),\"%@\");", callback, string1, string2];
		NSLog(jsString);
		[webView stringByEvaluatingJavaScriptFromString:jsString];
		[jsString release];
	}
}

- (NSString *)getPropertyValue:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	//duplicate properties possible, check return types - works for battery and os for now
	NSUInteger argc = [arguments count];
	NSString* aspect = nil, *property = nil;
	
	if (argc > 0) aspect = [arguments objectAtIndex:0];
	if (argc > 1) property = [arguments objectAtIndex:1];
	
	NSLog(@"BONDIDeviceStatus.getPropertyValue: %@ %@",aspect,property);
	//filtering with aspect parameter, otherwise all properties are retrieved
	UIDevice *device = [UIDevice currentDevice];
    NSMutableDictionary *devProps = [NSMutableDictionary dictionaryWithCapacity:5];
	//Operating System
	[devProps setObject:[device systemName] forKey:@"name"];
    [devProps setObject:@"Apple" forKey:@"vendor"];
    [devProps setObject:[device systemVersion] forKey:@"version"];	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *languages = [defaults objectForKey:@"AppleLanguages"];
	NSString *currentLanguage = [languages objectAtIndex:0];	
    [devProps setObject:currentLanguage forKey:@"language"];
	
	//Battery (batteryCapacity, batteryTime : no information)
	device.batteryMonitoringEnabled = YES;
	//batteryLevel = Integer 
	[devProps setObject:[NSString stringWithFormat:@"%.0f",[device batteryLevel]*100] forKey:@"batteryLevel"];
	[devProps setObject:@"Li-Ion" forKey:@"batteryTechnology"];
	
	UIDeviceBatteryState batteryState = device.batteryState;
	if (batteryState == UIDeviceBatteryStateCharging)
		[devProps setObject:@"true" forKey:@"batteryBeingCharged"];
	else {
		[devProps setObject:@"false" forKey:@"batteryBeingCharged"];
	}
	return [devProps objectForKey:property];
	
}
- (NSString *)watchPropertyChange:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString *listener = nil;
	NSArray *watchPropertyInfo = nil;
	NSDictionary *watchOptionsDictionary = nil, *propertyRefDictionary = nil;
	NSUInteger minTimeout = 0, maxTimeout = NSIntegerMax, minChangePercent=0;
	BOOL callCallbackOnRegister = NO;
	NSError *error = nil;
	SBJSON *parser = [[SBJSON alloc] init];
		
	listener = @"bondi.devicestatus.propertyChangeSuccess";
	if (argc > 0) {
		propertyRefDictionary = [parser objectWithString:[arguments objectAtIndex:0] error:&error];
		if (error)
			return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
		
	}
	if (argc > 1) {
		watchOptionsDictionary = [parser objectWithString:[arguments objectAtIndex:1] error:&error];
		if (error)
			return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
	}
	
	if (watchOptionsDictionary) {
		minTimeout =[[watchOptionsDictionary objectForKey:@"minTimeout"] unsignedIntValue];
		if (!minTimeout) minTimeout= 0;
		maxTimeout = [[watchOptionsDictionary objectForKey:@"maxTimeout"] unsignedIntValue];
		if (!maxTimeout) maxTimeout = NSIntegerMax;
		callCallbackOnRegister = [[watchOptionsDictionary objectForKey:@"callCallbackOnRegister"] boolValue];
		if (!callCallbackOnRegister) callCallbackOnRegister = NO;
		minChangePercent = [[watchOptionsDictionary objectForKey:@"minChangePercent"] unsignedIntValue];
		if (!minChangePercent) minChangePercent = 0;
	}

	NSLog(@"BONDIDeviceStatus.watchPropertyChange: %@ %@ %@",listener,[propertyRefDictionary description],[watchOptionsDictionary description]);
	
	watchPropertyInfo = [NSArray arrayWithObjects: [NSNumber numberWithInt:[listeners count]], listener, watchOptionsDictionary, propertyRefDictionary, nil];
	NSMutableArray *timers = [[NSMutableArray alloc] init];
	NSTimer *timerMin;	
	timerMin = [NSTimer scheduledTimerWithTimeInterval: minTimeout/1000 //ms in s
											 target: self
										   selector: @selector(handleCallback:)
										   userInfo: watchPropertyInfo
											repeats: YES];
	[timers addObject:timerMin];
	NSTimer *timerMax;
	if (maxTimeout != NSIntegerMax) {
		NSLog(@"maxTimeout created");
		timerMax = [NSTimer scheduledTimerWithTimeInterval: maxTimeout/1000 //ms in s
											 target: self
										   selector: @selector(handleCallback:)
										   userInfo: watchPropertyInfo
											repeats: YES];
		[timers addObject:timerMax];
	}
	[listeners addObject:timers];
	[oldValues addObject:[NSNumber numberWithInt:-1]]; //no old value = -1
	
	if (callCallbackOnRegister){
		[NSTimer scheduledTimerWithTimeInterval: 0.1
										 target: self
									   selector: @selector(handleCallback:)
									   userInfo: watchPropertyInfo
										repeats: NO];
	}
	
	return [NSString stringWithFormat:@"%i",[listeners count]-1]; //count as id, since properties are added as last object
}

-(bool) isNumeric:(NSString*) checkText
{	
	NSNumberFormatter* numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];	
	NSNumber* number = [numberFormatter numberFromString:checkText];	
	if (number != nil) {
		return true;
	}
	return false;
}
- (void) handleCallback: (NSTimer *) timer{
	NSArray *watchPropertyInfo = [timer userInfo];
	NSUInteger index = [[watchPropertyInfo objectAtIndex:0] intValue];
	NSString *listener = [watchPropertyInfo objectAtIndex:1];
	NSDictionary *watchOptionsDictionary = [watchPropertyInfo objectAtIndex:2], *propertyRefDictionary = [watchPropertyInfo objectAtIndex:3];
	double maxTimeout = 0.0;
	NSUInteger minChangePercent=0;
	if (watchOptionsDictionary) {
		maxTimeout = [[watchOptionsDictionary objectForKey:@"maxTimeout"] doubleValue];
		if (!maxTimeout) maxTimeout = 0.0;
		minChangePercent = [[watchOptionsDictionary objectForKey:@"minChangePercent"] unsignedIntValue];
		if (!minChangePercent) minChangePercent = 0;
	}
	BOOL maxTimeoutFired = NO;
	if (maxTimeout != 0.0){
		 maxTimeoutFired = maxTimeout/1000.0 == [timer timeInterval];
		 if (maxTimeoutFired)
			 NSLog(@"maxTimeoutFired");
	}
	
	NSString *propertyRefProperty = [propertyRefDictionary objectForKey:@"property"];
	if (propertyRefProperty) {
		NSMutableArray *arguments = [[NSMutableArray alloc] initWithObjects:@"",propertyRefProperty,nil];
		SBJSON *parser = [[SBJSON alloc] init];
		NSString *newValue = [self getPropertyValue:arguments withDict:nil];
		BOOL callback = YES;
		if (newValue){
			//check for minChangePercent
			if (!maxTimeoutFired && [self isNumeric:newValue] && minChangePercent != 0){				
				NSNumberFormatter* numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
				double newNumber = abs([[numberFormatter numberFromString:newValue] doubleValue]);				 
				double oldNumber = [[oldValues objectAtIndex:index] doubleValue];
				double difference = oldNumber-newNumber;
				if (difference < 0.0) //abss
					difference *=-1;
				if (oldNumber != -1.0) //if no old number do callback anyway
					callback = difference > (minChangePercent/100.0)*oldNumber;	
				//NSLog(@" %f %f ", difference, (minChangePercent/100.0)*oldNumber);
				//NSLog(@"minChangePercent: i: %.2f new: %.2f old: %.2f callback: %i", i, newNumber, oldNumber, callback);
				if (callback)
					[oldValues replaceObjectAtIndex:index withObject:[NSNumber numberWithDouble:newNumber]];
			}
			
			if (callback)
				 [self createCallback:listener withString1:[parser stringWithObject:propertyRefDictionary] withString2:newValue];
			
		}
	}
}



- (NSString *)clearPropertyChange:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSInteger watchHandler;
	if (argc > 0) watchHandler = [[arguments objectAtIndex:0] integerValue];
	
	NSLog(@"BONDIDeviceStatus.clearPropertyChange: %i",watchHandler);
	NSMutableArray *timers = [listeners objectAtIndex:watchHandler];
	if (!timers)
		return [NSString stringWithFormat:@"%i", INVALID_ARGUMENT_ERROR];
	//stop and remove timer
	[[timers objectAtIndex:0] invalidate];
	if ([timers count] > 1)
		[[timers objectAtIndex:1] invalidate];
	[listeners removeObjectAtIndex:watchHandler];
	[oldValues removeObjectAtIndex:watchHandler];
	return nil;
}

@end
