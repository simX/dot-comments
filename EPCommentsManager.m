//
//  EPCommentsManager.m
//  .mac Comments Manager
//  Created by Simone Manganelli on 2006-09-03.
//
//  Copyright © 2006 Simone Manganelli.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:

//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.

//  Except as contained in this notice, the name(s) of the above copyright
//  holders shall not be used in advertising or otherwise to promote the
//  sale, use or other dealings in this Software without prior written
//  authorization.

//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "EPCommentsManager.h"


@implementation EPCommentsManager



// this is simply the Interface Builder action that initiates comment activation
- (IBAction)activateComments:(id)sender
{
	[self activateCommentsWithUsernameTextField:dotMacUsernameTextField
						passwordSecureTextField:dotMacPasswordTextField
									 webPageURL:[entryPageURLTextField stringValue]];
}

- (IBAction)postComment:(id)sender
{
	[self postTestComment];
}

- (void)postTestComment
{
	// here we make the first xml-rpc authentication call to the .mac server
	
	// set up the xml-rpc invocation reference parameters
	WSMethodInvocationRef theRPCCall;
	NSURL *theRPCAppURL = [NSURL URLWithString:@"http://www.mac.com/WebObjects/Comments.woa/wa/xauthenticateUser"];
	NSString *methodName = @"xauthenticateUser";
	NSDictionary *parameters = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"x938t",@"iv",
																		  @"/simx/dotcomments_iblogtutorial.html",@"postURL",
																		  @"http://comment_url.info",@"userURL",
																		  @"ell",@"s_D",
																		  @"comment author author",@"name",
		nil] forKey:@"plist"];
	
	// create the xml-rpc call
	theRPCCall = WSMethodInvocationCreate((CFURLRef) theRPCAppURL, (CFStringRef) methodName, kWSXMLRPCProtocol);
	
	// set the parameters for the xml-prc call
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef) parameters, (CFArrayRef) [NSArray arrayWithObjects:@"iv",@"postURL",@"userURL",@"s_D",@"name",nil]);
	
	// set the callback method
	WSMethodInvocationSetCallBack(theRPCCall, &postCommentCallback, nil);
	
	// invoke the xml-rpc call
	NSDictionary *result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	NSLog(@"%@",result);
}

void postCommentCallback(WSMethodInvocationRef invocation, void* info, CFDictionaryRef outRef)
{
	
	NSLog(@"%@, %@",info,(NSDictionary *)outRef);
}



// the following method takes 3 arguments: a pointer to a text field where the user
// enters their .mac username, a pointer to a text field where the user
// enters their .mac password, and a string containing a complete URL to a 
// web page hosted on .mac

// this is the main function where all the xml-rpc calls to the .mac comment
// system are transmitted

