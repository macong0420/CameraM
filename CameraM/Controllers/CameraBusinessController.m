//
//  CameraBusinessController.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraBusinessController.h"
#import "../Managers/CMWatermarkRenderer.h"
#import "../Services/CMCaptureSessionService.h"
#import "../Common/CMConstants.h"
#import "../Common/CMSettingsStorage.h"
#import <mach/mach.h>

static inline CFTimeInterval CMPerfNow(void) {
  return CFAbsoluteTimeGetCurrent();
}

static inline double CMPerfDurationMs(CFTimeInterval start, CFTimeInterval end) {
  return (end - start) * 1000.0;
}

static double CMResidentMemoryMB(void) {
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  kern_return_t kr =
      task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count);
  if (kr != KERN_SUCCESS) {
    return 0.0;
  }
  return (double)info.resident_size / (1024.0 * 1024.0);
}

static UIImage *CMNormalizeImageOrientation(UIImage *image) {
  if (!image || image.imageOrientation == UIImageOrientationUp) {
    return image;
  }

  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return normalizedImage ?: image;
}

@interface CameraBusinessController () <CameraManagerDelegate>

@property(nonatomic, strong) id<CMCaptureSessionServicing> captureService;
@property(nonatomic, strong) UIImage *latestCapturedImage;
@property(nonatomic, assign) BOOL isGridLinesVisible;
@property(nonatomic, copy) CMWatermarkConfiguration *watermarkConfiguration;
@property(nonatomic, strong) CMWatermarkRenderer *watermarkRenderer;
@property(nonatomic, strong) NSOperationQueue *decodeQueue;
@property(nonatomic, strong) NSOperationQueue *composeQueue;
@property(nonatomic, strong) NSOperationQueue *saveQueue;
@property(nonatomic, copy) NSArray<CMCameraLensOption *> *availableLensOptions;
@property(nonatomic, strong) CMCameraLensOption *currentLensOption;
@property(nonatomic, copy) NSString *restoredLensIdentifier;
@property(nonatomic, assign) uint64_t perfJobSequence;
@property(nonatomic, assign) NSInteger pendingRenderTaskCount;
@property(nonatomic, assign) NSInteger maxObservedRenderQueueDepth;
@property(nonatomic, assign) NSUInteger totalProcessedJobs;
@property(nonatomic, assign) NSUInteger totalFailedJobs;
@property(nonatomic, assign) NSInteger maxPendingJobs;
@property(nonatomic, assign) NSInteger dropThresholdJobs;
@property(nonatomic, assign) uint64_t nextCompletionJobID;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSDictionary *> *pendingOrderedCompletions;

- (void)persistWatermarkConfiguration;
- (void)loadPersistedWatermarkConfiguration;
- (void)persistCurrentLensSelection;
- (void)loadPersistedSettings;
- (void)persistFlashMode;
- (void)persistGridVisibility;
- (void)persistCurrentResolutionMode;
- (void)enqueueOrderedCompletionForJobID:(uint64_t)jobID
                             finalImage:(nullable UIImage *)finalImage
                                  error:(nullable NSError *)error
                             completion:
                                 (void (^)(UIImage *_Nullable processedImage,
                                           NSError *_Nullable error))completion;

@end

@implementation CameraBusinessController

- (instancetype)init {
  return [self initWithCaptureService:nil];
}

