/*
 launchdialog.m - iOS lauch dialog
 Copyright (C) 2016 mittorn
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FtpServer.h"

@interface XashPromptAlertViewDelegate : NSObject <UIAlertViewDelegate>

@property (nonatomic, assign) int *button;

@end

@implementation XashPromptAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	*_button = buttonIndex;
}
@end

void runEvents()
{
	
}

extern int g_iArgc;
extern char **g_pszArgv;
char *g_szLibrarySuffix;


const char *IOS_GetDocsDir()
{
	static const char *dir = NULL;
	
	if( dir )
		return dir;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirctory = [paths objectAtIndex:0];
	[[NSFileManager defaultManager] createDirectoryAtPath:documentsDirctory withIntermediateDirectories:NO attributes:nil error:nil];
	
	dir = [documentsDirctory fileSystemRepresentation];
	
	return dir;
}

UIBackgroundTaskIdentifier task;
FtpServer *server = NULL;

void IOS_StartBackgroundTask()
{
	if( !server ) return;

	if( task != UIBackgroundTaskInvalid )
		return;

	UIApplication*    app = [UIApplication sharedApplication];
	
	task = [app beginBackgroundTaskWithExpirationHandler:^{
		[app endBackgroundTask:task];
		task = UIBackgroundTaskInvalid;
	}];
	
	// Start the long-running task and return immediately.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		UIBackgroundTaskIdentifier local = task;

		// do not keep "zombie" tasks
		while( 1 )
			sleep(1);
	
		[app endBackgroundTask:local];
		task = UIBackgroundTaskInvalid;
	});
}

#define SETTINGS_MAGIC 111

typedef struct settings_s
{
	unsigned char magic;
	char args[1024];
	unsigned int port;
	char suffix[32];
	unsigned int ftpserver;
} settings_t;

void IOS_LaunchDialog( void )
{
	int button = -1, bExit, bStart;
	UIAlertView * alert = [[UIAlertView alloc] init];
	bExit = [alert addButtonWithTitle:@"Exit"];
	bStart = [alert addButtonWithTitle:@"Start"];
	XashPromptAlertViewDelegate *delegate = [[XashPromptAlertViewDelegate alloc] init];
	delegate.button = &button;
	
	alert.delegate = delegate;

	const char *docsDir = IOS_GetDocsDir();
	
	FILE *settingsfile;
	char settingspath[256];
	snprintf(settingspath, sizeof(settingspath), "%s/settings.bin", docsDir );
	settingspath[255] = 0;
	settings_t settings;

	[alert setTransform:CGAffineTransformMakeTranslation(0,109)];

	UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];

	UISwitch *ftpswitch = [[UISwitch alloc] initWithFrame:CGRectMake(210,60,80,30)];

	UILabel *argstitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 30)];
	[argstitle setText:@"Command-line arguments:"];

	UITextField *args = [[UITextField alloc] initWithFrame:CGRectMake(0, 30, 300, 30)];
	[args setBackgroundColor:[[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:1]];

	UILabel *ftptitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, 200, 30)];
	[ftptitle setText:@"FTP Server"];


	UITextField *port = [[UITextField alloc] initWithFrame:CGRectMake(110, 60, 100, 30)];
	
	UITextField *suffix = [[UITextField alloc] initWithFrame:CGRectMake(140, 90, 160, 30 )];
	[suffix setBackgroundColor:[[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:1]];

	UILabel *suffixtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 90, 140, 30)];
	[suffixtitle setText:@"Library suffix"];

	[scroll addSubview:argstitle];
	[scroll addSubview:args];
	[scroll addSubview:suffix];
	[scroll addSubview:ftpswitch];
	[scroll addSubview:ftptitle];
	[scroll addSubview:port];
	[scroll addSubview:suffixtitle];

	settingsfile = fopen( settingspath, "rb" );
	if( settingsfile && ( fread(&settings, sizeof( settings ), 1, settingsfile ) == 1 ) && ( settings.magic == SETTINGS_MAGIC ) )
	{
		settings.args[1023] = 0;
		settings.suffix[31] = 0;
		[args setText:@(settings.args)];
		[port setText:[NSString stringWithFormat:@"%u", settings.port]];
		[suffix setText:@(settings.suffix)];
		ftpswitch.on = settings.ftpserver;
	}
	else
	{
		[args setText:@"-dev 3 -log"];
		[port setText:@"21135"];
	}

	scroll.contentSize=CGSizeMake(250, 200);
	[alert setValue:scroll forKey:@"accessoryView"];

	[alert show];

	@autoreleasepool {
		while( button == -1 ) {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
		}
	}

	if( (settingsfile = fopen( settingspath, "wb" )) )
	{
		settings.ftpserver = ftpswitch.on;
		strlcpy(settings.args, [args.text UTF8String], 1024);
		strlcpy(settings.suffix, [suffix.text UTF8String], 32 );
		settings.port = [port.text intValue];
		settings.magic = 111;
	
		fwrite(&settings, sizeof(settings), 1, settingsfile);
		fclose(settingsfile);
	}
	if( button == bExit )
	{
		printf("Exit selected\n");
		exit(0);
	}

	if( ftpswitch.on )
	{

		button = -1;

		[[[UIAlertView alloc] initWithTitle:@"Xash3D" message:[NSString stringWithFormat:@"Started FTP server on port %@", port.text] delegate:delegate cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
	
		server = [[ FtpServer alloc ] initWithPort:[port.text integerValue] withDir:@(docsDir) notifyObject:nil ];

		IOS_StartBackgroundTask();

		@autoreleasepool {
			while( button == -1 ) {
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
				IOS_StartBackgroundTask(); // keep running
			}
		}
	}

	NSArray *argv = [ args.text componentsSeparatedByString:@" " ];
	
	int count = [argv count];
	char *arg1 = g_pszArgv[0];
	g_pszArgv = calloc( count + 2, sizeof( char* ) );
	int i;
	g_pszArgv[0] = arg1;
	for( i = 0; i<count; i++ )
	{
		g_pszArgv[i + 1] = strdup( [argv[i] UTF8String] );
	}
	g_iArgc = count + 1;
	g_pszArgv[count + 1] = 0;

	if( [suffix.text length] )
		g_szLibrarySuffix = strdup([suffix.text UTF8String]);

	alert.delegate = nil;

	[ftpswitch release];
	[ftptitle release];
	[args release];
	[argstitle release];
	[port release];
	[suffix release];
	[suffixtitle release];

	[alert release];
}

char *IOS_GetUDID( void )
{
	static char udid[256];
	NSString *id = [[[UIDevice currentDevice]identifierForVendor] UUIDString];
	strncpy( udid, [id UTF8String], 255 );
	[id release];
	return udid;
}