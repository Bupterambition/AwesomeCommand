//
//  ThirdCommand.m
//  AwesomeCommand
//
//  Created by  on 16/8/15.
//  Copyright © 2016年 . All rights reserved.
//

#import "ThirdCommand.h"
#import <AwesomeCommand/AwesomeCommandPublicHeader.h>

@implementation ThirdCommand
- (id<AwesomeCancelable>)run:(id<AwesomeResult>)result {
    NSLog(@"开始执行 Command 3");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [result onNext:nil];
        [result onComplete];
    });
    NSOperation *disposeOperation = [NSOperation new];
    return [[BlockCancelable alloc] initWithBlock:^{
        //something to compose
        //Example
        [disposeOperation cancel];
    }];
}
@end