- (instancetype)initWithCaptureService:
    (id<CMCaptureSessionServicing>)service {
  self = [super init];
  if (self) {
    id<CMCaptureSessionServicing> resolvedService = service;
    if (!resolvedService) {
      CameraManager *manager = [CameraManager sharedManager];
      resolvedService =
          [[CMCaptureSessionService alloc] initWithCameraManager:manager];
    }
    _captureService = resolvedService;
    _captureService.delegate = self;

    _isGridLinesVisible = NO;
    _watermarkConfiguration = [CMWatermarkConfiguration defaultConfiguration];
    [self loadPersistedWatermarkConfiguration];
    [self loadPersistedSettings];
    _watermarkRenderer = [[CMWatermarkRenderer alloc] init];
    _decodeQueue = [[NSOperationQueue alloc] init];
    _decodeQueue.name = @"com.cameram.pipeline.decode";
    _decodeQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    _decodeQueue.maxConcurrentOperationCount = 2;
    _composeQueue = [[NSOperationQueue alloc] init];
    _composeQueue.name = @"com.cameram.pipeline.compose";
    _composeQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    _composeQueue.maxConcurrentOperationCount = 2;
    _saveQueue = [[NSOperationQueue alloc] init];
    _saveQueue.name = @"com.cameram.pipeline.save";
    _saveQueue.qualityOfService = NSQualityOfServiceUtility;
    _saveQueue.maxConcurrentOperationCount = 1;
    _availableLensOptions = _captureService.availableLensOptions ?: @[];
    _currentLensOption = _captureService.currentLensOption;
    _restoredLensIdentifier = [[CMSettingsStorage sharedStorage] loadLensIdentifier];
    _perfJobSequence = 0;
    _pendingRenderTaskCount = 0;
    _maxObservedRenderQueueDepth = 0;
    _totalProcessedJobs = 0;
    _totalFailedJobs = 0;
    _maxPendingJobs = 8;
    _dropThresholdJobs = 12;
    _nextCompletionJobID = 1;
    _pendingOrderedCompletions = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)enqueueOrderedCompletionForJobID:(uint64_t)jobID
                             finalImage:(UIImage *)finalImage
                                  error:(NSError *)error
                             completion:
                                 (void (^)(UIImage *_Nullable processedImage,
                                           NSError *_Nullable error))completion {
  if (!completion) {
    if (error) {
      NSLog(@"⚠️ 保存图片失败: %@", error.localizedDescription);
    }
    return;
  }

  NSMutableArray<NSDictionary *> *readyEntries = [NSMutableArray array];
  @synchronized(self) {
    self.pendingOrderedCompletions[@(jobID)] = @{
      @"completion" : [completion copy],
      @"image" : finalImage ?: [NSNull null],
      @"error" : error ?: [NSNull null]
    };

    while (YES) {
      NSNumber *nextKey = @(self.nextCompletionJobID);
      NSDictionary *entry = self.pendingOrderedCompletions[nextKey];
      if (!entry) {
        break;
      }
      [readyEntries addObject:entry];
      [self.pendingOrderedCompletions removeObjectForKey:nextKey];
      self.nextCompletionJobID += 1;
    }
  }

  if (readyEntries.count == 0) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    for (NSDictionary *entry in readyEntries) {
      void (^entryCompletion)(UIImage *_Nullable, NSError *_Nullable) =
          entry[@"completion"];
      id imageValue = entry[@"image"];
      id errorValue = entry[@"error"];
      UIImage *orderedImage =
          [imageValue isKindOfClass:[NSNull class]] ? nil : (UIImage *)imageValue;
      NSError *orderedError =
          [errorValue isKindOfClass:[NSNull class]] ? nil : (NSError *)errorValue;
      if (entryCompletion) {
        entryCompletion(orderedImage, orderedError);
      }
    }
  });
}

// Convenience accessor for preview layer
- (AVCaptureVideoPreviewLayer *)previewLayer {
  return self.captureService.previewLayer;
}

#pragma mark - 状态查询接口

- (CameraResolutionMode)currentResolutionMode {
  return self.captureService.currentResolutionMode;
}

- (FlashMode)currentFlashMode {
  return self.captureService.currentFlashMode;
}

- (CameraAspectRatio)currentAspectRatio {
  return self.captureService.currentAspectRatio;
}

- (CameraDeviceOrientation)currentDeviceOrientation {
  return self.captureService.currentDeviceOrientation;
}

- (BOOL)isUltraHighResolutionSupported {
  return self.captureService.isUltraHighResolutionSupported;
}

#pragma mark - 相机控制接口

