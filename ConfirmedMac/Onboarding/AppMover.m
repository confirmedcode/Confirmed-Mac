
#import "AppMover.h"

#define kAppMoverCloseIfOpen @"ConfirmedAppMoverCloseIfOpen"
#define kAppMoverSameServiceIsOpen @"ConfirmedSameVersionIsOpened"


bool MoveConfirmedToApplicationsFolder(void);

int modalAlert(NSString *title, NSString *info, NSAlertStyle style, NSString *firstButtonTitle, NSString *secondButtonTitle)
{
    NSAlert* alert = [[NSAlert alloc] init];
    
    [alert setMessageText:title];
    [alert setInformativeText:info];
    if (firstButtonTitle) [alert addButtonWithTitle:firstButtonTitle];
    if (secondButtonTitle) [alert addButtonWithTitle:secondButtonTitle];
    [alert setAlertStyle:style];
    
    return [alert runModal];
}

static BOOL AuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL *canceled) {
    if (canceled) *canceled = NO;
    
    // Make sure that the destination path is an app bundle. We're essentially running 'sudo rm -rf'
    // so we really don't want to fuck this up.
    if (![[dstPath pathExtension] isEqualToString:@"app"]) return NO;
    
    // Do some more checks
    if ([[dstPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;
    if ([[srcPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) return NO;
    
    int pid, status;
    AuthorizationRef myAuthorizationRef;
    
    // Get the authorization
    OSStatus err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
    if (err != errAuthorizationSuccess) return NO;
    
    AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights myRights = {1, &myItems};
    AuthorizationFlags myFlags = (AuthorizationFlags)(kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize);
    
    err = AuthorizationCopyRights(myAuthorizationRef, &myRights, NULL, myFlags, NULL);
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled && canceled)
            *canceled = YES;
        goto fail;
    }
    
    static OSStatus (*security_AuthorizationExecuteWithPrivileges)(AuthorizationRef authorization, const char *pathToTool,
                                                                   AuthorizationFlags options, char * const *arguments,
                                                                   FILE **communicationsPipe) = NULL;
    if (!security_AuthorizationExecuteWithPrivileges) {
        // On 10.7, AuthorizationExecuteWithPrivileges is deprecated. We want to still use it since there's no
        // good alternative (without requiring code signing). We'll look up the function through dyld and fail
        // if it is no longer accessible. If Apple removes the function entirely this will fail gracefully. If
        // they keep the function and throw some sort of exception, this won't fail gracefully, but that's a
        // risk we'll have to take for now.
        security_AuthorizationExecuteWithPrivileges = (OSStatus (*)(AuthorizationRef, const char*,
                                                                    AuthorizationFlags, char* const*,
                                                                    FILE **)) dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
    }
    if (!security_AuthorizationExecuteWithPrivileges) goto fail;
    
    // Delete the destination
    {
        char *args[] = {"-rf", (char *)[dstPath fileSystemRepresentation], NULL};
        err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/rm", kAuthorizationFlagDefaults, args, NULL);
        if (err != errAuthorizationSuccess) goto fail;
        
        // Wait until it's done
        pid = wait(&status);
        if (pid == -1 || !WIFEXITED(status)) goto fail; // We don't care about exit status as the destination most likely does not exist
    }
    
    NSLog(@"Copying");
    // Copy
    {
        char *args[] = {"-pR", (char *)[srcPath fileSystemRepresentation], (char *)[dstPath fileSystemRepresentation], NULL};
        err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, args, NULL);
        if (err != errAuthorizationSuccess) goto fail;
        
        // Wait until it's done
        pid = wait(&status);
        if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;
    }
    
    NSLog(@"Xattr");
    
    // xattr
    {
        char *args[] = {"-d", "-r", "com.apple.quarantine", (char *)[dstPath fileSystemRepresentation], NULL};
        err = security_AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/usr/bin/xattr", kAuthorizationFlagDefaults, args, NULL);
        if (err != errAuthorizationSuccess) goto fail;
        
        // Wait until it's done
        pid = wait(&status);
        if (pid == -1 || !WIFEXITED(status) || WEXITSTATUS(status)) goto fail;
    }
    
    NSLog(@"DONE");
    
    AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
    return YES;
    
fail:
    AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
    return NO;
}

void RelaunchConfirmed(NSString *desiredLocation) {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSLog(@"relaunching app %d", pid);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kAppMoverCloseIfOpen object:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       
                       int instancesRunning = 0;
                       NSDate *startDate = [NSDate date];
                       do {
                           [NSThread sleepForTimeInterval:0.1];
                           instancesRunning = 0;
                           NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
                           NSArray *oldApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"confirmed.tunnels"];
                           apps = [apps arrayByAddingObjectsFromArray:oldApps];
                           for (NSRunningApplication *app in apps) {
                               if ([app processIdentifier] != [[NSRunningApplication currentApplication] processIdentifier])
                                   instancesRunning++;
                           }
                           
                       } while (instancesRunning > 0 && fabs([startDate timeIntervalSinceNow]) < 5);
                       
                       
                       //[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
                       NSString *preOpenCmd = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine %@", desiredLocation];
                       NSString *preOpenEncoded = [NSString stringWithFormat:@"/usr/bin/xattr -d -r com.apple.quarantine %@", @"/Applications/Confirmed\\ VPN.app"];

                       NSString *script = [NSString stringWithFormat:@"/bin/sleep 0.3; %@; %@; /usr/bin/open %@", preOpenCmd, preOpenEncoded, [desiredLocation stringByReplacingOccurrencesOfString:@" " withString:@"\\ "]];
                       
                       NSLog(@"Script %@", script);
                       
                       [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", script, nil]];
                       
                       [NSApp terminate:nil];
                       exit(0);
                   });
}

