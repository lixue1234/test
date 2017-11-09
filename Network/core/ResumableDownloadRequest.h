//
//  ResumableDownloadRequest.h
//  OneTargetGPad
//
//  Created by Jaffer on 17/4/19.
//  Copyright © 2017年 yitai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Requests.h"

typedef long long (^ExpectedFileSizeBlock)(long long);

@interface ResumableDownloadRequest : NSObject

+ (instancetype)resumableDownloadRequestWithUrl:(NSString *)url
                                     parameters:(NSDictionary *)parameter
                                       filePath:(NSString *)filePath
                               expectedFileSize:(ExpectedFileSizeBlock)expectedFileSizeBlock
                                       progress:(UnitRequestProcessBlock)progressBlock
                                        success:(UnitRequestSuccessBlock)successBlock
                                        failure:(UnitRequestFailureBlock)failureBlock
                                       finished:(UnitRequestFinishedBlock)finishedBlock;
- (void)resumeDownload;

- (void)stopDownload;

- (void)cancelDownload;

@end