- (void)setupCameraWithPreviewView:(UIView *)previewView
                        completion:
                            (void (^)(BOOL success,
                                      NSError *_Nullable error))completion {
  [self.captureService setupCameraWithPreviewView:previewView
                                       completion:completion];
}

- (void)startSession {
  [self.captureService startSession];
}

- (void)stopSession {
  [self.captureService stopSession];
}

- (void)cleanup {
  [self.decodeQueue cancelAllOperations];
  [self.composeQueue cancelAllOperations];
  [self.saveQueue cancelAllOperations];
  @synchronized(self) {
    [self.pendingOrderedCompletions removeAllObjects];
    self.nextCompletionJobID = self.perfJobSequence + 1;
  }
  [self.captureService cleanup];
}

- (void)startOrientationMonitoring {
  [self.captureService startDeviceOrientationMonitoring];
}

- (void)stopOrientationMonitoring {
  [self.captureService stopDeviceOrientationMonitoring];
}

#pragma mark - 拍摄控制

- (void)capturePhoto {
  if (self.captureService.currentState != CameraStateRunning) {
    NSError *stateError =
        [NSError errorWithDomain:kCMBusinessControllerErrorDomain
                            code:3002
                        userInfo:@{
                          NSLocalizedDescriptionKey : @"相机尚未就绪，请稍后重试"
                        }];
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self.delegate respondsToSelector:@selector(didFailWithError:)]) {
        [self.delegate didFailWithError:stateError];
      }
    });
    return;
  }
  CFTimeInterval captureRequestTime = CMPerfNow();
  NSLog(@"📊 [Perf][Capture] request state=%ld t=%.6f",
        (long)self.captureService.currentState, captureRequestTime);
  [self.captureService capturePhoto];
}

- (void)switchCamera {
  [self.captureService switchCamera];
}

- (void)switchResolutionMode {
  CameraResolutionMode currentMode = self.captureService.currentResolutionMode;
  CameraResolutionMode newMode = (currentMode == CameraResolutionModeStandard)
                                     ? CameraResolutionModeUltraHigh
                                     : CameraResolutionModeStandard;

  if (newMode == CameraResolutionModeUltraHigh &&
      !self.captureService.isUltraHighResolutionSupported) {
    return; // 不支持高分辨率
  }

  [self.captureService switchResolutionMode:newMode];
}

- (void)switchFlashMode {
  FlashMode currentMode = self.captureService.currentFlashMode;
  FlashMode nextMode;

  switch (currentMode) {
  case FlashModeAuto:
    nextMode = FlashModeOn;
    break;
  case FlashModeOn:
    nextMode = FlashModeOff;
    break;
  case FlashModeOff:
    nextMode = FlashModeAuto;
    break;
  }

  [self.captureService switchFlashMode:nextMode];
  [self persistFlashMode];
}

- (void)switchAspectRatio:(CameraAspectRatio)ratio {
  [self.captureService switchAspectRatio:ratio];
}

- (void)switchToLensOption:(CMCameraLensOption *)lensOption {
  [self.captureService switchToLensOption:lensOption];
}

#pragma mark - 对焦和曝光

- (void)focusAtPoint:(CGPoint)screenPoint
    withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
  // 转换屏幕坐标到设备坐标
  CGPoint devicePoint =
      [previewLayer captureDevicePointOfInterestForPoint:screenPoint];
  [self.captureService focusAtPoint:devicePoint];
}

- (void)setExposureCompensation:(float)value {
  [self.captureService setExposureCompensation:value];
}

#pragma mark - 网格线状态管理

- (void)toggleGridLines {
  self.isGridLinesVisible = !self.isGridLinesVisible;
  [self persistGridVisibility];
}

- (BOOL)isGridLinesVisible {
  return _isGridLinesVisible;
}

- (CGRect)previewRectForCurrentAspectRatioInViewSize:(CGSize)viewSize {
  return [self.captureService previewRectForAspectRatio:self.currentAspectRatio
                                             inViewSize:viewSize];
}

- (CGRect)activePreviewRectInViewSize:(CGSize)viewSize {
  return [self.captureService activeFormatPreviewRectInViewSize:viewSize];
}

