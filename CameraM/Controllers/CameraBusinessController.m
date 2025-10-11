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
@property(nonatomic, strong) dispatch_queue_t renderQueue;
@property(nonatomic, copy) NSArray<CMCameraLensOption *> *availableLensOptions;
@property(nonatomic, strong) CMCameraLensOption *currentLensOption;
@property(nonatomic, copy) NSString *restoredLensIdentifier;

- (void)persistWatermarkConfiguration;
- (void)loadPersistedWatermarkConfiguration;
- (void)persistCurrentLensSelection;
- (void)loadPersistedSettings;
- (void)persistFlashMode;
- (void)persistGridVisibility;
- (void)persistCurrentResolutionMode;

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
    _renderQueue =
        dispatch_queue_create("com.cameram.render", DISPATCH_QUEUE_SERIAL);
    _availableLensOptions = _captureService.availableLensOptions ?: @[];
    _currentLensOption = _captureService.currentLensOption;
    _restoredLensIdentifier = [[CMSettingsStorage sharedStorage] loadLensIdentifier];
  }
  return self;
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

  dispatch_async(self.renderQueue, ^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }

      UIImage *workingImage = image;
      if (applyCrop) {
        CameraAspectRatio aspectRatio = strongSelf.currentAspectRatio;
        UIImage *croppedImage =
            [strongSelf.captureService cropImage:image
                                   toAspectRatio:aspectRatio];
        if (croppedImage) {
          workingImage = croppedImage;
        }
      } else {
        workingImage = CMNormalizeImageOrientation(image);
      }

      // 应用水印
      CMWatermarkConfiguration *configurationSnapshot =
          configuration ? [configuration copy]
                        : [strongSelf.watermarkConfiguration copy];
      UIImage *renderedImage = workingImage;
      if (configurationSnapshot) {
        UIImage *watermarked =
            [strongSelf.watermarkRenderer renderImage:workingImage
                                    withConfiguration:configurationSnapshot
                                             metadata:metadata];
        if (watermarked) {
          renderedImage = watermarked;
        }
      }

      UIImage *finalImage = renderedImage ?: workingImage;

      [strongSelf.captureService
          saveImageToPhotosLibrary:finalImage
                          metadata:metadata
                        completion:^(BOOL success, NSError *_Nullable error) {
                          if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                              completion(finalImage, error);
                            });
                          } else if (error) {
                            NSLog(@"⚠️ 保存图片失败: %@",
                                  error.localizedDescription);
                          }
                        }];
    }
  });
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
