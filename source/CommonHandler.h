//
//  CommonHandler.h
//  MOA
//
//  Created by tunsuy on 22/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CommonHandler : NSObject

+ (void)showSlowStackInfo:(NSArray *)slowStacks;
+ (void)showCrashReporter;

@end
