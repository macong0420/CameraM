//
//  CameraBusinessController.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraBusinessController.h"
#import "../Managers/CMWatermarkRenderer.h"

static NSString *const kCMWatermarkConfigurationStorageKey =
    @"com.cameram.watermark.configuration";
static NSString *const kCMLensSelectionStorageKey =
    @"com.cameram.lens.selection";
static NSString *const kCMFlashModeStorageKey =
    @"com.cameram.flash.mode";
static NSString *const kCMGridVisibilityStorageKey =
    @"com.cameram.grid.visibility";
static NSString *const kCMResolutionModeStorageKey =
    @"com.cameram.resolution.mode";
static NSString *const kCMBusinessControllerErrorDomain =
    @"com.cameram.business";

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

@property(nonatomic, strong) CameraManager *cameraManager;
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
  self = [super init];
  if (self) {
    [self setupCameraManager];
    _isGridLinesVisible = NO;
    _watermarkConfiguration = [CMWatermarkConfiguration defaultConfiguration];
    [self loadPersistedWatermarkConfiguration];
    [self loadPersistedSettings];
    _watermarkRenderer = [[CMWatermarkRenderer alloc] init];
    _renderQueue =
        dispatch_queue_create("com.cameram.render", DISPATCH_QUEUE_SERIAL);
    _availableLensOptions = self.cameraManager.availableLensOptions ?: @[];
    _currentLensOption = self.cameraManager.currentLensOption;
    _restoredLensIdentifier = [[NSUserDefaults standardUserDefaults]
        stringForKey:kCMLensSelectionStorageKey];
  }
  return self;
}

#pragma mark - 私有方法

- (void)setupCameraManager {
  self.cameraManager = [CameraManager sharedManager];
  self.cameraManager.delegate = self;
}

#pragma mark - 状态查询接口

- (CameraResolutionMode)currentResolutionMode {
  return self.cameraManager.currentResolutionMode;
}

- (FlashMode)currentFlashMode {
  return self.cameraManager.currentFlashMode;
}

- (CameraAspectRatio)currentAspectRatio {
  return self.cameraManager.currentAspectRatio;
}

- (CameraDeviceOrientation)currentDeviceOrientation {
  return self.cameraManager.currentDeviceOrientation;
}

- (BOOL)isUltraHighResolutionSupported {
  return self.cameraManager.isUltraHighResolutionSupported;
}

#pragma mark - 相机控制接口

- (void)setupCameraWithPreviewView:(UIView *)previewView
                        completion:
                            (void (^)(BOOL success,
                                      NSError *_Nullable error))completion {
  [self.cameraManager setupCameraWithPreviewView:previewView
                                      completion:completion];
}

- (void)startSession {
  [self.cameraManager startSession];
}

- (void)stopSession {
  [self.cameraManager stopSession];
}

- (void)cleanup {
  [self.cameraManager cleanup];
}

- (void)startOrientationMonitoring {
  [self.cameraManager startDeviceOrientationMonitoring];
}

- (void)stopOrientationMonitoring {
  [self.cameraManager stopDeviceOrientationMonitoring];
}

#pragma mark - 拍摄控制

- (void)capturePhoto {
  [self.cameraManager capturePhoto];
}

- (void)switchCamera {
  [self.cameraManager switchCamera];
}

- (void)switchResolutionMode {
  CameraResolutionMode currentMode = self.cameraManager.currentResolutionMode;
  CameraResolutionMode newMode = (currentMode == CameraResolutionModeStandard)
                                     ? CameraResolutionModeUltraHigh
                                     : CameraResolutionModeStandard;

  if (newMode == CameraResolutionModeUltraHigh &&
      !self.cameraManager.isUltraHighResolutionSupported) {
    return; // 不支持高分辨率
  }

  [self.cameraManager switchResolutionMode:newMode];
}

- (void)switchFlashMode {
  FlashMode currentMode = self.cameraManager.currentFlashMode;
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

  [self.cameraManager switchFlashMode:nextMode];
  [self persistFlashMode];
}

- (void)switchAspectRatio:(CameraAspectRatio)ratio {
  [self.cameraManager switchAspectRatio:ratio];
}

- (void)switchToLensOption:(CMCameraLensOption *)lensOption {
  [self.cameraManager switchToLensOption:lensOption];
}

#pragma mark - 对焦和曝光