- (void)updateWatermarkConfiguration:(CMWatermarkConfiguration *)configuration {
  if (!configuration) {
    return;
  }
  self.watermarkConfiguration = [configuration copy];
  [self persistWatermarkConfiguration];
}

- (void)processImage:(UIImage *)image
            metadata:(nullable NSDictionary *)metadata
       configuration:(nullable CMWatermarkConfiguration *)configuration
           applyCrop:(BOOL)applyCrop
          completion:(void (^)(UIImage *_Nullable processedImage,
                               NSError *_Nullable error))completion {
  if (!image) {
    if (completion) {
      NSError *error = [NSError
          errorWithDomain:kCMBusinessControllerErrorDomain
                     code:3001
                 userInfo:@{NSLocalizedDescriptionKey : @"未获取到有效的图片"}];
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, error);
      });
    }
    return;
  }

  __weak typeof(self) weakSelf = self;
  __block uint64_t jobID = 0;
  CFTimeInterval enqueueTime = CMPerfNow();
  NSInteger queueDepth = 0;
  BOOL shouldUseFastPath = NO;
  @synchronized(self) {
    self.perfJobSequence += 1;
    jobID = self.perfJobSequence;
    self.pendingRenderTaskCount += 1;
    queueDepth = self.pendingRenderTaskCount;
    if (self.pendingRenderTaskCount > self.maxObservedRenderQueueDepth) {
      self.maxObservedRenderQueueDepth = self.pendingRenderTaskCount;
    }
    shouldUseFastPath = (self.pendingRenderTaskCount > self.maxPendingJobs);
  }

  NSLog(
      @"📊 [Perf][Pipeline][Enqueue] job=%llu queueDepth=%ld maxDepth=%ld image=%.0fx%.0f mem=%.1fMB",
      jobID, (long)queueDepth, (long)self.maxObservedRenderQueueDepth, image.size.width,
      image.size.height, CMResidentMemoryMB());
  if (shouldUseFastPath) {
    NSLog(@"⚠️ [Backpressure] job=%llu queueDepth=%ld > maxPending=%ld, fast-path enabled",
          jobID, (long)queueDepth, (long)self.maxPendingJobs);
  }
  if (queueDepth > self.dropThresholdJobs) {
    NSInteger remainingQueueDepth = 0;
    NSUInteger failedCount = 0;
    @synchronized(self) {
      if (self.pendingRenderTaskCount > 0) {
        self.pendingRenderTaskCount -= 1;
      }
      self.totalFailedJobs += 1;
      remainingQueueDepth = self.pendingRenderTaskCount;
      failedCount = self.totalFailedJobs;
    }
    NSError *overloadError = [NSError
        errorWithDomain:kCMBusinessControllerErrorDomain
                   code:3003
               userInfo:@{
                 NSLocalizedDescriptionKey :
                     @"处理队列繁忙，已触发过载保护，请稍后重试"
               }];
    NSLog(
        @"⛔️ [Backpressure] drop job=%llu queueDepth=%ld threshold=%ld stats(failed=%lu)",
        jobID, (long)remainingQueueDepth, (long)self.dropThresholdJobs,
        (unsigned long)failedCount);
    [self enqueueOrderedCompletionForJobID:jobID
                                finalImage:nil
                                     error:overloadError
                                completion:completion];
    return;
  }
  __block UIImage *workingImage = image;
  __block UIImage *finalImage = image;
  __block NSError *pipelineError = nil;
  __block CFTimeInterval cropStart = 0;
  __block CFTimeInterval cropEnd = 0;
  __block CFTimeInterval composeStart = 0;
  __block CFTimeInterval composeEnd = 0;
  __block CFTimeInterval saveStart = 0;
  __block CFTimeInterval saveEnd = 0;

  NSBlockOperation *decodeOp = [NSBlockOperation blockOperationWithBlock:^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }
      CFTimeInterval startTime = CMPerfNow();
      CFTimeInterval dequeueWaitMs = CMPerfDurationMs(enqueueTime, startTime);
      NSLog(@"📊 [Perf][Pipeline][Start] job=%llu queueWait=%.2fms stage=decode",
            jobID, dequeueWaitMs);

      cropStart = CMPerfNow();
      if (applyCrop) {
        CameraAspectRatio aspectRatio = strongSelf.currentAspectRatio;
        UIImage *croppedImage =
            [strongSelf.captureService cropImage:image toAspectRatio:aspectRatio];
        if (croppedImage) {
          workingImage = croppedImage;
        }
      } else {
        workingImage = CMNormalizeImageOrientation(image);
      }
      cropEnd = CMPerfNow();
    }
  }];

  NSBlockOperation *composeOp = [NSBlockOperation blockOperationWithBlock:^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }
      if (decodeOp.isCancelled) {
        return;
      }
      composeStart = CMPerfNow();
      CMWatermarkConfiguration *configurationSnapshot =
          configuration ? [configuration copy]
                        : [strongSelf.watermarkConfiguration copy];
      UIImage *renderedImage = workingImage;
      if (configurationSnapshot && !shouldUseFastPath) {
        UIImage *watermarked =
            [strongSelf.watermarkRenderer renderImage:workingImage
                                    withConfiguration:configurationSnapshot
                                             metadata:metadata];
        if (watermarked) {
          renderedImage = watermarked;
        }
      } else if (shouldUseFastPath) {
        NSLog(@"⚡️ [Backpressure] job=%llu skip compose to reduce latency",
              jobID);
      }
      finalImage = renderedImage ?: workingImage;
      composeEnd = CMPerfNow();
    }
  }];
  [composeOp addDependency:decodeOp];

  NSBlockOperation *saveOp = [NSBlockOperation blockOperationWithBlock:^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }
      if (decodeOp.isCancelled || composeOp.isCancelled) {
        return;
      }
      saveStart = CMPerfNow();
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      __block NSError *saveError = nil;
      __block BOOL saveSuccess = NO;

      [strongSelf.captureService
          saveImageToPhotosLibrary:finalImage
                          metadata:metadata
                        completion:^(BOOL success, NSError *_Nullable error) {
                          saveSuccess = success;
                          saveError = error;
                          dispatch_semaphore_signal(sema);
                        }];
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
      saveEnd = CMPerfNow();

      if (!saveSuccess || saveError) {
        pipelineError = saveError;
      }

      NSInteger remainingQueueDepth = 0;
      NSUInteger processedCount = 0;
      NSUInteger failedCount = 0;
      @synchronized(strongSelf) {
        if (strongSelf.pendingRenderTaskCount > 0) {
          strongSelf.pendingRenderTaskCount -= 1;
        }
        remainingQueueDepth = strongSelf.pendingRenderTaskCount;
        strongSelf.totalProcessedJobs += 1;
        if (!saveSuccess || saveError) {
          strongSelf.totalFailedJobs += 1;
        }
        processedCount = strongSelf.totalProcessedJobs;
        failedCount = strongSelf.totalFailedJobs;
      }
      NSLog(
          @"📊 [Perf][Pipeline][Done] job=%llu crop=%.2fms compose=%.2fms save=%.2fms total=%.2fms queueDepth=%ld fail=%@ stats(total=%lu failed=%lu) mem=%.1fMB",
          jobID, CMPerfDurationMs(cropStart, cropEnd),
          CMPerfDurationMs(composeStart, composeEnd),
          CMPerfDurationMs(saveStart, saveEnd),
          CMPerfDurationMs(enqueueTime, saveEnd), (long)remainingQueueDepth,
          (saveError || !saveSuccess) ? @"YES" : @"NO",
          (unsigned long)processedCount, (unsigned long)failedCount,
          CMResidentMemoryMB());

      [strongSelf enqueueOrderedCompletionForJobID:jobID
                                        finalImage:finalImage
                                             error:pipelineError
                                        completion:completion];
    }
  }];
  [saveOp addDependency:composeOp];

  [self.decodeQueue addOperation:decodeOp];
  [self.composeQueue addOperation:composeOp];
  [self.saveQueue addOperation:saveOp];
}

