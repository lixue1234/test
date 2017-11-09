//
//  NetworkConfig.m
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import "NetworkConfig.h"

@implementation NetworkConfig

- (instancetype)init {
    if (self = [super init]) {
        self.sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.callbackQueue = dispatch_queue_create("com.yitai.requestCallbackQueue", DISPATCH_QUEUE_SERIAL);
        self.maxConcurrentRequestCount = 5;
    }
    return self;
}

@end
