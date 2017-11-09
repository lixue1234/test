//
//  NetworkDispatcher.m
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import "NetworkDispatcher.h"

static dispatch_queue_t requestCallbackQueue() {
    
    static dispatch_queue_t callbackQueue = nil;
    
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        
        callbackQueue = dispatch_queue_create("com.yitai.httpRequestCallbackQueue", DISPATCH_QUEUE_SERIAL);
    });
    
    return callbackQueue;
}



@interface NetworkDispatcher()

@property (nonatomic, strong) NetworkConfig *networkConfig;
@property (nonatomic, strong) NetworkExecutor *requestExecutor;

@end


@implementation NetworkDispatcher

#pragma mark dealloc
- (void)dealloc {
    NSLog(@"%s",__func__);
}

#pragma mark init
+ (instancetype)defaultDispatcher {
    static NetworkDispatcher *instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[NetworkDispatcher alloc] init];
    });
    
    return instance;
}

+ (instancetype)dispatcher {
    return [[NetworkDispatcher alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        self.networkConfig = [NetworkConfig new];
    }
    return self;
}

#pragma mark public method
//setting
- (void)setGlobalNetworkSettings:(NetworkDispatcherConfigBlock)config {
    self.networkConfig = [[NetworkConfig alloc] init];
    Block_Call(config, self.networkConfig);
}

+ (void)setGlobalNetworkSettings:(NetworkDispatcherConfigBlock)config {
    NetworkDispatcher *dispatcher = [NetworkDispatcher defaultDispatcher];
    dispatcher.networkConfig = [[NetworkConfig alloc] init];
    Block_Call(config, dispatcher.networkConfig);
}

#pragma mark cancel request
+ (UnitRequest *)cancelRequestById:(RequestId)reqId {
    NetworkDispatcher *dispatcher = [NetworkDispatcher defaultDispatcher];
    return [dispatcher cancelRequestById:reqId];
}

- (UnitRequest *)cancelRequestById:(RequestId)reqId {
   
   __block UnitRequest *request = nil;
   
   if (reqId == 0) {
        return nil;
   }
    
    AFHTTPSessionManager *manager = self.requestExecutor.sessionManager;
    if (manager && manager.tasks && manager.tasks.count > 0) {
        [manager.tasks enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.taskIdentifier == reqId) {
                [obj cancel];
                request = obj.rawRequest;
                *stop = YES;
            }
        }];
    }
    
    return request;
}

#pragma mark instance method

#pragma mark ==unit request
- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock {
    
    return [self dispatchUnitRequestWithinConfigBlock:configBlock
                                             progress:nil
                                             success:successBlock
                                             failure:failureBlock
                                             finished:nil];
}

- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock {
    
    return [self dispatchUnitRequestWithinConfigBlock:configBlock
                                             progress:nil
                                             success:successBlock
                                             failure:failureBlock
                                             finished:finishedBlock];
}


- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                         progress:(UnitRequestProcessBlock)progressBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock {
    //config request outside
    UnitRequest *request = [UnitRequest request];
    Block_Call(configBlock, request);
    
    //re-assemble request
    [self reassembleUnitRequest:request
                             progress:progressBlock
                              success:successBlock
                              failure:failureBlock
                             finished:finishedBlock];
    
    //dispatch request
    return [self dispatchUnitRequest:request];
}

