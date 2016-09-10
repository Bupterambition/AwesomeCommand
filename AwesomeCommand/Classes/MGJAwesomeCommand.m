//
// Created by Wentong on 16/5/31.
//

#import "MGJAwesomeCommand.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "MGJSignalUtil.h"
#import "MGJAwesomeResult.h"
#import "MGJAwesomeCallback.h"
#import "MGJBlockCancelable.h"
#import "MGJAwesomeCommandPublicDefine.h"

@interface MGJAwesomeCommand ()

@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) dispatch_queue_t excuteQueue;

@property (nonatomic, strong) dispatch_queue_t userDefineExecQueue;

@property (nonatomic, strong) RACScheduler *callbackScheduler;
@property (nonatomic, strong) RACScheduler *excuteScheduler;
@property (nonatomic, strong) RACSignal *executionSignals;
@property (nonatomic, strong) RACSubject *addedExecutionSignalsSubject;
@property (nonatomic, assign) BOOL executing;
@property (nonatomic, strong) id<MGJAwesomeCancelable> cancelable;

- (NSString *)getExecuteSchedulerName;
- (NSString *)getCallbackSchedulerName;
- (id<MGJAwesomeCancelable>)_executeWithCallback:(id<MGJAwesomeCallback>)callback andBlock:(MGJAwesomeExcuteCallbaclBlock)callbackBlock;

@end

@implementation MGJAwesomeCommand

@synthesize userDefineExecQueue = _userDefineExecQueue;
@synthesize executing = _executing;
@synthesize executionSignals = _executionSignals;
@synthesize addedExecutionSignalsSubject = _addedExecutionSignalsSubject;
#pragma mark - @protocol MGJAwesomecommandProtocol
@synthesize callbackQueue = _callbackQueue;
@synthesize excuteQueue = _excuteQueue;
@synthesize excuteBlock = _excuteBlock;

