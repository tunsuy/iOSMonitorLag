//
//  DetectedRunLoop_Other.m
//  MOA
//
//  Created by tunsuy on 22/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "DetectedRunLoop_Other.h"
#import "CommonHandler.h"

#define DetectedRunLoop_Other_Detect_Level (16.0f/1000.0f)
#define DetectedRunLoop_Other_Detect_Interval 1.0f

@interface DetectedRunLoop_Other () {
    CFRunLoopObserverRef observer;
    double lastRecordTime;
    NSMutableArray *backtrace;
}
@end

@implementation DetectedRunLoop_Other

static double waitStartTime;

+ (instancetype) sharedInstance{
    static dispatch_once_t once;
    static DetectedRunLoop_Other *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)startDetect {
    [self addMainThreadObserver];
    [self addSecondaryThreadAndObserver];
}

- (void)stopDetect {
    if (!observer) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
    observer = NULL;
}

#pragma mark addMainThreadObserver
- (void) addMainThreadObserver {
    dispatch_async(dispatch_get_main_queue(), ^{
        //建立自动释放池
        @autoreleasepool {
            //获得当前thread的Run loop
            NSRunLoop *myRunLoop = [NSRunLoop currentRunLoop];
            
            //设置Run loop observer的运行环境
            CFRunLoopObserverContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
            
            //创建Run loop observer对象
            //第一个参数用于分配observer对象的内存
            //第二个参数用以设置observer所要关注的事件，详见回调函数myRunLoopObserver中注释
            //第三个参数用于标识该observer是在第一次进入run loop时执行还是每次进入run loop处理时均执行
            //第四个参数用于设置该observer的优先级
            //第五个参数用于设置该observer的回调函数
            //第六个参数用于设置该observer的运行环境
            observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, &myRunLoopObserver, &context);
            
            if (observer) {
                //将Cocoa的NSRunLoop类型转换成Core Foundation的CFRunLoopRef类型
                CFRunLoopRef cfRunLoop = [myRunLoop getCFRunLoop];
                //将新建的observer加入到当前thread的run loop
                CFRunLoopAddObserver(cfRunLoop, observer, kCFRunLoopDefaultMode);
            }
        }
    });
}

//runloop状态回调函数
//每次小循环都会记录一下kCFRunLoopAfterWaiting的时间_waitStartTime，并且在kCFRunLoopBeforeWaiting制空。
void myRunLoopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    switch (activity) {

        case kCFRunLoopBeforeWaiting:{
            waitStartTime = 0;
            NSLog(@"run loop before waiting");
            break;
        }

        case kCFRunLoopAfterWaiting:{
            waitStartTime = [[NSDate date] timeIntervalSince1970];
            NSLog(@"run loop after waiting");
            break;
        }

        default:
            break;
    }
}

#pragma mark addSecondaryThreadAndObserver
- (void) addSecondaryThreadAndObserver{
    NSThread *thread = [self secondaryThread];
    [self performSelector:@selector(addSecondaryTimer) onThread:thread withObject:nil waitUntilDone:YES];
}

- (NSThread *)secondaryThread {
    static NSThread *_secondaryThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _secondaryThread =
        [[NSThread alloc] initWithTarget:self
                                selector:@selector(networkRequestThreadEntryPoint:)
                                  object:nil];
        [_secondaryThread start];
    });
    return _secondaryThread;
}

- (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"monitorControllerThread"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSRunLoopCommonModes];
        [runLoop run];
    }
}

- (void) addSecondaryTimer{
    NSTimer *myTimer = [NSTimer timerWithTimeInterval:DetectedRunLoop_Other_Detect_Interval target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:myTimer forMode:NSDefaultRunLoopMode];
}

- (void)timerFired:(NSTimer *)timer{
    double currentTime = [[NSDate date] timeIntervalSince1970];
    double timeDiff = currentTime - waitStartTime;
    
    //如果当前时长与_waitStartTime差距大于2秒
    if (timeDiff > DetectedRunLoop_Other_Detect_Level){
        if (lastRecordTime - waitStartTime < 0.001 && lastRecordTime != 0){
            NSLog(@"last time no :%f %f",timeDiff, waitStartTime);
            return;
        }
        
        //显示堆栈信息
        NSArray *slowStack = [NSThread callStackSymbols];
        [CommonHandler showSlowStackInfo:slowStack];
//        [CommonHandler showCrashReporter];
        
        lastRecordTime = waitStartTime;
    }
}

@end
