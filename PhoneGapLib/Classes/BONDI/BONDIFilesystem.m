//
//  BONDIFilesystem.m
//  MoRIA
//
//  Created by iptv on 24.11.09.
//  Copyright 2009 Fraunhofer FOKUS. All rights reserved.
//

#import "BONDIFilesystem.h"
#import "BONDIErrorCodes.h"
#import "JSON.h"
#import "NSData+Base64.h"

@implementation BONDIFilesystem
@synthesize readFileHandles, writeFileHandles, updateFileHandles;

+ (id) sharedBONDIFilesystem
{
	static BONDIFilesystem *shared = nil;
	if (!shared){
		UIWebView *webView= [[[UIApplication sharedApplication] delegate] webView];
		shared = [[self alloc] initWithWebView:webView];
		shared.readFileHandles = [[NSMutableDictionary alloc] init];
		shared.writeFileHandles = [[NSMutableDictionary alloc] init];
		shared.updateFileHandles = [[NSMutableDictionary alloc] init];
	}
	return shared;
}

#pragma mark -
#pragma mark Helper Methods

- (NSString *)stringWithBool:(BOOL)boolean{
	return [NSString stringWithFormat:@"%@",boolean ? @"true" : @"false"];
}

-(BOOL)boolWithString:(NSString*)boolString{
	return [boolString isEqualToString:@"true"] ? YES : NO;
}

//needed for async functions (copyTo, moveTo etc.)
- (void)createCallbackDelayed:(NSTimer*)timer {
	NSLog(@"BONDIFilesystem.createCallbackDelayed");
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

- (void)createCallback:(NSString*)callback withFunction:(id)function withString:(id)string {
	NSLog(@"BONDIFilesystem.createCallback");
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

#pragma mark -
#pragma mark FileSystemManager

- (NSString *)resolveLocation:(NSString *)location addMode:(NSString *)mode{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error = nil;
	NSDictionary *attributes = [fileManager attributesOfItemAtPath:location error:&error];
	if (error) {
		NSLog(@"%@",[error localizedDescription]);
		return [NSString stringWithFormat:@"%i", INVALID_ARGUMENT_ERROR];
		
	} else {
		//create JSON manually (object)	
		
		//resolve parent
		NSString *parentString = [location stringByDeletingLastPathComponent];
		NSString *parent = nil;
		if (![location isEqualToString:documentsDirectory]){ //assuming documentsDirectory is root
			//recursively creating parent objects
			parent = [self resolveLocation:parentString addMode:mode];
		}		
		
		BOOL isFile = FALSE, isDirectory = FALSE;
		if([[attributes fileType] isEqualToString:@"NSFileTypeRegular"]){
			isFile = TRUE;
		}
		else {
			isDirectory = TRUE;
		}
		
		NSString *fileInfo = [[NSString alloc]
							  initWithFormat:@"{parent: %@, mode: '%@', readOnly: %@, isFile: %@, isDirectory: %@, created: '%@' , modified: '%@', path: '%@' , name: '%@' , absolutePath: '%@' , fileSize: %i}",
							  parent, //parent is another JSON object
							  mode,
							  [self stringWithBool:[attributes fileIsAppendOnly]],
							  [self stringWithBool:isFile],
							  [self stringWithBool:isDirectory],
							  [attributes fileCreationDate],
							  [attributes fileModificationDate],
							  [location stringByDeletingLastPathComponent],
							  [location lastPathComponent],
							  [location stringByStandardizingPath],
							  [attributes fileSize]
							  ];
		return fileInfo;
	}
		
	
}

- (NSString *)getDefaultLocation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *documentsDirectory = [paths objectAtIndex:0];	
	
	NSUInteger argc = [arguments count];
	NSString* specifier = nil;
	
	if (argc > 0) specifier = [arguments objectAtIndex:0];
	NSLog(@"[INFO] BONDIFilesystem.getDefaultLocation:%@",specifier);
	
	NSString *specifiedLocation = nil;
	if ([specifier isEqualToString:@"wgt-private"])
		specifiedLocation = [documentsDirectory stringByAppendingPathComponent:@"Private"];
	else if ([specifier isEqualToString:@"documents"])
		specifiedLocation = [documentsDirectory stringByAppendingPathComponent:@"My Documents"];
	else if ([specifier isEqualToString:@"images"])
		specifiedLocation = [documentsDirectory stringByAppendingPathComponent:@"My Pictures"];

	BOOL success = TRUE;
	if (![fileManager fileExistsAtPath:specifiedLocation]){
		success = [fileManager createDirectoryAtPath:specifiedLocation attributes:nil];
	}
	
	if (success)
		return specifiedLocation;
	else
		return nil;
}

//TODO: resolve mode parameter handling
- (NSString *)resolve:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString* successCallback = nil, *errorCallback = nil, *location = nil, *mode = nil;
	NSTimer *timer;
	
	successCallback = @"bondi.filesystem.fileSystemResolveSuccess";
	errorCallback =  @"bondi.filesystem.fileSystemError";
	if (argc > 0) location = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	
	NSLog(@"[INFO] BONDIFilesystem.resolve: %@ %@",location,mode);	
	
	NSString *resolvedLocation = [self resolveLocation:location addMode:mode];
	if ([resolvedLocation isEqualToString:[NSString stringWithFormat:@"%i", INVALID_ARGUMENT_ERROR]]){
		NSString *parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", INVALID_ARGUMENT_ERROR];
		NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
	} else {
		NSArray *callbackInfo = [NSArray arrayWithObjects:successCallback, @"", resolvedLocation, nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
	}
	return nil;
}
#pragma mark -
#pragma mark File

- (NSString *)file_resolve:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	
	NSUInteger argc = [arguments count];
	NSString* location = nil, *mode = nil;
	if (argc > 0) location = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	NSLog(@"[INFO] BONDIFilesystem.File.resolve:%@ %@",location, mode);	
	
	return [self resolveLocation:location addMode:mode];
	
}