bool requestAuthorizedInstall(NSString *srcPath, NSString *dstPath, BOOL skipAuth) {
    BOOL canceled;
    NSInteger option = NSAlertFirstButtonReturn;
    
    if (!skipAuth) {
        option = modalAlert(@"Confirmed is not in your Applications Folder", @"Please authorize Confirmed to move to Applications to work properly.", NSInformationalAlertStyle, @"Authorize & Move", @"Quit");

    }
    if (option == NSAlertFirstButtonReturn) {
        //move app as admin
        return AuthorizedInstall(srcPath, dstPath, &canceled);
    }
    else {
        return false;
    }
}

void MoveConfirmed(NSString *bundle, NSString *desiredLocation, BOOL skipAuth) {
    NSError *error = nil;
    NSFileManager *nsfm = [NSFileManager defaultManager];
    
    if ([nsfm fileExistsAtPath:desiredLocation]) {
        //try to remove item
        [nsfm removeItemAtPath:desiredLocation error:&error];
        
        if (error) {
            //if couldn't remove, authorize
            NSLog(@"Copy Error 1 %@", error);
            requestAuthorizedInstall(bundle, desiredLocation, skipAuth);
        }
        else {
            //if could remove, try to copy, otherwise authorize
            [nsfm copyItemAtPath:bundle toPath:desiredLocation error:&error];
            NSLog(@"Copy Error 2 %@", error);
            if (error) {
                requestAuthorizedInstall(bundle, desiredLocation, skipAuth);
            }
        }
    }
    else {
        [nsfm copyItemAtPath:bundle toPath:desiredLocation error:&error];
        NSLog(@"Copy Error 3 %@", error);
        if (error) {
            requestAuthorizedInstall(bundle, desiredLocation, skipAuth);
        }
    }
        
    RelaunchConfirmed(desiredLocation);
    
}

bool IsConfirmedOpen() {
    BOOL isAppOpen = NO;
    NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    NSArray *oldApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"confirmed.tunnels"];
    apps = [apps arrayByAddingObjectsFromArray:oldApps];
    for (NSRunningApplication *app in apps) {
        if ([app processIdentifier] != [[NSRunningApplication currentApplication] processIdentifier])
            isAppOpen = YES;
    }
    
    return isAppOpen;
}

