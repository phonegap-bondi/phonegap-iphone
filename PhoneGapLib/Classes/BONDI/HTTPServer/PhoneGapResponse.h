#import "HTTPResponseHandler.h"

@interface PhoneGapResponse : HTTPResponseHandler
{
	NSString *className;
	NSString *methodName;
	NSMutableArray *arguments;
	NSMutableDictionary *options;
}

@end