- (void)focusAtPoint:(CGPoint)screenPoint
    withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
  // 转换屏幕坐标到设备坐标
  CGPoint devicePoint =
      [previewLayer captureDevicePointOfInterestForPoint:screenPoint];
  [self.cameraManager focusAtPoint:devicePoint];
}

- (void)setExposureCompensation:(float)value {
  [self.cameraManager setExposureCompensation:value];
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
  return [self.cameraManager previewRectForAspectRatio:self.currentAspectRatio
                                            inViewSize:viewSize];
}

- (CGRect)activePreviewRectInViewSize:(CGSize)viewSize {
  return [self.cameraManager previewRectForAspectRatio:self.currentAspectRatio
                                             inViewSize:viewSize];
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
            [strongSelf.cameraManager cropImage:image
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

      [strongSelf.cameraManager
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
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([defaults objectForKey:kCMGridVisibilityStorageKey] != nil) {
    _isGridLinesVisible =
        [defaults boolForKey:kCMGridVisibilityStorageKey];
  } else {
    [self persistGridVisibility];
  }

  if ([defaults objectForKey:kCMFlashModeStorageKey] != nil) {
    NSInteger rawValue = [defaults integerForKey:kCMFlashModeStorageKey];
    FlashMode storedMode = (FlashMode)rawValue;
    if (storedMode < FlashModeAuto || storedMode > FlashModeOff) {
      storedMode = FlashModeAuto;
    }
    if (storedMode != self.cameraManager.currentFlashMode) {
      [self.cameraManager switchFlashMode:storedMode];
    } else {
      [self persistFlashMode];
    }
  } else {
    [self persistFlashMode];
  }

  if ([defaults objectForKey:kCMResolutionModeStorageKey] != nil) {
    NSInteger rawValue = [defaults integerForKey:kCMResolutionModeStorageKey];
    CameraResolutionMode storedMode = (CameraResolutionMode)rawValue;
    if (storedMode == CameraResolutionModeUltraHigh &&
        !self.cameraManager.isUltraHighResolutionSupported) {
      storedMode = CameraResolutionModeStandard;
    }

    if (storedMode != self.cameraManager.currentResolutionMode) {
      [self.cameraManager switchResolutionMode:storedMode];
    } else {
      [self persistCurrentResolutionMode];
    }
  } else {
    [self persistCurrentResolutionMode];
  }
}

- (void)persistFlashMode {
  [[NSUserDefaults standardUserDefaults]
      setInteger:self.cameraManager.currentFlashMode
            forKey:kCMFlashModeStorageKey];
}

- (void)persistGridVisibility {
  [[NSUserDefaults standardUserDefaults]
      setBool:self.isGridLinesVisible
        forKey:kCMGridVisibilityStorageKey];
}

- (void)persistCurrentResolutionMode {
  [[NSUserDefaults standardUserDefaults]
      setInteger:self.cameraManager.currentResolutionMode
            forKey:kCMResolutionModeStorageKey];
}

- (void)persistWatermarkConfiguration {
  if (!self.watermarkConfiguration) {
    return;
  }

  NSError *archiveError = nil;
  NSData *data =
      [NSKeyedArchiver archivedDataWithRootObject:self.watermarkConfiguration
                            requiringSecureCoding:YES
                                            error:&archiveError];
  if (data && !archiveError) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:data forKey:kCMWatermarkConfigurationStorageKey];
  } else if (archiveError) {
    NSLog(@"⚠️ 水印配置存档失败: %@", archiveError.localizedDescription);
  }
}

- (void)loadPersistedWatermarkConfiguration {
  NSData *storedData = [[NSUserDefaults standardUserDefaults]
      objectForKey:kCMWatermarkConfigurationStorageKey];
  if (!storedData) {
    return;
  }

  NSError *unarchiveError = nil;
  CMWatermarkConfiguration *storedConfig = [NSKeyedUnarchiver
      unarchivedObjectOfClass:[CMWatermarkConfiguration class]
                     fromData:storedData
                        error:&unarchiveError];
  if (storedConfig && !unarchiveError) {
    self.watermarkConfiguration = [storedConfig copy];
  } else if (unarchiveError) {
    NSLog(@"⚠️ 水印配置读取失败: %@", unarchiveError.localizedDescription);
  }
}

- (void)persistCurrentLensSelection {
  if (self.currentLensOption.identifier.length == 0) {
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:kCMLensSelectionStorageKey];
    return;
  }
  [[NSUserDefaults standardUserDefaults]
      setObject:self.currentLensOption.identifier
         forKey:kCMLensSelectionStorageKey];
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
