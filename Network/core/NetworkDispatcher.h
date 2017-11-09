//
//  NetworkDispatcher.h
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import <Foundation/Foundation.h>
#import "NetworkConfig.h"
#import "NetworkExecutor.h"
#import "Requests.h"


@interface NetworkDispatcher : NSObject

+ (instancetype)defaultDispatcher;

+ (instancetype)dispatcher;

//config
- (void)setGlobalNetworkSettings:(NetworkDispatcherConfigBlock)config;

//unit request
//normal upload download task
- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock;

- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock;

- (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                         progress:(UnitRequestProcessBlock)progressBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock;



//chain request
- (ChainRequest *)dispatchChainRequestWithinConfigBlock:(ChainRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock;

//batch request
- (BatchRequest *)dispatchBatchRequestWithinConfigBlock:(BatchRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock;

- (UnitRequest *)cancelRequestById:(RequestId)reqId;



/*
 ********** deprecated ***********
//config
+ (void)setGlobalNetworkSettings:(NetworkDispatcherConfigBlock)config;

//unit request
//normal upload download task
+ (RequestId)dispatchUnitRequestWithinConfigBlock:(UnitRequestConfigBlock)configBlock
                                         progress:(UnitRequestProcessBlock)progressBlock
                                          success:(UnitRequestSuccessBlock)successBlock
                                          failure:(UnitRequestFailureBlock)failureBlock
                                         finished:(UnitRequestFinishedBlock)finishedBlock;

//chain request
+ (ChainRequest *)dispatchChainRequestWithinConfigBlock:(ChainRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock;


//batch request
+ (BatchRequest *)dispatchBatchRequestWithinConfigBlock:(BatchRequestConfigBlock)configBlock
                                                success:(GroupRequestSuccessBlock)successBlock
                                                failure:(GroupRequestFailureBlock)failureBlock
                                               finished:(GroupRequestFinishedBlock)finishedBlock;

//cancel
+ (UnitRequest *)cancelRequestById:(RequestId)reqId;
*/

@end





