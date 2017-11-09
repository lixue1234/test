//
//  ResumableDownloadRequest.m
//  OneTargetGPad
//
//  Created by Jaffer on 17/4/19.
//  Copyright © 2017年 yitai. All rights reserved.
//

#import "ResumableDownloadRequest.h"
#import "AFNetworking.h"
#import "NSObject+Addtions.h"


static dispatch_queue_t createCallbackQueue() {
    
    static dispatch_queue_t callbackQueue = nil;
    
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        
        callbackQueue = dispatch_queue_create("com.yitai.resumableDownloadCallbackQueue", DISPATCH_QUEUE_SERIAL);
    });
    
    return callbackQueue;
}


@interface ResumableDownloadRequest () <NSURLSessionDataDelegate>

@property (nonatomic, strong) AFHTTPRequestSerializer *requestSerializer;
@property (nonatomic, strong) AFHTTPResponseSerializer *responseSerializer;

@property (nonatomic, copy) ExpectedFileSizeBlock expectedFileSizeBlock;
@property (nonatomic, copy) UnitRequestProcessBlock progressBlock;
@property (nonatomic, copy) UnitRequestSuccessBlock successBlock;
@property (nonatomic, copy) UnitRequestFailureBlock failureBlock;
@property (nonatomic, copy) UnitRequestFinishedBlock finishedBlock;

@property (nonatomic, assign) long long currentFileSize;
@property (nonatomic, assign) long long expectedFileSize;

@property (nonatomic, strong) NSString *filePath;

@property (nonatomic, strong) NSURLSession *currentSession;
@property (nonatomic, strong) NSURLSessionDataTask *currentDownloadTask;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSProgress *currentProgress;


@end

@implementation ResumableDownloadRequest

- (void)dealloc {
    NSLog(@"%s::dealloc",__func__);
}

+ (instancetype)resumableDownloadRequestWithUrl:(NSString *)url
                                     parameters:(NSDictionary *)parameter
                                       filePath:(NSString *)filePath
                               expectedFileSize:(ExpectedFileSizeBlock)expectedFileSizeBlock
                                       progress:(UnitRequestProcessBlock)progressBlock
                                        success:(UnitRequestSuccessBlock)successBlock
                                        failure:(UnitRequestFailureBlock)failureBlock
                                       finished:(UnitRequestFinishedBlock)finishedBlock {
    
    ResumableDownloadRequest *downloadRequest = nil;
    
    if ([url isValidString] && [filePath isValidString]) {
        downloadRequest = [ResumableDownloadRequest new];
        
        downloadRequest.expectedFileSizeBlock = expectedFileSizeBlock;
        downloadRequest.progressBlock = progressBlock;
        downloadRequest.successBlock = successBlock;
        downloadRequest.failureBlock = failureBlock;
        downloadRequest.finishedBlock = finishedBlock;
        
        downloadRequest.filePath = filePath;
        
        downloadRequest.currentFileSize = [downloadRequest getCurrentFileSize];
        
        if (downloadRequest.currentFileSize > 0) {
            
            downloadRequest.expectedFileSize = expectedFileSizeBlock ? expectedFileSizeBlock(0) : 0;
            downloadRequest.currentProgress.totalUnitCount = downloadRequest.expectedFileSize;
            downloadRequest.currentProgress.completedUnitCount = downloadRequest.currentFileSize;

            [downloadRequest updateProgress];
        }
        
        [downloadRequest setupWithURL:url parameters:parameter];
    }
    
    return downloadRequest;
}