- (NSString *)listFiles:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSUInteger argc = [arguments count];
	NSString* path = nil, *mode = nil;
	if (argc > 0) path = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	NSLog(@"[INFO] BONDIFilesystem.listFiles:%@ %@",path, mode);
	
	NSError *error = nil;
	NSArray *directoryContent = [fileManager contentsOfDirectoryAtPath:path error:&error];
	if (error)
	{
		NSLog(@"%@",[error localizedDescription]);
		return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
	}

	//create JSON manually (array of objects)
	NSString *jsonString = @"[";
	
	for (NSString *file in directoryContent){
		NSString * fileInfoJSON = [self resolveLocation:[path stringByAppendingPathComponent:file] addMode:mode];
		jsonString = [jsonString stringByAppendingString:[NSString stringWithFormat:@"%@, ",fileInfoJSON]];
	}

	if([jsonString length]>2) //otherwise no files were found
		jsonString = [jsonString substringToIndex:[jsonString length]-2]; //remove last comma
	jsonString = [jsonString stringByAppendingString:@" ]"];
	
	return jsonString;
}

- (NSString *)copyTo:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSString* successCallback = nil, *errorCallback = nil, *filePath = nil, *srcPath = nil;
	BOOL overwrite;
	NSError *error = nil;
	NSTimer *timer;
	
	successCallback = @"bondi.filesystem.fileSystemSuccess";
	errorCallback =  @"bondi.filesystem.fileSystemError";
	if (argc > 0) srcPath = [arguments objectAtIndex:0];
	if (argc > 1) filePath = [arguments objectAtIndex:1];
	if (argc > 2) overwrite = [self boolWithString:[arguments objectAtIndex:2]];

	NSLog(@"[INFO] BONDIFilesystem.copyTo: %@ %@ %i",srcPath,filePath,overwrite);
	
	if (overwrite) {
		if ([fileManager fileExistsAtPath:filePath]){
			[fileManager removeItemAtPath:filePath error:&error];
			if (error) {
				NSLog(@"%@",[error localizedDescription]);
				NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
				NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
				timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
				return nil;				
			} 
		}
	} else {
		if ([fileManager fileExistsAtPath:filePath]){ //overwrite is false and target file exists => IO_ERROR
			NSLog(@"fileExistsAtPath %@",[error localizedDescription]);
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
	}	
	BOOL operationSuccess = [fileManager copyItemAtPath:srcPath toPath:filePath error:&error];
	if (operationSuccess){
		NSArray *callbackInfo = [NSArray arrayWithObjects:successCallback, @"", srcPath, nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}else{
		if (error) {
			NSLog(@"%@",[error localizedDescription]);
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;	
		} else {
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", PERMISSION_DENIED_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
		
	}
	

}

- (NSString *)moveTo:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSString* successCallback = nil, *errorCallback = nil, *filePath = nil, *srcPath = nil;
	BOOL overwrite;
	NSError *error = nil;
	NSTimer *timer;
	
	successCallback = @"bondi.filesystem.fileSystemSuccess";
	errorCallback =  @"bondi.filesystem.fileSystemError";
	if (argc > 0) srcPath = [arguments objectAtIndex:0];
	if (argc > 1) filePath = [arguments objectAtIndex:1];
	if (argc > 2) overwrite = [self boolWithString:[arguments objectAtIndex:2]];
	NSLog(@"[INFO] BONDIFilesystem.moveTo: %@ %@ %i",srcPath,filePath,overwrite);
	if (overwrite) {
		if ([fileManager fileExistsAtPath:filePath]){
			[fileManager removeItemAtPath:filePath error:&error];
			if (error) {
				NSLog(@"%@",[error localizedDescription]);
				NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
				NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
				timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
				return nil;
			} 
		}
	} else {
		if ([fileManager fileExistsAtPath:filePath]){ //overwrite is false and target file exists => IO_ERROR
			NSLog(@"%@",[error localizedDescription]);
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
	}	
	BOOL operationSuccess = [fileManager moveItemAtPath:srcPath toPath:filePath error:&error];
	if (operationSuccess){
		NSArray *callbackInfo = [NSArray arrayWithObjects:successCallback, @"", srcPath, nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}else{
		if (error) {
			NSLog(@"%@",[error localizedDescription]);
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;	
		} else {
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", PERMISSION_DENIED_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
		
	}
}

- (NSString *)open:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString *path, *mode, *encoding;
	if (argc > 0) path = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	if (argc > 2) encoding = [arguments objectAtIndex:2];
	NSLog(@"[INFO] BONDIFilesystem.open:%@ %@ %@",path,mode,encoding);
	
	NSFileHandle *fileHandle = nil;
	if ([mode isEqualToString:@"r"]){
		fileHandle= [NSFileHandle fileHandleForReadingAtPath:path];
		if (fileHandle)
			[readFileHandles setObject:fileHandle forKey:path];
	}
	else if ([mode isEqualToString:@"w"]){
		fileHandle= [NSFileHandle fileHandleForWritingAtPath:path];
		if (fileHandle)
			[writeFileHandles setObject:fileHandle forKey:path];
	}
	else { //append
		fileHandle= [NSFileHandle fileHandleForUpdatingAtPath:path];
		if (fileHandle)
			[updateFileHandles setObject:fileHandle forKey:path];
	}	
	if (!fileHandle) {
		return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
	} else {
		return [self addFileStreamAttributes:fileHandle withString:nil withPath:path];
	}
}

- (NSString *)createFile:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSString *path;
	if (argc > 0) path = [arguments objectAtIndex:0];
	NSLog(@"[INFO] BONDIFilesystem.createFile:%@",path);
	
	BOOL success = NO;
	if  (![fileManager fileExistsAtPath:path]){		
		success = [fileManager createFileAtPath:path contents:nil attributes:nil];
		NSLog(@"creating file");
	}
	if (!success)
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	else 
		return [self resolveLocation:path addMode:@"rw"]; //returns json file object
	
}

- (NSString *)deleteDirectory:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSError *error = nil;
	NSString* successCallback = nil, *errorCallback = nil, *path = nil;
	NSTimer *timer;
	BOOL recursive, success;
	
	successCallback = @"bondi.filesystem.fileSystemSuccess";
	errorCallback =  @"bondi.filesystem.fileSystemError";
	if (argc > 0) path = [arguments objectAtIndex:0];
	if (argc > 1) recursive = [self boolWithString:[arguments objectAtIndex:1]];
	NSLog(@"[INFO] BONDIFilesystem.deleteDirectory:%@ %d",path, recursive);
	
	//only empty dirs can be deleted non-recursively
	NSArray *dir = [fileManager contentsOfDirectoryAtPath:path error:&error];
	if (dir==nil || ([dir lastObject]!=nil && !recursive)) { //not existing dir or not empty and not recursive
		NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
		NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}else {
		success = [fileManager removeItemAtPath:path error:&error];
		if (!success){
			NSLog(@"%@",[error description]);
			NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", IO_ERROR];
			NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
			timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
			return nil;
		}
	}
	
	if (error){
		NSLog(@"%@",[error description]);
		NSString * parameter = [[NSString alloc] initWithFormat:@"new GenericError(%i)", PERMISSION_DENIED_ERROR];
		NSArray *callbackInfo = [NSArray arrayWithObjects:errorCallback, parameter, @"", nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}
	
	if (success){
		NSArray *callbackInfo = [NSArray arrayWithObjects:successCallback, @"", path, nil];		
		timer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(createCallbackDelayed:) userInfo:callbackInfo repeats:NO];
		return nil;
	}
	return nil;
}

- (NSString *)deleteFile:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSString *path;
	if (argc > 0) path = [arguments objectAtIndex:0];
	NSLog(@"[INFO] BONDIFilesystem.deleteFile:%@",path);
	
	NSError *error = nil;
	BOOL success = [fileManager removeItemAtPath:path error:&error];
	if (!success){
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	}
	if (error){
		NSLog(@"%@",[error description]);
		return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
	}
	
	return nil;
}

