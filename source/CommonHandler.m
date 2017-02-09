//
//  CommonHandler.m
//  MOA
//
//  Created by tunsuy on 22/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "CommonHandler.h"
#import <CrashReporter/CrashReporter.h>

@implementation CommonHandler

+ (void)showSlowStackInfo:(NSArray *)slowStacks {
    NSMutableArray *info = [NSMutableArray array];
    
    for (NSString* call in slowStacks) {
        NSLog(@"slow call stack: %@\n", call);
        [info addObject:call];
    }
    //UI提示
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"出现卡顿"
                                                        message:[NSString stringWithFormat:@"%@", info]
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"确定", nil];
    [alertView show];
}

+ (void)showCrashReporter {
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD
                                                                       symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
    PLCrashReporter *crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];
    
    NSData *data = [crashReporter generateLiveReport];
    PLCrashReport *reporter = [[PLCrashReport alloc] initWithData:data error:NULL];
    NSString *report = [PLCrashReportTextFormatter stringValueForCrashReport:reporter
                                                              withTextFormat:PLCrashReportTextFormatiOS];
    
    //UI提示
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"出现卡顿"
                                                        message:[NSString stringWithFormat:@"%@", report]
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"确定", nil];
    [alertView show];
}

@end
