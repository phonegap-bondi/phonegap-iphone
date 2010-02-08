//
//  BONDIDeviceStatus.h
//  PhoneGapLib
//
//  Created by sph on 20.01.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PhoneGapCommand.h"

@interface BONDIDeviceStatus : PhoneGapCommand {
	NSMutableArray *listeners;
	NSMutableArray *oldValues;
}
@property (nonatomic, retain) NSMutableArray *listeners;
@property (nonatomic, retain) NSMutableArray *oldValues;

+ (id) sharedBONDIDeviceStatus;
- (void)createCallback:(NSString*)callback withString1:(id)string1 withString2:(id)string2;

- (NSString *)getPropertyValue:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)watchPropertyChange:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)clearPropertyChange:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end
