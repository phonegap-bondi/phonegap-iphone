//
//  BONDIFilesystem.h
//  MoRIA
//
//  Acccess to app's sandbox
//  Created by iptv on 24.11.09.
//  Copyright 2009 Fraunhofer FOKUS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PhoneGapCommand.h"

@interface BONDIFilesystem : PhoneGapCommand {
	NSMutableDictionary *readFileHandles;
	NSMutableDictionary *writeFileHandles;
	NSMutableDictionary *updateFileHandles;
}

@property (nonatomic, retain) NSMutableDictionary *readFileHandles;
@property (nonatomic, retain) NSMutableDictionary *writeFileHandles;
@property (nonatomic, retain) NSMutableDictionary *updateFileHandles;

+ (id) sharedBONDIFilesystem;
- (void)createCallback:(NSString*)callback withFunction:(id)function withString:(id)string;

//FileSystemManager
- (NSString *)getDefaultLocation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)resolve:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
//File
- (NSString *)listFiles:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)copyTo:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)moveTo:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)open:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)createFile:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)createDirectory:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)deleteDirectory:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)deleteFile:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

//FileStream
- (NSString *)seek:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)read:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)readBytes:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)readBase64:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)write:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)writeBytes:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)writeBase64:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (NSString *)close:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end