// note that iWeb actually transmits these calls in a slightly different order:
// iWeb actually terminates the session and then invokes "comment.changeTagForComments"
// as well as "comment.commentIdentifiersSinceChangeTag" afterwards; the transmitted
// cookie also changes, but there does not seem to be any new call to the
// "comments.authenticate" call -- the minor differences in the order of xml-rpc
// calls in the following code and in iWeb doesn't seem to make a difference, though
- (void)activateCommentsWithUsernameTextField:(NSTextField *)usernameTextField
							passwordSecureTextField:(NSSecureTextField *)passwordSecureTextField
										 webPageURL:(NSString *)entryPageURL
{
	// get the .mac username and password from the text field pointers
	NSString *dotMacUsername = [usernameTextField stringValue];
	NSString *dotMacPassword = [passwordSecureTextField stringValue];

	// convert the complete URL to an iDisk File URL, a form that the .mac
	// server uses; this is neither a canonical URL or a file URL
	NSString *iDiskFileURL = [self convertURLToiDiskFileURL:entryPageURL];
	
	[iDiskFileURLTextField setStringValue:iDiskFileURL];
	BOOL isHomepageURL = [self isHomepageURL:entryPageURL];
	
	// this checks whether the provided URL is on the homepage.mac.com
	// subdomain, in which case a dummy HTML file is created
	if (isHomepageURL) [self createDummyFile:iDiskFileURL entryPageURL:entryPageURL iDiskUsername:dotMacUsername];
	
	
	
	// here we make the first xml-rpc authentication call to the .mac server
	
	// set up the xml-rpc invocation reference parameters
	WSMethodInvocationRef theRPCCall;
	NSURL *theRPCAppURL = [NSURL URLWithString:@"https://www.mac.com/WebObjects/WSComments.woa/xmlrpc"];
	NSString *methodName = @"comments.authenticate";
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:dotMacUsername,@"username",dotMacPassword,@"password",nil];
	NSDictionary *result;
	
	// create the xml-rpc call
	theRPCCall = WSMethodInvocationCreate((CFURLRef) theRPCAppURL, (CFStringRef) methodName, kWSXMLRPCProtocol);
	
	// set the parameters for the xml-prc call
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef) parameters, (CFArrayRef) [NSArray arrayWithObjects:@"username",@"password",nil]);
	
	// invoke the xml-rpc call
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	
	// check whether the xml-rpc call succeeeded or not
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
	
	
	// get the headers from the xml-rpc response from the .mac server
	CFHTTPMessageRef headers = (CFHTTPMessageRef)CFDictionaryGetValue((CFDictionaryRef) result, kWSHTTPResponseMessage);
	
	// get the headers into a usable form
	NSDictionary *headerDict = (NSDictionary *)CFHTTPMessageCopyAllHeaderFields(headers);
	
	// here we get the cookie from the xml-rpc response from the .mac server;
	// if we don't get this cookie, subsequent calls will fail
	NSScanner *cookieScanner = [[NSScanner alloc] init];
	[cookieScanner initWithString:[headerDict objectForKey:@"Set-Cookie"]]; // get the "Set-Cookie" header
	[cookieScanner scanUpToString:@"wosid=" intoString:nil]; // find the "wosid" parameter
	[cookieScanner scanString:@"wosid=" intoString:nil];
	NSString *sessionIDString;
	[cookieScanner scanUpToString:@";" intoString:&sessionIDString];
	[cookieScanner scanUpToString:@"woinst=" intoString:nil]; // find the "woinst" parameter
	[cookieScanner scanString:@"woinst=" intoString:nil];
	NSString *sessionInstanceString;
	[cookieScanner scanUpToString:@";" intoString:&sessionInstanceString];
	[cookieScanner release];
	
	NSDictionary *cookieHeaderDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"wosid=%@; woinst=%@",sessionIDString,sessionInstanceString],@"Cookie",nil];
	NSLog(@"%@",cookieHeaderDict);
	
	
	
	// this xml-rpc call tells .mac to set the properties for comments at the new URL
	theRPCAppURL = [NSURL URLWithString:@"http://www.mac.com/WebObjects/WSComments.woa/xmlrpc"];
	methodName = @"comment.setCommentPropertiesForResources";
	parameters = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSDictionary dictionaryWithObjectsAndKeys:@"US/Pacific",@"timezone",@"true",@"visible",@"false",@"allowSubcomments",@"true",@"mutable",
			@"false",@"allowMedia",@"%A, %B %e, %Y - %I:%M %p",@"dateFormat",@"false",@"moderated",@"English",@"lang",@"iweb",@"appid",nil],@"optionsStruct",
		[NSArray arrayWithObjects:iDiskFileURL,nil],@"URL",nil];
	theRPCCall = WSMethodInvocationCreate((CFURLRef)theRPCAppURL, (CFStringRef)methodName, kWSXMLRPCProtocol);
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef) parameters, (CFArrayRef) [NSArray arrayWithObjects:@"optionsStruct",@"URL",nil]);
	// note that in contrast to the previous call, we now include extra HTTP headers
	// along with the xml-rpc call on the following line; this is the cookie
	WSMethodInvocationSetProperty(theRPCCall, (CFStringRef) kWSHTTPExtraHeaders, (CFTypeRef) cookieHeaderDict);
	
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
	
	
	
	// this xml-prc call tells .mac to index the comments
	methodName = @"comment.indexComments";
	parameters = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:iDiskFileURL],@"URL",nil];
	theRPCCall = WSMethodInvocationCreate((CFURLRef)theRPCAppURL, (CFStringRef)methodName, kWSXMLRPCProtocol);
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef)parameters, (CFArrayRef)[NSArray arrayWithObject:@"URL"]);
	WSMethodInvocationSetProperty(theRPCCall, (CFStringRef) kWSHTTPExtraHeaders, (CFTypeRef) cookieHeaderDict);
	
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
	
	
	// this xml-prc call tells .mac to do something else (I'm not exactly sure what this does)
	methodName = @"comment.changeTagForComments";
	parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"iweb",@"appID",dotMacUsername,@"username",nil];
	theRPCCall = WSMethodInvocationCreate((CFURLRef)theRPCAppURL, (CFStringRef)methodName, kWSXMLRPCProtocol);
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef)parameters, (CFArrayRef)[NSArray arrayWithObjects:@"appID",@"username",nil]);
	WSMethodInvocationSetProperty(theRPCCall, (CFStringRef) kWSHTTPExtraHeaders, (CFTypeRef) cookieHeaderDict);
	
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	NSString *someRandomNumber = [result objectForKey:(NSString *)kWSMethodInvocationResult];
	
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
	
	
	
	// this xml-prc call tells .mac to do somethinge even elser! (I'm also not exactly sure what this does)
	methodName = @"comment.commentIdentifiersSinceChangeTag";
	parameters = [NSDictionary dictionaryWithObjectsAndKeys:someRandomNumber,@"someRandomNumber",[NSArray arrayWithObject:iDiskFileURL],@"URL",nil];
	theRPCCall = WSMethodInvocationCreate((CFURLRef)theRPCAppURL, (CFStringRef)methodName, kWSXMLRPCProtocol);
	WSMethodInvocationSetParameters(theRPCCall, (CFDictionaryRef)parameters, (CFArrayRef)[NSArray arrayWithObjects:@"someRandomNumber",@"URL",nil]);
	WSMethodInvocationSetProperty(theRPCCall, (CFStringRef) kWSHTTPExtraHeaders, (CFTypeRef) cookieHeaderDict);
	
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
	
	
	
	// this xml-prc call tells .mac to terminate the session
	methodName = @"comment.terminateSession";
	theRPCCall = WSMethodInvocationCreate((CFURLRef)theRPCAppURL, (CFStringRef)methodName, kWSXMLRPCProtocol);
	WSMethodInvocationSetParameters(theRPCCall, nil, nil);
	WSMethodInvocationSetProperty(theRPCCall, (CFStringRef) kWSHTTPExtraHeaders, (CFTypeRef) cookieHeaderDict);
	
	result = (NSDictionary *)(WSMethodInvocationInvoke(theRPCCall));
	
	if (WSMethodResultIsFault ((CFDictionaryRef) result))
		NSLog(@"%@",[result objectForKey:(NSString *)kWSFaultString]);
	else
		NSLog(@"%@",[result objectForKey: (NSString *) kWSMethodInvocationResult]);
}



