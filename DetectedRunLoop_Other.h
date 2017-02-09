//
//  DetectedRunLoop_Other.h
//  MOA
//
//  Created by tunsuy on 22/12/16.
//  Copyright © 2016年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DetectedRunLoop_Other : NSObject

+ (instancetype)sharedInstance;

- (void)startDetect;
- (void)stopDetect;

@end
