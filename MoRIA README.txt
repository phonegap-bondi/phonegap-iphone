1. Follow README.md to install PhoneGapLib and create a PhoneGap project

2. Add/Replace the following lines in <Project>AppDelegate.m to start the HTTPServer:

#import "HTTPServer.h"

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
[ super applicationDidFinishLaunching:application ];
[[HTTPServer sharedHTTPServer] start];

}



- (void)applicationWillTerminate:(UIApplication *)application
{
	
[[HTTPServer sharedHTTPServer] stop];

}

3. Make "User Header Search Paths" in Project Info -> Build recursive (in order to find HTTPServer Header files)