- (NSString *)createDirectory:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUInteger argc = [arguments count];
	NSString *path;
	if (argc > 0) path = [arguments objectAtIndex:0];
	NSLog(@"[INFO] BONDIFilesystem.createDirectory:%@",path);
	BOOL success;
	NSError *error = nil;
	if (![fileManager fileExistsAtPath:path])	
		success = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	else
		success = NO;

	if (error){
		NSLog(@"%@",[error localizedDescription]);
		return [NSString stringWithFormat:@"%i", PERMISSION_DENIED_ERROR];
	}
	if (!success)
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	else 
		return [self resolveLocation:path addMode:@"rw"]; //returns json file object
	
}


#pragma mark -
#pragma mark FileStream

- (NSString *) addFileStreamAttributes:(NSFileHandle *)fileHandle withString:(NSString*)dataString withPath:(NSString*)path{
	int filesize = -1;
	if (path) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
		filesize = [attributes fileSize];
	}
	NSString *fileStreamAttributes = [[NSString alloc]
									  initWithFormat:@"{ filesize: %i ,data: %@, position: %i }",
									  filesize,
									  dataString,  
									  [fileHandle offsetInFile]
									  ];
	return fileStreamAttributes;
}

- (NSString *)seek:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString *path, *mode;
	NSInteger position;
	if (argc > 0) path = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	if (argc > 2) position = [[arguments objectAtIndex:2] integerValue];
	NSLog(@"[INFO] BONDIFilesystem.seek: %@ %@ %i",path,mode,position);
	
	NSFileHandle *fileHandle;
	if ([mode isEqualToString:@"r"]){
		fileHandle = [readFileHandles objectForKey:path];
	}
	else if ([mode isEqualToString:@"w"]){
		fileHandle= [writeFileHandles objectForKey:path];
	}
	else { //append
		fileHandle= [updateFileHandles objectForKey:path];
	}
	
	if (!fileHandle){
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	} else{
		@try {
			[fileHandle seekToFileOffset:position];
		} 
		@catch (id exception) {
			NSLog(@"%@", exception);
			return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
		}	
	}
	return [self addFileStreamAttributes:fileHandle withString:nil withPath:path];
}