#pragma mark ==chain request
//chain request
- (ChainRequest *)dispatchChainRequestWithinConfigBlock:(ChainRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock {
    //config request outside
    ChainRequest *chainRequest = [ChainRequest request];
    Block_Call(configBlock, chainRequest);
    
    //bind callback block
    chainRequest.groupSuccessBlock = successBlock ? successBlock : nil;
    chainRequest.groupFailureBlock = failureBlock ? failureBlock : nil;
    chainRequest.groupFinishedBlock = finishedBlock ? finishedBlock : nil;
    
    //get first unit request
    UnitRequest *firstRequest = [chainRequest.unitRequestsArray firstObject];
   
    if (firstRequest) {
        [self dispatchUnitRequest:firstRequest withinChainRequest:chainRequest];
    } else {
        [self executeBlockOnMainThread:chainRequest.isCallbackOnMainThread
                                 block:^{
                                     
                                     Block_Call(chainRequest.groupSuccessBlock, nil);
                                     Block_Call(chainRequest.groupFinishedBlock, nil, nil);
                                 }];
        
//        [self executeBlock:^{
//            Block_Call(chainRequest.groupSuccessBlock, nil);
//            Block_Call(chainRequest.groupFinishedBlock, nil, nil);
//        }];
        NSLog(@"%@",[NSString stringWithFormat:@"%s:have no unit requests",__func__]);
    }
    return chainRequest;
}

#pragma mark ==batch request
- (BatchRequest *)dispatchBatchRequestWithinConfigBlock:(BatchRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock {

    //config request outside
    BatchRequest *batchRequest = [BatchRequest request];
    Block_Call(configBlock, batchRequest);
    
    if (batchRequest.unitRequestsArray == nil || batchRequest.unitRequestsArray.count == 0) {
        return nil;
    }
    
    //bind callback block
    batchRequest.groupSuccessBlock = successBlock ? successBlock : nil;
    batchRequest.groupFailureBlock = failureBlock ? failureBlock : nil;
    batchRequest.groupFinishedBlock = finishedBlock ? finishedBlock : nil;

    //dispatch
    dispatch_group_t group = dispatch_group_create();
    
    [batchRequest.unitRequestsArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UnitRequest *unitRequest = (UnitRequest *)obj;
        
        dispatch_group_enter(group);
        
        __weak typeof(self) weakSelf = self;
        
        [weakSelf reassembleUnitRequest:unitRequest
                           progress:nil
                            success:nil
                            failure:nil
                           finished:^(id responseData, NSError *error) {
                                                              
                               [batchRequest finishedUnitRequest:unitRequest resposne:responseData error:error];
                               
                               dispatch_group_leave(group);
                           }];
        
        [self dispatchUnitRequest:unitRequest];
    }];
    
    __weak typeof(self) weakSelf = self;
   
    dispatch_notify(group, self.networkConfig.callbackQueue, ^{
    
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (batchRequest.errorExists) {
            
            [strongSelf executeBlockOnMainThread:batchRequest.isCallbackOnMainThread
                                           block:^{
                 
                                               Block_Call(batchRequest.groupFailureBlock, batchRequest.unitResponsesArray);
                                               Block_Call(batchRequest.groupFinishedBlock, nil, batchRequest.unitResponsesArray);
                                           }];
//            [strongSelf executeBlock:^{
//                Block_Call(batchRequest.groupFailureBlock, batchRequest.unitResponsesArray);
//                Block_Call(batchRequest.groupFinishedBlock, nil, batchRequest.unitResponsesArray);
//            }];
        } else {
        
            [strongSelf executeBlockOnMainThread:batchRequest.isCallbackOnMainThread
                                           block:^{
                 
                                               Block_Call(batchRequest.groupSuccessBlock, batchRequest.unitResponsesArray);
                                               Block_Call(batchRequest.groupFinishedBlock, batchRequest.unitResponsesArray, nil);

                                           }];
//            [strongSelf executeBlock:^{
//                Block_Call(batchRequest.groupSuccessBlock, batchRequest.unitResponsesArray);
//                Block_Call(batchRequest.groupFinishedBlock, batchRequest.unitResponsesArray, nil);
//            }];
        }
    });
        
    return batchRequest;
}


#pragma mark class method
+ (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                         progress:(UnitRequestProcessBlock)progressBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock {
    
    NetworkDispatcher *dispatcher = [NetworkDispatcher defaultDispatcher];
    return [dispatcher dispatchUnitRequestWithinConfigBlock:configBlock
                                                   progress:progressBlock
                                                    success:successBlock
                                                    failure:failureBlock
                                                   finished:finishedBlock];
    
}

+ (ChainRequest *)dispatchChainRequestWithinConfigBlock:(ChainRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock {
    
    NetworkDispatcher *dispatcher = [NetworkDispatcher defaultDispatcher];
    return [dispatcher dispatchChainRequestWithinConfigBlock:configBlock
                                                     success:successBlock
                                                     failure:failureBlock
                                                    finished:finishedBlock];
}

+ (BatchRequest *)dispatchBatchRequestWithinConfigBlock:(BatchRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock {
    
    NetworkDispatcher *dispatcher = [NetworkDispatcher defaultDispatcher];
    return [dispatcher dispatchBatchRequestWithinConfigBlock:configBlock
                                                     success:successBlock
                                                     failure:failureBlock
                                                    finished:finishedBlock];
    
    
}

#pragma mark dispatch
- (RequestId)dispatchUnitRequest:(UnitRequest *)request {
    __weak typeof(self) weakSelf = self;
    
    return [self.requestExecutor executeUnitRequest:request
                                  completion:^(id responseData, NSError *error) {
                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                      if (error) {
                                      
                                          //尝试重发
                                          if (request.retryTimes) {
                                              
                                              NSLog(@"%s::request=%@ --- retry",__func__, request);
                                              request.retryTimes --;
                                              
                                              [strongSelf dispatchUnitRequest:request];
                                              
                                          } else {
                                          
                                              [strongSelf executeBlockOnMainThread:request.isCallbackOnMainThread
                                                                             block:^{
                                                   
                                                                                 Block_Call(request.unitFailureBlock, error);
                                                                                 Block_Call(request.unitFinishedBlock, nil, error);

                                                                             }];
//                                              [strongSelf executeBlock:^{
//                                                  Block_Call(request.unitFailureBlock, error);
//                                                  Block_Call(request.unitFinishedBlock, nil, error);
//                                              }];
                                          }
                                        } else {
                                        
                                            [strongSelf executeBlockOnMainThread:request.isCallbackOnMainThread
                                                                           block:^{
                                                 
                                                                               Block_Call(request.unitSuccessBlock, responseData);
                                                                               Block_Call(request.unitFinishedBlock, responseData, nil);
                                                                           }];
//                                          [strongSelf executeBlock:^{
//                                              Block_Call(request.unitSuccessBlock, responseData);
//                                              Block_Call(request.unitFinishedBlock, responseData, nil);
//                                          }];
                                      }
                                  }];
}

- (RequestId)dispatchUnitRequest:(UnitRequest *)unitRequest withinChainRequest:(ChainRequest *)chainRequest {
    __weak typeof(self) weakSelf = self;

    [self reassembleUnitRequest:unitRequest
                       progress:nil
                        success:nil
                        failure:nil
                       finished:^(id responseData, NSError *error) {
                           __strong typeof(weakSelf) strongSelf = weakSelf;
                           
                           ExecuteState executeState = ExecuteStateSuccss;
                           UnitRequest *nextRequest = [chainRequest getNextUnitRequestDependingOnCurrentRequest:unitRequest response:responseData error:error executeState:&executeState];
                           
                           if (nextRequest) {
                               //继续下一个任务
                               [strongSelf dispatchUnitRequest:nextRequest withinChainRequest:chainRequest];
                           } else {
                               if (executeState == ExecuteStateSuccss) {
                                   //所有任务已经完成
                                   
                                   [strongSelf executeBlockOnMainThread:chainRequest.isCallbackOnMainThread
                                                                  block:^{
                                       
                                                                      Block_Call(chainRequest.groupSuccessBlock, chainRequest.unitResponsesArray);
                                                                      Block_Call(chainRequest.groupFinishedBlock, chainRequest.unitResponsesArray, nil);
                                                                  }];
//                                   [strongSelf executeBlock:^{
//                                       Block_Call(chainRequest.groupSuccessBlock, chainRequest.unitResponsesArray);
//                                       Block_Call(chainRequest.groupFinishedBlock, chainRequest.unitResponsesArray, nil);
//                                   }];
                               } else if (executeState == ExecuteStateFialure) {
                                   //某个任务失败导致中断
                                   
                                   [strongSelf executeBlockOnMainThread:chainRequest.isCallbackOnMainThread
                                                                  block:^{
                                        
                                                                      Block_Call(chainRequest.groupFailureBlock, chainRequest.unitResponsesArray);
                                                                      Block_Call(chainRequest.groupFinishedBlock, nil, chainRequest.unitResponsesArray);

                                                                  }];
//                                   Block_Call(chainRequest.groupFailureBlock, chainRequest.unitResponsesArray);
//                                   Block_Call(chainRequest.groupFinishedBlock, nil, chainRequest.unitResponsesArray);
                               }
                           }
                       }];
    return [self dispatchUnitRequest:unitRequest];
}

#pragma process response


#pragma mark reassemble
- (void)reassembleUnitRequest:(UnitRequest *)request
                     progress:(UnitRequestProcessBlock)progressBlock
                      success:(UnitRequestSuccessBlock)successBlock
                      failure:(UnitRequestFailureBlock)failureBlock
                     finished:(UnitRequestFinishedBlock)finishedBlock {
    
    //bind callback blocks
    request.unitProcessBlock = progressBlock ? progressBlock : nil;
    request.unitSuccessBlock = successBlock ? successBlock : nil;
    request.unitFailureBlock = failureBlock ? failureBlock : nil;
    request.unitFinishedBlock = finishedBlock ? finishedBlock : nil;
    
    //request url
    NSString *validUrl = nil;
    if (request.needAppendGlobalServerHost) {
        if (self.networkConfig.serverHost) {
            validUrl = self.networkConfig.serverHost;
            if (request.path) {
                validUrl = [self.networkConfig.serverHost stringByAppendingPathComponent:request.path];
            }
        } else {
            NSAssert(NO, @"The global server host did not be configured");
        }
    } else {
        
        validUrl = request.url;
    }
    NSAssert(validUrl, @"There is no valid request url for current request");
    request.url = validUrl;
    
    //request params
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (request.needAppendGlobalParams) {
        if (self.networkConfig.publicParams) {
            [params addEntriesFromDictionary:self.networkConfig.publicParams];
        }
        if (request.exclusiveParams) {
            [params addEntriesFromDictionary:request.exclusiveParams];
        }
    } else {
        if (request.exclusiveParams) {
            [params addEntriesFromDictionary:request.exclusiveParams];
        }
    }
    request.exclusiveParams = params;
    
    //request headers
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    if (request.needAppendGlobalHeaders) {
        if (self.networkConfig.publicHeaders) {
            [headers addEntriesFromDictionary:self.networkConfig.publicHeaders];
        }
        if (request.exclusiveHeaders) {
            [headers addEntriesFromDictionary:request.exclusiveHeaders];
        }
    } else {
        if (request.exclusiveHeaders) {
            [headers addEntriesFromDictionary:request.exclusiveHeaders];
        }
    }
    request.exclusiveHeaders = headers;
}

#pragma mark tools
- (void)executeBlock:(void(^)())block {
    dispatch_queue_t queue = self.networkConfig.callbackQueue;
    if (queue) {
        dispatch_async(queue, ^{
            block();
        });
    } else {
        block();
    }
}

- (void)executeBlockOnMainThread:(BOOL)onMainThread block:(void(^)())block {
    
    if (onMainThread) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            block();
        });
    } else {
        
        dispatch_async(requestCallbackQueue(), ^{
            
            block();
        });
    }
}

- (NetworkExecutor *)requestExecutor {
    if (_requestExecutor == nil) {
        _requestExecutor = [[NetworkExecutor alloc] initWithNetworkCofig:self.networkConfig];
    }
    return _requestExecutor;
}


@end








