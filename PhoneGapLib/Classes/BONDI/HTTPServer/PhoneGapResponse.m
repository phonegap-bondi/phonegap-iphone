#import "PhoneGapResponse.h"
//TODO: Security measures: only allow localhost requests

#import "HTTPServer.h"
#import "BONDIFilesystem.h"
#import "BONDIDeviceStatus.h"

@implementation PhoneGapResponse

//
// load
//
// Implementing the load method and invoking
// [HTTPResponseHandler registerHandler:self] causes HTTPResponseHandler
// to register this class in the list of registered HTTP response handlers.
//
+ (void)load
{
	[HTTPResponseHandler registerHandler:self];
}

//
// canHandleRequest:method:url:headerFields:
//
// Class method to determine if the response handler class can handle
// a given request.
//
// Parameters:
//    aRequest - the request
//    requestMethod - the request method
//    requestURL - the request URL
//    requestHeaderFields - the request headers
//
// returns YES (if the handler can handle the request), NO (otherwise)
//
+ (BOOL)canHandleRequest:(CFHTTPMessageRef)aRequest
	method:(NSString *)requestMethod
	url:(NSURL *)requestURL
	headerFields:(NSDictionary *)requestHeaderFields
{	
	return YES;
}

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] initWithCapacity:6] autorelease];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

//
// startResponse
//
// Since this is a simple response, we handle it synchronously by sending
// everything at once.
//
- (void)startResponse
{
	
	//start parsing from URL and HTTP Header (X-Bondi) , options are optional
	//example:  http://localhost:8080/<className>/<methodName>;arg1;arg2?option1=something&option2=other
	
	NSArray *pathsArray = [url.path componentsSeparatedByString:@"/"];
	className = [[pathsArray objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	methodName = [[pathsArray objectAtIndex:2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	//retrieving arguments from HTTP header
	NSString *headerValue = [headerFields objectForKey:@"X-Bondi"];
	if (headerValue) {
		arguments = (NSMutableArray *)[headerValue componentsSeparatedByString:@";"];
	} else { //retrieving from HTTP url
		arguments = (NSMutableArray *)[[url.parameterString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] componentsSeparatedByString:@";"];
		options = (NSMutableDictionary *)[self parseQueryString:[url.query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	
	//NSLog(@"[HTTP-Server] HTTP.get: %@, %@, %@, %@", className, methodName, arguments.description, options.description);

	NSString *returnValue = nil;
	
	
	UIWebView *webView= [[[UIApplication sharedApplication] delegate] webView];
	id obj;
	//BONDIFilesystem singleton
	if ([className isEqualToString:@"BONDIFilesystem"])
		obj = [BONDIFilesystem sharedBONDIFilesystem];
	else if ([className isEqualToString:@"BONDIDeviceStatus"])
		obj = [BONDIDeviceStatus sharedBONDIDeviceStatus];
	else	
		obj = [[NSClassFromString(className) alloc] initWithWebView:webView];
	
	if (obj != nil) {
		// construct the fill method name to ammend the second argument.
		NSString* fullMethodName = [[NSString alloc] initWithFormat:@"%@:withDict:", methodName];
		if ([obj respondsToSelector:NSSelectorFromString(fullMethodName)]){
			returnValue = [obj performSelector:NSSelectorFromString(fullMethodName) withObject:arguments withObject:options];
			NSLog(@"[HTTP-Server] response: %@",returnValue);
			NSData *returnData = [returnValue dataUsingEncoding:NSUTF8StringEncoding];
			
			CFHTTPMessageRef response =
			CFHTTPMessageCreateResponse(
										kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
			CFHTTPMessageSetHeaderFieldValue(
											 response, (CFStringRef)@"Content-Type", (CFStringRef)@"text/plain");
			CFHTTPMessageSetHeaderFieldValue(
											 response, (CFStringRef)@"Connection", (CFStringRef)@"close");
			CFHTTPMessageSetHeaderFieldValue(
											 response,
											 (CFStringRef)@"Content-Length",
											 (CFStringRef)[NSString stringWithFormat:@"%ld", [returnData length]]);
			CFDataRef headerData = CFHTTPMessageCopySerializedMessage(response);
			
			@try
			{
				[fileHandle writeData:(NSData *)headerData];
				[fileHandle writeData:returnData];
			}
			@catch (NSException *exception)
			{
				// Ignore the exception, it normally just means the client
				// closed the connection from the other end.
			}
			@finally
			{
				CFRelease(headerData);
				[server closeHandler:self];
			}
		}
		else
			NSLog(@"Class method '%@' not defined in class '%@'", methodName, className);
	}
	else
		NSLog(@"%@ does not exist", className);
	

}
@end