- (NSString *)read:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSFileHandle *fileHandle;
	NSData *fileData;
	
	NSInteger byteCount;
	NSString *path, *mode, *encoding;
	if (argc > 0) byteCount = [[arguments objectAtIndex:0] integerValue];
	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.read:%i %@ %@ %@",byteCount,path,mode,encoding);
	
	if ([mode isEqualToString:@"r"])
		fileHandle = [readFileHandles objectForKey:path];
	else
		fileHandle = [updateFileHandles objectForKey:path];

	if (!fileHandle)
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	@try {
		if (byteCount != 0)
			fileData = [fileHandle readDataOfLength:byteCount];
		else {
			fileData = [fileHandle readDataToEndOfFile];
		}
	} 
	@catch (id exception) { //NSFileHandleOperationException
		NSLog(@"%@", exception);
		return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
	}	

	NSString *dataString;
	if ([encoding isEqualToString:@"UTF-8"])
		dataString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
	else
		dataString = [[NSString alloc] initWithData:fileData encoding:NSISOLatin1StringEncoding];
	
	dataString = [NSString stringWithFormat:@"'%@'",dataString];
	return [self addFileStreamAttributes:fileHandle withString:dataString withPath:path];

}

- (NSString *)readBytes:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSFileHandle *fileHandle;
	NSData *fileData;
	NSString *dataString; NSRange range;
	char *buffer;
	
	NSInteger byteCount;
	NSString *path, *mode, *encoding;
	if (argc > 0) byteCount = [[arguments objectAtIndex:0] integerValue];
	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.readBytes:%i %@ %@ %@",byteCount,path,mode,encoding);

	if ([mode isEqualToString:@"r"])
		fileHandle = [readFileHandles objectForKey:path];
	else
		fileHandle = [updateFileHandles objectForKey:path];
	
	if (!fileHandle)
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	@try {
		if (byteCount != 0)
			fileData = [fileHandle readDataOfLength:byteCount];
		else {
			fileData = [fileHandle readDataToEndOfFile];
		}
	} 
	@catch (id exception) {
		NSLog(@"%@", exception);
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	}
	
	buffer = malloc(sizeof(char)*[fileHandle offsetInFile]);
	if ([encoding isEqualToString:@"UTF-8"]){
		dataString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
		range = NSMakeRange(0,[dataString length]); 
		[dataString getBytes:buffer maxLength:[fileHandle offsetInFile] usedLength:NULL encoding:NSUTF8StringEncoding options:1 range:range remainingRange:NULL];
	}
	else{
		dataString = [[NSString alloc] initWithData:fileData encoding:NSISOLatin1StringEncoding];
		range = NSMakeRange(0,[dataString length]); 
		[dataString getBytes:buffer maxLength:[fileHandle offsetInFile] usedLength:NULL encoding:NSISOLatin1StringEncoding options:1 range:range remainingRange:NULL];
	}

	//create JSON manually (byte array)
	NSString *jsonString = @"[";
	for (int i=0;i<[fileHandle offsetInFile];i++) {
		jsonString = [jsonString stringByAppendingString:[NSString stringWithFormat:@"%i, ",buffer[i]]]; 		
	}
	if([jsonString length]>2) //otherwise empty array
		jsonString = [jsonString substringToIndex:[jsonString length]-2]; //remove last comma
	jsonString = [jsonString stringByAppendingString:@" ]"];	

	return [self addFileStreamAttributes:fileHandle withString:jsonString withPath:path];
}

