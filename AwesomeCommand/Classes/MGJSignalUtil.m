//
// Created by Wentong on 16/5/31.
//

#import "MGJSignalUtil.h"
#import "MGJAwesomeCommand.h"
#import "MGJAwesomeResult.h"
#import "MGJAwesomeCancelable.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <pthread/pthread.h>

@interface MGJAwesomeEasyResultImpl : NSObject <MGJAwesomeEasyResult>

@property(readonly, nonnull, strong) id<MGJAwesomeResult> result;

+ (instancetype)resultWithResult:(id<MGJAwesomeResult>)result;

@end

@implementation MGJAwesomeEasyResultImpl

- (instancetype)initWithResult:(nonnull id<MGJAwesomeResult>)result {
    self = [super init];
    if (self) {
        _result = result;
    }

    return self;
}

+ (instancetype)resultWithResult:(nonnull id<MGJAwesomeResult>)result {
    return [[self alloc] initWithResult:result];
}

- (void)onSuccess:(id)data {
    [_result onNext:data];
    [_result onComplete];
}

- (void)onError:(NSError *)error {
    [_result onError:error];
}

@end


@interface MGJAwesomeResultImpl : NSObject <MGJAwesomeResult>

@property(readonly, nonnull, strong) id<RACSubscriber> subscriber;

+ (instancetype)resultWithSubscriber:(nonnull id<RACSubscriber>)subscriber;

@end

@implementation MGJAwesomeResultImpl
- (instancetype)initWithSubscriber:(nonnull id<RACSubscriber>)subscriber {
    self = [super init];
    if (self) {
        _subscriber = subscriber;
    }
    return self;
}

+ (instancetype)resultWithSubscriber:(id<RACSubscriber>)subscriber {
    return [[self alloc] initWithSubscriber:subscriber];
}


- (void)onNext:(id)data {
    [_subscriber sendNext:data];
}

- (void)onComplete {
    [_subscriber sendCompleted];

}

- (void)onError:(NSError *)error {
    [_subscriber sendError:error];
}

- (id<MGJAwesomeEasyResult>)useEasyResult {
    return [MGJAwesomeEasyResultImpl resultWithResult:self];
}

@end


@implementation MGJSignalUtil

+ (RACSignal *)createSignal:(nonnull MGJAwesomeCommand *)command {
    pthread_mutex_t _mutex;
    const int result = pthread_mutex_init(&_mutex, NULL);
    NSCAssert(0 == result, @"Failed to initialize mutex with error %d.", result);
    
    @weakify(command);
    RACSignal *racSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(command);
        if (command && [command respondsToSelector:@selector(run:)]) {
            pthread_mutex_lock(&_mutex);
            
            id<MGJAwesomeResult> result = [MGJAwesomeResultImpl resultWithSubscriber:subscriber];
            [command setValue:@(YES) forKey:@"Executing"];
            id<MGJAwesomeCancelable> cancelable = [command run:result];
            
            pthread_mutex_unlock(&_mutex);
            if (cancelable) {
                return [RACDisposable disposableWithBlock:^{
                    [cancelable cancel];
                }];
            } else {
                return nil;
            }
            
        }
        return nil;
    }];

    return racSignal;

}
@end