- (void)setupWithURL:(NSString *)url parameters:(NSDictionary *)parameter {
    
    NSLog(@"断点下载资源地址=======%@",url);
    
    NSError *serError = nil;
    //在文件服务器上时，使用post序列化request时出现问题，返回数据都是固定大小（应该是报错信息）
    //NSMutableURLRequest *downloadRequest = [self.requestSerializer requestWithMethod:@"POST" URLString:url parameters:parameter error:&serError];

    NSMutableURLRequest *downloadRequest = [self.requestSerializer requestWithMethod:@"GET" URLString:url parameters:parameter error:&serError];
    
    if (serError) {
        
        NSLog(@"%s::serialize download request error=%@",__func__, serError);
        
        @weakify(self);
        [self execCallback:^{
            @strongify(self);
            if (self.failureBlock) {
                self.failureBlock(serError);
            }
            
            if (self.finishedBlock) {
                self.finishedBlock(nil, serError);
            }
        }];
        
        return;
    }
    
    NSString *range = [NSString stringWithFormat:@"bytes=%lld-",self.currentFileSize];
    [downloadRequest setValue:range forHTTPHeaderField:@"Range"];
    
    [downloadRequest setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    self.currentDownloadTask = [self.currentSession dataTaskWithRequest:downloadRequest];
}

#pragma mark download control
- (void)resumeDownload {
    [self.currentDownloadTask resume];
}

- (void)stopDownload {
    [self.currentDownloadTask suspend];
}

- (void)cancelDownload {
    [self.currentDownloadTask cancel];
}

#pragma mark NSURLSessionDataDelegate

//收到response
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    if (self.currentFileSize == 0) {
        
        self.expectedFileSize = response.expectedContentLength;
        self.currentProgress.totalUnitCount = self.expectedFileSize;
        self.currentProgress.completedUnitCount = self.currentFileSize;
        
        if (self.expectedFileSizeBlock && self.expectedFileSize > 0) {
            self.expectedFileSizeBlock(self.expectedFileSize);
        }
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

//开始接收数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    self.currentFileSize += data.length;
    
    self.currentProgress.completedUnitCount = self.currentFileSize;
    
    [self updateProgress];
    
    [self.outputStream write:data.bytes maxLength:data.length];

}

//下载完成或失败
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    
    @weakify(self);
    [self execCallback:^{
        @strongify(self);
        
        if (error) {
            
            if (self.failureBlock) {
                self.failureBlock(error);
            }
        } else {
            
            if (self.successBlock) {
                self.successBlock(nil);
            }
        }
        
        if (self.finishedBlock) {
            self.finishedBlock(nil, error);
        }
        
        [self destroy];

    }];
}


#pragma mark getter
- (NSProgress *)currentProgress {
    if (_currentProgress == nil) {
        _currentProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        _currentProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    }
    return _currentProgress;
}

- (NSURLSession *)currentSession {
    if (_currentSession == nil) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        
        _currentSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue new]];
        
    }
    return _currentSession;
}

- (NSOutputStream *)outputStream {
    if (_outputStream == nil) {
        _outputStream = [[NSOutputStream alloc] initToFileAtPath:self.filePath append:YES];
        [_outputStream open];
    }
    return _outputStream;
}

- (AFHTTPRequestSerializer *)requestSerializer {
    if (_requestSerializer == nil) {
        _requestSerializer = [AFHTTPRequestSerializer serializer];
    }
    return _requestSerializer;
}

- (AFHTTPResponseSerializer *)responseSerializer {
    if (_responseSerializer == nil) {
        _responseSerializer = [AFHTTPResponseSerializer serializer];
    }
    return _responseSerializer;
}

#pragma mark tool
- (void)updateProgress {
    @weakify(self);
    [self execCallback:^{
        @strongify(self);
        if (self.progressBlock) {
            self.progressBlock(self.currentProgress);
        }
    }];
}

- (void)destroy {
    [self.outputStream close];

    [self.currentSession invalidateAndCancel];
}

- (long long)getCurrentFileSize {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exist = [fileManager fileExistsAtPath:self.filePath];
    
    long long size = 0;
    if (exist) {
        size = [[[fileManager attributesOfItemAtPath:self.filePath error:nil] objectForKey:@"NSFileSize"] longLongValue];
    }
    
    return size;
}

- (void)execCallback:(void(^)())callback {
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        
//        callback();
//    });
    
    //在子线程回调
    dispatch_sync(createCallbackQueue(), ^{
       
        callback();
    });
}


/*
//有问题
- (void)safeCallback:(void(^)()) block, ... {
    
    if (block) {
        
        va_list argList;
        va_start(argList, block);
        
        block(argList);
        
        va_end(argList);
    }
}
*/

@end