- (NSString *)readBase64:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSFileHandle *fileHandle;
	NSData *fileData;
	NSString *dataString;
	
	NSInteger byteCount;
	NSString *path, *mode, *encoding;
	if (argc > 0) byteCount = [[arguments objectAtIndex:0] integerValue];
	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.readBase64:%i %@ %@ %@",byteCount,path,mode,encoding);
	
	if ([mode isEqualToString:@"r"])
		fileHandle = [readFileHandles objectForKey:path];
	else
		fileHandle = [updateFileHandles objectForKey:path];

	if (!fileHandle)
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	@try {
		if (byteCount != 0)
			fileData = [fileHandle readDataOfLength:byteCount];
		else {
			fileData = [fileHandle readDataToEndOfFile];
		}
	} 
	@catch (id exception) { //NSFileHandleOperationException
		NSLog(@"%@", exception);
		return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
	}

	dataString = [NSString stringWithFormat:@"'%@'",[fileData base64EncodedString]];
	return [self addFileStreamAttributes:fileHandle withString:dataString withPath:path];
}

- (NSString *)write:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSData *data;
	NSString *stringData, *path, *mode, *encoding;
	if (argc > 0) stringData = [arguments objectAtIndex:0];
	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.write:%@ %@ %@ %@",stringData,path,mode,encoding);
			
	NSFileHandle *fileHandle;
	if (![mode isEqualToString:@"r"]){ //only "w" and "a" allowed
		if ([mode isEqualToString:@"w"])
			fileHandle= [writeFileHandles objectForKey:path];
		else
			fileHandle= [updateFileHandles objectForKey:path];
		
		if (!fileHandle)
			return [NSString stringWithFormat:@"%i", IO_ERROR];
		if ([encoding isEqualToString:@"UTF-8"])
			data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
		else
			data = [stringData dataUsingEncoding:NSISOLatin1StringEncoding];
		@try {
			if ([mode isEqualToString:@"a"])
				[fileHandle seekToEndOfFile];
			[fileHandle writeData:data];
		}
		@catch (id exception) { //NSFileHandleOperationException
			NSLog(@"%@", exception);
			return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
		}
		return [self addFileStreamAttributes:fileHandle withString:nil withPath:path]; //no need to add stringData in return
	}
	else
		return [NSString stringWithFormat:@"%i", IO_ERROR];		
	return nil;
}