- (void)processImportedImage:(UIImage *)image
           withConfiguration:(CMWatermarkConfiguration *)configuration
                  completion:(void (^)(UIImage *_Nullable processedImage,
                                       NSError *_Nullable error))completion {
  [self processImportedImage:image
                     metadata:nil
            withConfiguration:configuration
                    completion:completion];
}

- (void)processImportedImage:(UIImage *)image
                  completion:(void (^)(UIImage *_Nullable processedImage,
                                       NSError *_Nullable error))completion {
  [self processImportedImage:image withConfiguration:nil completion:completion];
}

- (void)processImportedImage:(UIImage *)image
                     metadata:(NSDictionary *)metadata
            withConfiguration:(CMWatermarkConfiguration *)configuration
                    completion:(void (^)(UIImage *_Nullable processedImage,
                                         NSError *_Nullable error))completion {
  [self processImage:image
            metadata:metadata
       configuration:configuration
           applyCrop:NO
          completion:^(UIImage *_Nullable processedImage,
                       NSError *_Nullable error) {
            if (processedImage) {
              self.latestCapturedImage = processedImage;
            }
            if (completion) {
              completion(processedImage, error);
            }
          }];
}

- (void)loadPersistedSettings {
  CMSettingsStorage *storage = [CMSettingsStorage sharedStorage];

  // Load grid visibility
  _isGridLinesVisible = [storage loadGridVisibilityWithDefault:NO];

  // Load flash mode
  FlashMode storedFlashMode = [storage loadFlashModeWithDefault:FlashModeAuto];
  if (storedFlashMode != self.captureService.currentFlashMode) {
    [self.captureService switchFlashMode:storedFlashMode];
  } else {
    [self persistFlashMode];
  }

  // Load resolution mode
  CameraResolutionMode storedResolutionMode =
      [storage loadResolutionModeWithDefault:CameraResolutionModeStandard];
  if (storedResolutionMode == CameraResolutionModeUltraHigh &&
      !self.captureService.isUltraHighResolutionSupported) {
    storedResolutionMode = CameraResolutionModeStandard;
  }

  if (storedResolutionMode != self.captureService.currentResolutionMode) {
    [self.captureService switchResolutionMode:storedResolutionMode];
  } else {
    [self persistCurrentResolutionMode];
  }
}

