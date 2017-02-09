//
//  PMainThreadWatcher.h
//  MOA
//
//  Created by tunsuy on 21/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PMainThreadWatcherDelegate <NSObject>

- (void)onMainThreadSlowStackDetected:(NSArray *)slowStacks;

@end

@interface PMainThreadWatcher : NSObject

@property (nonatomic, weak) id<PMainThreadWatcherDelegate> delegate;

+ (instancetype)sharedInstance;

- (void)startWatch;

@end