- (NSString *)writeBytes:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString *stringData;
	NSData *data;

	NSArray *byteArray;
	NSString *path, *mode, *encoding;
	
	byteArray = [[arguments objectAtIndex:0] componentsSeparatedByString:@","];
	char bytes[[byteArray count]];
	for (int i = 0; i<[byteArray count]; i++) {
		bytes[i] = [[byteArray objectAtIndex:i] intValue];
	}

	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.writeBytes: %@ %@ %@ %@",path,mode,encoding,byteArray);
	
	NSFileHandle *fileHandle;
	if (![mode isEqualToString:@"r"]){ //only "w" and "a" allowed
		if ([mode isEqualToString:@"w"])
			fileHandle= [writeFileHandles objectForKey:path];
		else
			fileHandle= [updateFileHandles objectForKey:path];
		
		if (!fileHandle)
			return [NSString stringWithFormat:@"%i", IO_ERROR];		
		
		if ([encoding isEqualToString:@"UTF-8"]){
			stringData = [[NSString alloc] initWithBytes:bytes length:[byteArray count] encoding:NSUTF8StringEncoding];
			data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
		}
		else{
			stringData = [[NSString alloc] initWithBytes:bytes length:[byteArray count] encoding:NSISOLatin1StringEncoding];
			data = [stringData dataUsingEncoding:NSISOLatin1StringEncoding];
		}
		
		NSLog(@"stringData: %@",stringData);
		@try {
			if ([mode isEqualToString:@"a"])
				[fileHandle seekToEndOfFile];
			[fileHandle writeData:data];
		}
		@catch (id exception) { //NSFileHandleOperationException
			NSLog(@"%@", exception);
			return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
		}
		return [self addFileStreamAttributes:fileHandle withString:nil withPath:path]; //no need to add stringData in return
		
	}
	else
		return [NSString stringWithFormat:@"%i", IO_ERROR];
	
	
	return nil;
}

- (NSString *)writeBase64:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSData *data;
	NSString *base64Data, *path, *mode, *encoding;
	if (argc > 0) base64Data = [arguments objectAtIndex:0];
	if (argc > 1) path = [arguments objectAtIndex:1];
	if (argc > 2) mode = [arguments objectAtIndex:2];
	if (argc > 3) encoding = [arguments objectAtIndex:3];
	NSLog(@"[INFO] BONDIFilesystem.writeBase64:%@ %@ %@ %@",base64Data,path,mode,encoding);

	NSFileHandle *fileHandle;
	if (![mode isEqualToString:@"r"]){ //only "w" and "a" allowed
		if ([mode isEqualToString:@"w"])
			fileHandle= [writeFileHandles objectForKey:path];
		else
			fileHandle= [updateFileHandles objectForKey:path];
		
		if (!fileHandle)
			return [NSString stringWithFormat:@"%i", IO_ERROR];		
		data = [NSData dataFromBase64String:base64Data];
		@try {
			if ([mode isEqualToString:@"a"])
				[fileHandle seekToEndOfFile];
			[fileHandle writeData:data];
		}
		@catch (id exception) { //NSFileHandleOperationException
			NSLog(@"%@", exception);
			return [NSString stringWithFormat:@"%i", IO_ERROR]; //rethrow the exception
		}
		return [self addFileStreamAttributes:fileHandle withString:nil withPath:path]; //no need to add stringData in return
	}
	else
		return [NSString stringWithFormat:@"%i", IO_ERROR];		
	return nil;
}

- (NSString *)close:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options{
	NSUInteger argc = [arguments count];
	NSString *path, *mode, *encoding;
	if (argc > 0) path = [arguments objectAtIndex:0];
	if (argc > 1) mode = [arguments objectAtIndex:1];
	if (argc > 2) encoding = [arguments objectAtIndex:2];
	NSLog(@"[INFO] BONDIFilesystem.close: %@ %@ %@",path,mode,encoding);
	
	NSFileHandle *fileHandle;
	if ([mode isEqualToString:@"r"]){
		fileHandle = [readFileHandles objectForKey:path];
	}
	else if ([mode isEqualToString:@"w"]){
		fileHandle= [writeFileHandles objectForKey:path];
	}
	else { //append
		fileHandle= [updateFileHandles objectForKey:path];
	}
	
	[fileHandle closeFile];	
	
	//remove filehandle from its dictionary
	
	if ([mode isEqualToString:@"r"]){
		[readFileHandles removeObjectForKey:path];
	}
	else if ([mode isEqualToString:@"w"]){
		[writeFileHandles removeObjectForKey:path];
	}
	else { //append
		[updateFileHandles removeObjectForKey:path];
	}
	return nil;
}

#pragma mark -
#pragma mark Memory Management

- (void)dealloc
{
    [super dealloc];
	[readFileHandles dealloc];
	[writeFileHandles dealloc];
	[updateFileHandles dealloc];
}

@end
