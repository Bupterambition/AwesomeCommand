//
//  MGJAwesomeCommand+ExecQueue.h
//  Pods
//
//  Created by Senmiao on 8/30/16.
//
//

#import "MGJAwesomeCommand.h"

@interface MGJAwesomeCommand (ExecQueue)

- (void)setExecQueue:(dispatch_queue_t)queue;

@end
