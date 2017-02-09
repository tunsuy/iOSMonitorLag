//
//  DetectedRunLoop.m
//  MOA
//
//  Created by tunsuy on 22/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "DetectedRunLoop.h"
#import "CommonHandler.h"

#define DetectedRunLoop_Detect_Level (16.0f/1000.0f)

@interface DetectedRunLoop () {
    int timeoutCount;
    CFRunLoopObserverRef observer;
    
    @public
    dispatch_semaphore_t semaphore;
    CFRunLoopActivity activity;
}
@end

@implementation DetectedRunLoop

+ (instancetype)sharedInstance {
    static DetectedRunLoop *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

//runloop状态回调函数
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    DetectedRunLoop *object = (__bridge DetectedRunLoop*)info;
    
    // 记录状态值
    object->activity = activity;
    
    // 发送信号
    dispatch_semaphore_t semaphore = object->semaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)startDetect {
    if (observer) {
        return;
    }
    
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                       kCFRunLoopAllActivities,
                                       YES,
                                       0,
                                       &runLoopObserverCallBack,
                                       &context);
    //将观察者添加到主线程runloop的common模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    
    // 创建信号
    semaphore = dispatch_semaphore_create(0);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES)
        {
            // 假定连续5次超时stackTime则认为卡顿
            int64_t stackTime = DetectedRunLoop_Detect_Level * NSEC_PER_SEC;
            long st = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, stackTime));
            if (st != 0)
            {
                if (!observer) {
                    timeoutCount = 0;
                    activity = 0;
                    semaphore = 0;
                    return ;
                }
                
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够检测到是否卡顿
                if (activity==kCFRunLoopBeforeSources || activity==kCFRunLoopAfterWaiting)
                {
                    if (++timeoutCount < 5)
                        continue;
                    
                    //显示slow stack 信息
                    NSArray *callStack = [NSThread callStackSymbols];
                    [CommonHandler showSlowStackInfo:callStack];
//                    [CommonHandler showCrashReporter];
                    
                    //PS: 可以利用PLCrashReporter开源库显示出具体的代码行
                    //http://blog.devzeng.com/blog/ios-plcrashreporter.html
                }
            }
            timeoutCount = 0;
        }
    });
}

- (void)stopDetect {
    if (!observer) {
        return;
    }
    
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
    observer = NULL;
}

@end