// for pages hosted on the homepage.mac.com subdomain, this method creates a
// valid XHTML file that serves as a placeholder for the corresponding location
// in the "Web" folder of the user's iDisk (pages hosted on the homepage.mac.com
// subdomain are stored in the "Sites" folder of a user's iDisk)

// note that the user's iDisk *has to be mounted* for this to work; if the iDisk
// is not mounted, this will silently fail and comments will not be activated

// also note that if local .mac synching is turned on (instead of mounting the
// iDisk as a normal server), then the iDisk must be synched before comments
// will be activated

// finally, the dummy file actually redirects to the appropriate homepage.mac.com
// URL, so even if web users accidentally visit this dummy URL, they will find
// the correct page
- (void)createDummyFile:(NSString *)iDiskFileURL entryPageURL:(NSString *)entryPageURL iDiskUsername:(NSString *)dotMacUsername
{
	NSString *pathToDummyFile = [NSString stringWithFormat:@"/Volumes%@",iDiskFileURL];
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	
	// create the XHTML file contents
	NSString *dummyFileContents = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title></title><meta http-equiv=\"refresh\" content=\"0;url=%@\" /></head><body></body></html>",entryPageURL];
	
	int i;
	NSArray *folderArray = [pathToDummyFile componentsSeparatedByString:@"/"];
	NSLog(@"%@",folderArray);
	
	// the first three components of the path to the dummy file will be "/Users/username/Web/"
	NSString *currentString = [NSString stringWithFormat:@"%@/%@/%@/",[folderArray objectAtIndex:0],[folderArray objectAtIndex:1],[folderArray objectAtIndex:2]];

	// this for loop iterates through the path to the dummy file, creating folders
	// as needed if they are not already created
	for (i = 3; i < [folderArray count] - 1; i++) {
		currentString = [currentString stringByAppendingPathComponent:[folderArray objectAtIndex:i]];
		BOOL isDirectory = NO;
		if ([defaultManager fileExistsAtPath:currentString isDirectory:&isDirectory]) {
			if (! isDirectory) {
				NSBeep();
				return;
			}
		} else {
			[defaultManager createDirectoryAtPath:currentString attributes:nil];
		}
	}
	
	// after all the containing folders have been created, write the dummy
	// XHTML file to disk
	if (! [defaultManager fileExistsAtPath:pathToDummyFile isDirectory:nil]) {
		BOOL fileWriteSuccess = [defaultManager createFileAtPath:pathToDummyFile contents:[dummyFileContents dataUsingEncoding:NSASCIIStringEncoding] attributes:nil];
		if (fileWriteSuccess) {
			NSLog(@"dummy file write success!");
		} else {
			NSLog(@"dummy file write failed. :(");
		}
	}
}


