//
//  Camera+BONDI.m
//  PhoneGap
//
//  Created by iptv on 18.11.09.
//  Copyright 2009 Fraunhofer FOKUS. All rights reserved.
//

#import "BONDICamera.h"
#import "NSData+Base64.h"
#import "Categories.h"
#import "SBJSON.h";
#import "BONDIErrorCodes.h"

NSInteger const CAMERA_ALREADY_IN_USE_ERROR = 0;
NSInteger const CAMERA_CAPTURE_ERROR = 1;
NSInteger const CAMERA_LIVEVIDEO_ERROR = 2;

@implementation BONDICamera


- (void)createCallback:(NSString*)callback withFunction:(id)function withString:(id)string {
	NSLog(@"BONDICamera.createCallback");
	if (callback) {
		NSString* jsString;
		if (function)
			jsString = [[NSString alloc] initWithFormat:@"%@(%@);", callback, function];
		else if (string)
			jsString = [[NSString alloc] initWithFormat:@"%@(\"%@\");", callback, string];
		NSLog(@"%@",jsString);
		[webView stringByEvaluatingJavaScriptFromString:jsString];
		[jsString release];
	}
}

- (void)createCallbackDelayed:(NSTimer*)timer {
	NSLog(@"BONDICamera.createCallbackDelayed");
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


- (NSString *) takePicture:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString* successCallback = nil, *errorCallback = nil;
	NSDictionary *cameraOptionsDictionary;
	NSError *error = nil;
	SBJSON *parser = [[SBJSON alloc] init];
	NSTimer *timer;	

	successCallback = @"bondi.camera.cameraSuccess";
	errorCallback = @"bondi.camera.cameraError";
	if (argc > 0) {
		cameraOptionsDictionary = [parser objectWithString:[arguments objectAtIndex:0] error:&error];
		if (error){
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", PERMISSION_DENIED_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
	}
	NSLog(@"BONDICamera.takePicture: %@ %@ %@",successCallback, errorCallback, [cameraOptionsDictionary description]);
	
	bool hasCamera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
	if (!hasCamera) {
		NSLog(@"Camera.getPicture: Camera not available.");		
		NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", CAMERA_CAPTURE_ERROR];
		NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}
	if (pickerController == nil) {
		pickerController = [[CameraPicker alloc] init];
		pickerController.delegate = self;
		pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
		pickerController.successCallback = successCallback;
		pickerController.errorCallback = errorCallback;
		//options not supported: with, height
		//pickerController.quality = [cameraOptionsDictionary integerValueForKey:@"quality" defaultValue:100 withRange:NSMakeRange(0, 100)];
	}
	timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(startModalView:) userInfo:nil repeats:NO];
	return nil;
}

- (void)startModalView:(NSTimer *)timer {
	[[super appViewController] presentModalViewController:pickerController animated:YES];
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingImage:(UIImage*)image editingInfo:(NSDictionary*)editingInfo
{ 	
	CameraPicker* cameraPicker = (CameraPicker*)picker;
	CGFloat quality = (double)cameraPicker.quality / 100.0; 
	
	//store file with current date
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];	
	NSString *imageLocation = [documentsDirectory stringByAppendingPathComponent:@"My Pictures"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL success;
	if (![fileManager fileExistsAtPath:imageLocation]){
		success = [fileManager createDirectoryAtPath:imageLocation attributes:nil];
	}
	
	NSDate *currentDate = [NSDate date];
	NSString *strDate = [currentDate description];
	NSString *imgFileName = [[NSString alloc] initWithFormat:@"%@.jpg",strDate];
	NSString *imgFile = [imageLocation stringByAppendingPathComponent:imgFileName];	
	[UIImageJPEGRepresentation(image, quality) writeToFile:imgFile atomically:YES];
	NSLog(@"%@",imgFile);
	
	[picker dismissModalViewControllerAnimated:YES];
	
	//callback with path to image file
	NSTimer* timer;
	NSArray *callbackInfo = [NSArray arrayWithObjects:cameraPicker.successCallback, @"", imgFile, nil];		
	timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
	[picker dismissModalViewControllerAnimated:YES];
	CameraPicker* cameraPicker = (CameraPicker*)picker;
	NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", CAMERA_CAPTURE_ERROR];
	NSArray *callbackInfo = [NSArray arrayWithObjects:cameraPicker.errorCallback, parameter, @"", nil];	
	NSTimer *timer;
	timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
}

@end