#pragma mark - Init Method
- (void)dealloc {
    [self cancel];
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

#pragma mark - @protocol MGJAwesomeExecutable
- (id<MGJAwesomeCancelable>)executeWithCallback:(id<MGJAwesomeCallback>)callback {
    return [self _executeWithCallback:callback andBlock:nil];
}

- (id<MGJAwesomeCancelable>)executeWithBlock:(MGJAwesomeExcuteCallbaclBlock)callbackBlock {
    return [self _executeWithCallback:nil andBlock:callbackBlock];
}

- (id<MGJAwesomeCancelable>)_executeWithCallback:(id<MGJAwesomeCallback>)callback andBlock:(MGJAwesomeExcuteCallbaclBlock)callbackBlock NS_REQUIRES_SUPER {
    if (callback) {
        NSCParameterAssert([callback conformsToProtocol:@protocol(MGJAwesomeCallback)]);
    }
    
    [self createSignal];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wincompatible-pointer-types"
    RACMulticastConnection *subjecConnect = [self.addedExecutionSignalsSubject publish];
    RACMulticastConnection *connection = [self.executionSignals multicast:subjecConnect.signal];
    #pragma clang diagnostic pop
    @weakify(self, callback);
    RACCompoundDisposable *composable = [RACCompoundDisposable compoundDisposable];
    RACDisposable *subjectDisposable = [[[subjecConnect.signal subscribeOn:self.excuteScheduler] deliverOn:self.callbackScheduler] subscribeNext:^(id x) {
        @strongify(self, callback);
        [callback onNext:self AndData:x];
        MGJSafeExecBlock(callbackBlock)(self, x, nil, NO);
        [self->_addedExecutionSignalsSubject sendNext:x];
    } error:^(NSError *error) {
        @strongify(self, callback);
        [self setExecuting:NO];
        [callback onError:self AndError:error];
        MGJSafeExecBlock(callbackBlock)(self, nil, error, NO);
        [self->_addedExecutionSignalsSubject sendError:error];
    } completed:^{
        @strongify(self, callback);
        [self setExecuting:NO];
        [callback onComplete:self];
        MGJSafeExecBlock(callbackBlock)(self, nil, nil, YES);
        [self->_addedExecutionSignalsSubject sendCompleted];
    }];
    RACDisposable *connectDisposable = [connection connect];
    [composable addDisposable:connectDisposable];
    [composable addDisposable:subjectDisposable];
    @weakify(composable);
    self.cancelable = [[MGJBlockCancelable alloc] initWithBlock:^{
        @strongify(composable, self);
        [self setExecuting:NO];
        [composable dispose];
    }];
    
    return self.cancelable;
}

#pragma mark - @protocol MGJSignalable
- (RACSignal *)createSignal {
    if (!_executionSignals) {
        _executionSignals = [[[MGJSignalUtil createSignal:self] subscribeOn:self.excuteScheduler] deliverOn:self.callbackScheduler];
    }
    return _executionSignals;
}

- (void)subject:(RACSubject *)subject {
    NSParameterAssert([subject isKindOfClass:[RACSubject class]]);
    if (!self.executing) {
        _addedExecutionSignalsSubject = subject;
    } else {
#if DEBUG
        NSCAssert(0, @"Not allow!");
#endif
    }
}

#pragma mark - @protocol MGJAwesomeAsyncRunnable
// 不应主动去调用
- (id<MGJAwesomeCancelable>)run:(id<MGJAwesomeResult>)result {
    id<MGJAwesomeCancelable> disposeOperation = nil;
    if (self.excuteBlock) {
        disposeOperation = self.excuteBlock(result);
    }
    return [[MGJBlockCancelable alloc] initWithBlock:^{
        //something to compose
        //Example
        [disposeOperation cancel];
    }];
}

#pragma mark - @protocol MGJAwesomeCancelable
- (void)cancel {
    if (self.cancelable) {
        [self.cancelable cancel];
        self.cancelable = nil;
    }
}

#pragma mark - Accessor
- (void)setExecuting:(BOOL)executing {
    @synchronized (self) {
        _executing = executing;
    }
}

- (dispatch_queue_t)callbackQueue {
    if ([NSThread isMainThread]) {
        _callbackQueue = dispatch_get_main_queue();
    } else {
        _callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    return _callbackQueue;
}

- (void)setCallbackQueue:(dispatch_queue_t)callbackQueue {
    if (_callbackQueue != callbackQueue) {
        _callbackQueue = callbackQueue;
        if (_callbackQueue) {
            _callbackScheduler = [[RACQueueScheduler alloc] initWithName:[self getCallbackSchedulerName] queue:_callbackQueue];
        } else {
            _callbackScheduler = nil;
        }
    }
}

- (RACScheduler *)callbackScheduler {
	_callbackScheduler = [[RACQueueScheduler alloc] initWithName:[self getCallbackSchedulerName] queue:self.callbackQueue];
	return _callbackScheduler;
}

- (dispatch_queue_t)excuteQueue {
    if (!_excuteQueue) {
        if (_userDefineExecQueue) {
            _excuteQueue = _userDefineExecQueue;
        } else if ([NSThread isMainThread]) {
            _excuteQueue = dispatch_get_main_queue();
        } else {
            _excuteQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        }
    }
    return _excuteQueue;
}

- (void)setExcuteQueue:(dispatch_queue_t)excuteQueue {
    if (_excuteQueue != excuteQueue) {
        _excuteQueue = excuteQueue;
        if (_excuteQueue) {
            _excuteScheduler = [[RACQueueScheduler alloc] initWithName:[self getExecuteSchedulerName] queue:_excuteQueue];
        } else {
            _excuteScheduler = nil;
        }
    }
}

- (RACScheduler *)excuteScheduler {
    if (!_excuteScheduler) {
        _excuteScheduler = [[RACQueueScheduler alloc] initWithName:[self getExecuteSchedulerName] queue:self.excuteQueue];
    }
    return _excuteScheduler;
}

- (NSString *)getExecuteSchedulerName {
    return [NSString stringWithFormat:@"Exec-%@-%p-%s", [self class], self, dispatch_queue_get_label(_excuteQueue)];
}

- (NSString *)getCallbackSchedulerName {
    return [NSString stringWithFormat:@"Callback-%@-%p-%s", [self class], self, dispatch_queue_get_label(_callbackQueue)];
}

- (RACSubject *)addedExecutionSignalsSubject {
    if (!_addedExecutionSignalsSubject) {
        _addedExecutionSignalsSubject = [RACSubject new];
    }
    return _addedExecutionSignalsSubject;
}

- (MGJAwesomeExcuteBlock)excuteBlock {
    return _excuteBlock;
}

- (void)setExcuteBlock:(MGJAwesomeExcuteBlock)excuteBlock {
    _excuteBlock = excuteBlock;
}

@end