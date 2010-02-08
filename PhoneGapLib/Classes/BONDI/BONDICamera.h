//
//  Camera+BONDI.h
//  PhoneGap
//
//  Created by iptv on 18.11.09.
//  Copyright 2009 Fraunhofer FOKUS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Camera.h"

extern NSInteger const CAMERA_ALREADY_IN_USE_ERROR;
extern NSInteger const CAMERA_CAPTURE_ERROR;
extern NSInteger const CAMERA_LIVEVIDEO_ERROR;

@interface BONDICamera : Camera

- (void)createCallback:(NSString*)callback withFunction:(id)function withString:(id)string;

- (NSString *)takePicture:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingImage:(UIImage*)image editingInfo:(NSDictionary*)editingInfo;
- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker;
@end
