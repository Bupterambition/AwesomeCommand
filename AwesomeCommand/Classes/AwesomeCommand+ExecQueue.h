//
//  AwesomeCommand+ExecQueue.h
//  Pods
//
//  Created by Senmiao on 8/30/16.
//
//

#import "AwesomeCommand.h"

@interface AwesomeCommand (ExecQueue)

- (void)setExecQueue:(dispatch_queue_t)queue;

@end