- (void)persistFlashMode {
  [[CMSettingsStorage sharedStorage]
      saveFlashMode:self.captureService.currentFlashMode];
}

- (void)persistGridVisibility {
  [[CMSettingsStorage sharedStorage] saveGridVisibility:self.isGridLinesVisible];
}

- (void)persistCurrentResolutionMode {
  [[CMSettingsStorage sharedStorage]
      saveResolutionMode:self.captureService.currentResolutionMode];
}

- (void)persistWatermarkConfiguration {
  [[CMSettingsStorage sharedStorage]
      saveWatermarkConfiguration:self.watermarkConfiguration];
}

- (void)loadPersistedWatermarkConfiguration {
  CMWatermarkConfiguration *storedConfig =
      [[CMSettingsStorage sharedStorage] loadWatermarkConfiguration];
  if (storedConfig) {
    self.watermarkConfiguration = [storedConfig copy];
  }
}

- (void)persistCurrentLensSelection {
  [[CMSettingsStorage sharedStorage]
      saveLensIdentifier:self.currentLensOption.identifier];
}

#pragma mark - CameraManagerDelegate

- (void)cameraManager:(CameraManager *)manager
       didChangeState:(CameraState)state {
  dispatch_async(dispatch_get_main_queue(), ^{
    BOOL shouldEnable = (state == CameraStateRunning);

    if ([self.delegate
            respondsToSelector:@selector(shouldUpdateCaptureButtonEnabled:)]) {
      [self.delegate shouldUpdateCaptureButtonEnabled:shouldEnable];
    }
  });
}

