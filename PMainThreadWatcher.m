//
//  PMainThreadWatcher.m
//  MOA
//
//  Created by tunsuy on 21/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import "PMainThreadWatcher.h"
#import "CommonHandler.h"

#define PMainThreadWatcher_Watch_Interval 1.0f
#define PMainThreadWatcher_Watch_Level (16.0f/1000.0f)

#define Notification_PMainThreadWatcher_Worker_Ping @"Notification_PMainThreadWatcher_Worker_Ping"
#define Notification_PMainThreadWatcher_Main_Pong @"Notification_PMainThreadWatcher_Main_Pong"

//使用了unix下信号机制
//SIGUSR1: 表示留给用户使用
#define CALLSTACK_SIG SIGUSR1
static pthread_t mainThreadID;

#include <signal.h>
#include <pthread.h>

#include <libkern/OSAtomic.h>
#include <execinfo.h>

//信号处理函数
static void thread_singal_handler(int sig)
{
    NSLog(@"main thread catch signal: %d", sig);
    
    if (sig != CALLSTACK_SIG) {
        return;
    }
    
    NSArray* callStack = [NSThread callStackSymbols];
    
    id<PMainThreadWatcherDelegate> del = [PMainThreadWatcher sharedInstance].delegate;
    if (del != nil && [del respondsToSelector:@selector(onMainThreadSlowStackDetected:)]) {
        [del onMainThreadSlowStackDetected:callStack];
    }
    else
    {
        NSLog(@"detect slow call stack on main thread! \n");
        //显示堆栈信息
        [CommonHandler showSlowStackInfo:callStack];
//        [CommonHandler showCrashReporter];
    }
    
    return;
}

//设置信号及其对应的处理函数
static void install_signal_handler()
{
    signal(CALLSTACK_SIG, thread_singal_handler);
}

static void printMainThreadCallStack()
{
    NSLog(@"sending signal: %d to main thread", CALLSTACK_SIG);
    //向主线程发送信号
    pthread_kill(mainThreadID, CALLSTACK_SIG);
}


dispatch_source_t createGCDTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, interval), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}

@interface PMainThreadWatcher ()

@property (nonatomic, strong) dispatch_source_t pingTimer;
@property (nonatomic, strong) dispatch_source_t pongTimer;

@end

@implementation PMainThreadWatcher

+ (instancetype)sharedInstance {
    static PMainThreadWatcher *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PMainThreadWatcher alloc] init];
    });
    return instance;
}

- (void)startWatch {
    if ([NSThread isMainThread] == false) {
        NSLog(@"startWatch must is called on the mainThread");
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectedPingFromWorkerThread) name:Notification_PMainThreadWatcher_Worker_Ping object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectedPongFromMainThread) name:Notification_PMainThreadWatcher_Main_Pong object:nil];
    
    install_signal_handler();
    
    mainThreadID = pthread_self();
    
    uint64_t interval = PMainThreadWatcher_Watch_Interval * NSEC_PER_SEC;
    self.pingTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        [self pingMainThread];
    });
}

- (void)pingMainThread
{
    uint64_t interval = PMainThreadWatcher_Watch_Level * NSEC_PER_SEC;
    self.pongTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self onPongTimeout];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_PMainThreadWatcher_Worker_Ping object:nil];
    });
}

- (void)onPongTimeout {
    [self cancelPongTimer];
    printMainThreadCallStack();
}

- (void)detectedPingFromWorkerThread {
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_PMainThreadWatcher_Main_Pong object:nil];
}

- (void)detectedPongFromMainThread {
    [self cancelPongTimer];
}

- (void)cancelPongTimer {
    if (self.pongTimer) {
        dispatch_source_cancel(_pongTimer);
        _pongTimer = nil;
    }
}

@end
