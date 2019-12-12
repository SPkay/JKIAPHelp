//
//  JKJailbreakDetectTool.m
//  test
//
//  Created by kane on 2018/8/6.
//  Copyright © 2018年 yangjingkai. All rights reserved.
//

#import "JKJailbreakDetectTool.h"
#import <UIKit/UIKit.h>

#import <sys/stat.h>
#import <dlfcn.h>
#define ARRAY_SIZE(a) sizeof(a)/sizeof(a[0])
@implementation JKJailbreakDetectTool

// 四种检查是否越狱的方法, 只要命中一个, 就说明已经越狱.
+ (BOOL)detectCurrentDeviceIsJailbroken {
    BOOL result =  NO;
    
    result = [self detectJailBreakByJailBreakFileExisted];
    
    if (!result) {
        result = [self detectJailBreakByCydiaPathExisted];
    }
    if (!result) {
        result = [self detectJailBreakByStat];
    }
    
    if (!result) {
        result = [self detectJailBreakByAppPathExisted];
    }
    
    if (!result) {
        result = [self detectJailBreakByEnvironmentExisted];
    }
    
    return result;
}

/**
 * 判定常见的越狱文件
 * /Applications/Cydia.app
 * /Library/MobileSubstrate/MobileSubstrate.dylib
 * /bin/bash
 * /usr/sbin/sshd
 * 这个表可以尽可能的列出来，然后判定是否存在，只要有存在的就可以认为机器是越狱了。
 */
const char* jailbreak_tool_pathes[] = {
    "/Applications/Cydia.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib",
    "/bin/bash",
    "/usr/sbin/sshd",
    "/etc/apt",
};

+ (BOOL)detectJailBreakByJailBreakFileExisted {
    
    for (int i = 0; i<ARRAY_SIZE(jailbreak_tool_pathes); i++) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:jailbreak_tool_pathes[i]]]) {
           
            return YES;
        }
    }
    
    return NO;
}


+ (BOOL)detectJailBreakByStat{
     struct stat stat_info;
    for (int i = 0; i<ARRAY_SIZE(jailbreak_tool_pathes); i++) {
        const char * path =jailbreak_tool_pathes[i];
        
        if (0 == stat(path, &stat_info)) {
            
            return YES;
        }
    }
    
    //可能存在stat也被hook了，可以看stat是不是出自系统库，有没有被攻击者换掉
    //这种情况出现的可能性很小
    int ret;
    Dl_info dylib_info;
    int (*func_stat)(const char *,struct stat *) = stat;
    if ((ret = dladdr(func_stat, &dylib_info))) {
        NSLog(@"lib:%s",dylib_info.dli_fname);      //如果不是系统库，肯定被攻击了
        if (strcmp(dylib_info.dli_fname, "/usr/lib/system/libsystem_kernel.dylib")) {   //不相等，肯定被攻击了，相等为0
         
            return YES;
        }
   }
     return NO;
}

/**
 * 判断cydia的URL scheme.
 * URL scheme是可以用来在应用中呼出另一个应用，这个方法也就是在判定是否存在cydia这个应用。
 */
+ (BOOL)detectJailBreakByCydiaPathExisted {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]) {
     
        return YES;
    }
   
    return NO;
}

/**
 * 读取系统所有应用的名称.
 * 这个是利用不越狱的机器没有这个权限来判定的。
 */
#define USER_APP_PATH                 @"/User/Applications/"
+ (BOOL)detectJailBreakByAppPathExisted {
    if ([[NSFileManager defaultManager] fileExistsAtPath:USER_APP_PATH]) {
      
        NSArray *applist = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:USER_APP_PATH error:nil];
        NSLog(@"applist = %@", applist);
        return YES;
    }
   
    return NO;
}

/**
 * 这个DYLD_INSERT_LIBRARIES环境变量，在非越狱的机器上应该是空，越狱的机器上基本都会有Library/MobileSubstrate/MobileSubstrate.dylib.
 */
char* printEnv(void) {
    char *env = getenv("DYLD_INSERT_LIBRARIES");
    return env;
}

+ (BOOL)detectJailBreakByEnvironmentExisted {
    if (printEnv()) {
 
        return YES;
    }

    return NO;
}
@end
