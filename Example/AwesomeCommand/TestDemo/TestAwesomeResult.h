//
//  TestAwesomeResult.h
//  AwesomeCommand
//
//  Created by Senmiao on 16/8/15.
//  Copyright © 2016年 wentong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AwesomeCommand/AwesomeResult.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
@interface TestAwesomeResult : NSObject<AwesomeResult>
+ (instancetype)resultWithSubscriber:(id<RACSubscriber>)subscriber;
- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber;
@end
