//
//  FirstCommand.m
//  kZMoonCommand
//
//  Created by BupterAmbition on 16/8/15.
//  Copyright © 2016年 . All rights reserved.
//

#import "FirstCommand.h"
#import <kZMoonCommand/kZMoonCommandPublicHeader.h>
@implementation FirstCommand
@synthesize excuteQueue = _excuteQueue;
- (instancetype)init {
    self = [super init];
    if (self) {
        _excuteQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}


- (id<kZMoonCancelable>)run:(id<kZMoonResult>)result {
    NSLog(@"开始执行 Command 1");
    [result onNext:@"1"];
    [result onComplete];
    NSOperation *disposeOperation = [NSOperation new];
    return [[BlockCancelable alloc] initWithBlock:^{
        //something to compose
        //Example
        [disposeOperation cancel];
    }];
}

@end