- (void)cameraManager:(CameraManager *)manager
      didCapturePhoto:(UIImage *)image
         withMetadata:(NSDictionary *)metadata {
  if (!image) {
    return;
  }
  NSLog(@"📊 [Perf][Capture] didCapture image=%.0fx%.0f mem=%.1fMB",
        image.size.width, image.size.height, CMResidentMemoryMB());
  if ([self.delegate respondsToSelector:@selector(didReceiveCaptureAck)]) {
    [self.delegate didReceiveCaptureAck];
  }

  [self processImage:image
            metadata:metadata
       configuration:self.watermarkConfiguration
           applyCrop:YES
          completion:^(UIImage *_Nullable processedImage,
                       NSError *_Nullable error) {
            if (processedImage) {
              self.latestCapturedImage = processedImage;

              if ([self.delegate respondsToSelector:@selector
                                 (didCapturePhoto:withMetadata:)]) {
                [self.delegate didCapturePhoto:processedImage
                                  withMetadata:metadata];
              }
              if ([self.delegate respondsToSelector:@selector
                                 (shouldShowCaptureFlashEffect)]) {
                [self.delegate shouldShowCaptureFlashEffect];
              }
            }

            if (error && [self.delegate
                             respondsToSelector:@selector(didFailWithError:)]) {
              [self.delegate didFailWithError:error];
            }
          }];
}

- (void)cameraManager:(CameraManager *)manager
     didFailWithError:(NSError *)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(didFailWithError:)]) {
      [self.delegate didFailWithError:error];
    }
  });
}

- (void)cameraManager:(CameraManager *)manager
    didChangeResolutionMode:(CameraResolutionMode)mode {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate
            respondsToSelector:@selector(didChangeResolutionMode:)]) {
      [self.delegate didChangeResolutionMode:mode];
    }
    [self persistCurrentResolutionMode];
  });
}

- (void)cameraManager:(CameraManager *)manager
    didChangeFlashMode:(FlashMode)mode {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(didChangeFlashMode:)]) {
      [self.delegate didChangeFlashMode:mode];
    }
    [self persistFlashMode];
  });
}

- (void)cameraManager:(CameraManager *)manager
    didChangeAspectRatio:(CameraAspectRatio)ratio {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(didChangeAspectRatio:)]) {
      [self.delegate didChangeAspectRatio:ratio];
    }
  });
}

- (void)cameraManager:(CameraManager *)manager
    didChangeDeviceOrientation:(CameraDeviceOrientation)orientation {
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate
            respondsToSelector:@selector(didChangeDeviceOrientation:)]) {
      [self.delegate didChangeDeviceOrientation:orientation];
    }
  });
}

- (void)cameraManager:(CameraManager *)manager
    didUpdateAvailableLenses:(NSArray<CMCameraLensOption *> *)lenses
                 currentLens:(CMCameraLensOption *)currentLens {
  self.availableLensOptions = [lenses copy];
  self.currentLensOption = currentLens ?: self.availableLensOptions.firstObject;
  if ([self.delegate respondsToSelector:@selector
                     (didUpdateAvailableLensOptions:currentLens:)]) {
    [self.delegate didUpdateAvailableLensOptions:self.availableLensOptions
                                     currentLens:self.currentLensOption];
  }

  BOOL hasPendingRestore = self.restoredLensIdentifier.length > 0 &&
                           self.currentLensOption &&
                           ![self.currentLensOption.identifier
                               isEqualToString:self.restoredLensIdentifier];
  if (hasPendingRestore) {
    CMCameraLensOption *targetOption = nil;
    for (CMCameraLensOption *candidate in self.availableLensOptions) {
      if ([candidate.identifier isEqualToString:self.restoredLensIdentifier]) {
        targetOption = candidate;
        break;
      }
    }
    self.restoredLensIdentifier = nil;
    if (targetOption) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self switchToLensOption:targetOption];
      });
      return;
    }
  }

  [self persistCurrentLensSelection];
}

@end