// this method takes a URL from a .mac hosted webpage and transforms it
// to a format that the .mac comment system accepts; note that this is NOT
// the same thing as a file:/// URL, so it's referred to as an
// "iDisk File URL"
- (NSString *)convertURLToiDiskFileURL:(NSString *)theURL
{
	NSString *iDiskFileURL;
	NSString *dotMacUsername = [dotMacUsernameTextField stringValue];
	NSString *entryPageURL = [entryPageURLTextField stringValue];
	NSScanner *URLScanner = [[NSScanner alloc] initWithString:entryPageURL];
	[URLScanner scanUpToString:@"web.mac.com" intoString:nil];
	BOOL validURL = [URLScanner scanString:@"web.mac.com" intoString:nil];
	if (! validURL) {
		[URLScanner setScanLocation:0];
		[URLScanner scanUpToString:@"homepage.mac.com" intoString:nil];
		validURL = [URLScanner scanString:@"homepage.mac.com" intoString:nil];
		if (! validURL) {
			// the URL is neither on the homepage.mac.com or web.mac.com
			// subdomains, so it's an invalid URL for all intents and purposes,
			// because there are no other domains which .mac uses for hosting
			// web pages
			NSBeep();
			return nil;
		}
	}
	
	[URLScanner scanString:@"/" intoString:nil];
	validURL = [URLScanner scanString:dotMacUsername intoString:nil];
	if (! validURL) {
		// check to make sure the URL provided is on the iDisk of the
		// provided username; otherwise, it's treated as an invalid URL
		NSBeep();
		return nil;
	}
	
	[URLScanner scanString:@"/" intoString:nil];
	if ([URLScanner isAtEnd]) {
		// if there's nothing left, then the URL is just referring to the 
		// highest-level URL that could possibly be exposed to the internet
		// on the web.mac.com subdomain: http://web.mac.com/username/index.html
		iDiskFileURL = [NSString stringWithFormat:@"/%@/Web/Sites/index.html",dotMacUsername];
	} else {
		// if there's other stuff left, this is just the last part of the URL
		NSString *terminalURL;
		[URLScanner scanUpToString:@"" intoString:&terminalURL];
		if ([[terminalURL substringFromIndex:[terminalURL length]-1] isEqualToString:@"/"]) {
			// if the URL ends in a slash, automatically add "index.html" to the end;
			iDiskFileURL = [NSString stringWithFormat:@"/%@/Web/Sites/%@index.html",dotMacUsername,terminalURL];
		} else {
			iDiskFileURL = [NSString stringWithFormat:@"/%@/Web/Sites/%@",dotMacUsername,terminalURL];
		}
	}
	[URLScanner release];
	
	return iDiskFileURL;
}


// this method checks to see if a URL from a .mac hosted webpage is from
// the homepage.mac.com domain -- this is important, because it determines
// whether or not to create a dummy file on the iDisk
- (BOOL)isHomepageURL:(NSString *)theURL
{
	NSScanner *URLScanner = [[NSScanner alloc] initWithString:theURL];
	[URLScanner scanUpToString:@"homepage.mac.com" intoString:nil];
	BOOL homepageURL = [URLScanner scanString:@"homepage.mac.com" intoString:nil];
	[URLScanner release];
	return homepageURL;
}


// this method opens up a web browser window for the "Add A Comment" page for
// the provided URL; if this page shows an error when opened, then something
// went wrong with the comment activation (perhaps the iDisk wasn't mounted,
// so the required dummy file wasn't created?)
- (IBAction)visitAddACommentURL:(id)sender
{
	// convert the provided URL to an iDisk File URL
	NSString *iDiskFileURL = [self convertURLToiDiskFileURL:[entryPageURLTextField stringValue]];
	
	NSScanner *scanner = [[NSScanner alloc] initWithString:iDiskFileURL];
	NSString *scannedStringOne;
	NSString *scannedStringTwo;
	[scanner scanString:@"/" intoString:nil];
	[scanner scanUpToString:@"/" intoString:&scannedStringOne];
	[scanner scanString:@"/" intoString:nil];
	[scanner scanString:@"Web/Sites/" intoString:nil];
	[scanner scanUpToString:@"" intoString:&scannedStringTwo];
	[scanner release];
	NSString *modifiediDiskFileURL = [NSString stringWithFormat:@"/%@/%@",scannedStringOne,scannedStringTwo];
	
	// encode the slashes in the argument for the "Add A Comment" page
	NSString *encodedSlashString = [[modifiediDiskFileURL componentsSeparatedByString:@"/"] componentsJoinedByString:@"%2F"];
	NSLog(@"%@",encodedSlashString);
	
	// visit the "Add A Comment" page
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.mac.com/WebObjects/Comments.woa/wa/comment?url=%@",encodedSlashString]]];
}

@end