void killOtherConfirmeds() {
    NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    for (NSRunningApplication *app in apps) {
        if ([app processIdentifier] != [[NSRunningApplication currentApplication] processIdentifier])
            [app terminate];
    }
}

void ReplaceConfirmed(NSString *bundle, NSString *desiredLocation, BOOL skipAuth) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kAppMoverCloseIfOpen object:nil];
    killOtherConfirmeds();
    
    //now replace
    MoveConfirmed(bundle, desiredLocation, skipAuth);
    
}

void MoveConfirmedIfNecessary(NSString *bundle, NSString *desiredLocation) {
    NSString *myVersion = [NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    NSString *replaceVersion = [NSString stringWithFormat:@"%@",[[NSBundle bundleWithPath:desiredLocation] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
    id <SUVersionComparison> comparator = [SUStandardVersionComparator defaultComparator];
    NSInteger result = [comparator compareVersion:myVersion toVersion:replaceVersion];
    if (result == NSOrderedSame) {
        if (IsConfirmedOpen()) {
            //open panel
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName: kAppMoverSameServiceIsOpen object:nil userInfo:nil deliverImmediately:true];
            [NSApp terminate:nil];
        }
        else {
            //open the app
            RelaunchConfirmed(desiredLocation);
        }
    }
    else {
        
        NSUInteger option;
        if (result == NSOrderedAscending) {
            option = modalAlert(@"You Have A Newer Confirmed VPN App Installed", @"You have already installed a newer Confirmed version in the Applications folder. If you would like to use the older version, click 'Downgrade' or cancel to keep the current version.", NSInformationalAlertStyle, @"Downgrade", @"Quit");
        }
        else {
            option = modalAlert(@"Do You Want to Upgrade Confirmed VPN?", @"You have an older version of Confirmed in the Applications folder. \n\nIf you would like to use the newer version, click 'Authorize & Upgrade' (you will need to provide your admin password). \n\nOtherwise, please select 'Use Older App' to use the outdated version currently in Applications.", NSInformationalAlertStyle, @"Authorize & Upgrade", @"Use Older App");
        }
        
        if (NSAlertFirstButtonReturn == option){
            ReplaceConfirmed(bundle, desiredLocation, YES);
        }
        else {
            //launch the other app
            if (IsConfirmedOpen()) {
                //open panel
                [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kAppMoverSameServiceIsOpen object:nil userInfo:nil deliverImmediately:true];
                [NSApp terminate:nil];
            }
            else {
                //open the app
                RelaunchConfirmed(desiredLocation);
            }
        }
        
    }
}



bool MoveToApplicationsFolder(void) {
	// Skip if user suppressed the alert before
	// Path of the bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *destinationBundleName = @"Confirmed VPN.app";
    NSString *applicationsDirectory = @"/Applications/";
    NSString *desiredLocation = [applicationsDirectory stringByAppendingPathComponent:destinationBundleName];
    
    //if not in /Applications, let's move
    
    
    NSLog(@"Location %@", desiredLocation);
    if ([bundlePath caseInsensitiveCompare:desiredLocation] != NSOrderedSame) {
        if (![NSApp isActive]) {
            [NSApp activateIgnoringOtherApps:YES];
        }
        
        NSFileManager *nsfm = [NSFileManager defaultManager];
        
        BOOL isDir;
        //if it exists, prompt to move
        if ([nsfm fileExistsAtPath:desiredLocation isDirectory:&isDir]) {
            MoveConfirmedIfNecessary(bundlePath, desiredLocation);
        }
        else {
            //there's nothing here, just copy in
            MoveConfirmed(bundlePath, desiredLocation, NO);
        }
        
        return YES;
    }
    else {
        return NO;
    }
    
    return NO;
}

