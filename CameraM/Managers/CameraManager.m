//
//  CameraManager.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraManager.h"
#import "../Models/CMCameraLensOption.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <float.h>
#import <math.h>

@interface CameraManager () <AVCapturePhotoCaptureDelegate>

// AVFoundation 核心组件
@property(nonatomic, strong) AVCaptureSession *captureSession;
@property(nonatomic, strong) AVCaptureDevice *currentDevice;
@property(nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property(nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// 状态管理
@property(nonatomic, readwrite) CameraState currentState;
@property(nonatomic, readwrite) CameraPosition currentPosition;
@property(nonatomic, readwrite) CameraResolutionMode currentResolutionMode;
@property(nonatomic, readwrite) FlashMode currentFlashMode;
@property(nonatomic, readwrite) CameraAspectRatio currentAspectRatio;
@property(nonatomic, readwrite)
    CameraDeviceOrientation currentDeviceOrientation;
@property(nonatomic, readwrite) BOOL isUltraHighResolutionSupported;
@property(nonatomic, assign) CameraResolutionMode preferredResolutionMode;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, AVCaptureDeviceFormat *>
        *standardDeviceFormats;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, AVCaptureDeviceFormat *>
        *ultraHighDeviceFormats;

// 方向监听
@property(nonatomic, strong) CMMotionManager *motionManager;

// 性能优化 - 队列管理
@property(nonatomic, strong) dispatch_queue_t sessionQueue;

// 镜头管理
@property(nonatomic, strong)
    NSArray<CMCameraLensOption *> *availableLensOptions;
@property(nonatomic, strong) CMCameraLensOption *currentLensOption;
@property(nonatomic, strong)
    NSDictionary<NSString *, AVCaptureDevice *> *lensDeviceMap;

- (NSArray<AVCaptureDevice *> *)discoverDevicesForPosition:
    (CameraPosition)position;
- (void)rebuildLensOptionsForPosition:(CameraPosition)position
                              devices:(NSArray<AVCaptureDevice *> *)devices
                         shouldNotify:(BOOL)notify;
- (AVCaptureDevice *)deviceForLensOption:(CMCameraLensOption *)lensOption
                                 devices:(NSArray<AVCaptureDevice *> *)devices;
- (void)notifyLensUpdate;
- (CGSize)activeFormatDimensions;
- (BOOL)deviceSupportsUltraHighResolution:(AVCaptureDevice *)device;
- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device;
- (NSString *)formatCacheKeyForDevice:(AVCaptureDevice *)device;
- (AVCaptureDeviceFormat *)standardFormatForDevice:(AVCaptureDevice *)device;
- (AVCaptureDeviceFormat *)ultraHighResolutionFormatForDevice:
    (AVCaptureDevice *)device;
- (AVCaptureDeviceFormat *)findUltraHighResolutionFormatForDevice:
    (AVCaptureDevice *)device;
- (BOOL)applyFormat:(AVCaptureDeviceFormat *)format
           toDevice:(AVCaptureDevice *)device;
- (void)updateUltraHighResolutionSupportForDevice:(AVCaptureDevice *)device;
- (void)applyPreferredResolutionModeLockedWithSupportChanged:
    (BOOL)supportChanged;
- (CMVideoDimensions)maxPhotoDimensionsForFormat:
    (AVCaptureDeviceFormat *)format;
- (void)configureMaxPhotoDimensionsForSettings:
    (AVCapturePhotoSettings *)settings;

@end

@implementation CameraManager

#pragma mark - 单例模式

+ (instancetype)sharedManager {
  static CameraManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[CameraManager alloc] initPrivate];
  });
  return sharedInstance;
}

- (instancetype)initPrivate {
  self = [super init];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)commonInit {
  // 初始化状态
  _currentState = CameraStateIdle;
  _currentPosition = CameraPositionBack;
  _currentResolutionMode = CameraResolutionModeStandard;
  _preferredResolutionMode = CameraResolutionModeStandard;
  _currentFlashMode = FlashModeAuto;
  _currentAspectRatio = CameraAspectRatio4to3; // 默认4:3比例
  _currentDeviceOrientation = CameraDeviceOrientationPortrait; // 默认竖屏
  _availableLensOptions = @[];
  _lensDeviceMap = @{};
  _standardDeviceFormats = [NSMutableDictionary dictionary];
  _ultraHighDeviceFormats = [NSMutableDictionary dictionary];

  // 创建专用队列 - 避免主线程阻塞
  _sessionQueue =
      dispatch_queue_create("com.cameram.session", DISPATCH_QUEUE_SERIAL);

  // 初始化方向监听
  _motionManager = [[CMMotionManager alloc] init];

  // 检查4800万像素支持
  [self checkUltraHighResolutionSupport];
}

#pragma mark - 公开方法

- (void)setupCameraWithPreviewView:(UIView *)previewView
                        completion:
                            (void (^)(BOOL success,
                                      NSError *_Nullable error))completion {

  // 状态检查
  if (self.currentState != CameraStateIdle) {
    NSError *error = [NSError
        errorWithDomain:@"CameraManager"
                   code:1001
               userInfo:@{
                 NSLocalizedDescriptionKey : @"Camera is not in idle state"
               }];
    if (completion)
      completion(NO, error);
    return;
  }

  self.currentState = CameraStateSetup;

  // 异步执行，避免阻塞主线程
  dispatch_async(self.sessionQueue, ^{
    NSError *setupError = nil;
    BOOL success = [self performCameraSetup:&setupError];

    if (success && previewView) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self setupPreviewLayerWithView:previewView];
        [self notifyLensUpdate];
        if (completion)
          completion(YES, nil);
      });
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        self.currentState = CameraStateError;
        if (completion)
          completion(NO, setupError);
      });
    }
  });
}

- (void)startSession {
  dispatch_async(self.sessionQueue, ^{
    if (!self.captureSession.isRunning) {
      [self.captureSession startRunning];
      dispatch_async(dispatch_get_main_queue(), ^{
        self.currentState = CameraStateRunning;
        [self notifyDelegateStateChanged];
      });
    }
  });
}

- (void)stopSession {
  dispatch_async(self.sessionQueue, ^{
    if (self.captureSession.isRunning) {
      [self.captureSession stopRunning];
      dispatch_async(dispatch_get_main_queue(), ^{
        self.currentState = CameraStateStopped;
        [self notifyDelegateStateChanged];
      });
    }
  });
}

- (void)capturePhoto {
  if (self.currentState != CameraStateRunning) {
    return;
  }

  self.currentState = CameraStateCapturing;
  [self notifyDelegateStateChanged];

  dispatch_async(self.sessionQueue, ^{
    AVCaptureConnection *photoConnection =
        [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (photoConnection) {
      if (photoConnection.isVideoOrientationSupported) {
        photoConnection.videoOrientation = [self currentVideoOrientation];
      }
      if (photoConnection.isVideoMirroringSupported) {
        photoConnection.videoMirrored =
            (self.currentPosition == CameraPositionFront);
      }
    }
    AVCapturePhotoSettings *settings = [self createPhotoSettings];
    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
  });
}

- (void)switchCamera {
  dispatch_async(self.sessionQueue, ^{
    // 切换摄像头逻辑
    CameraPosition newPosition = (self.currentPosition == CameraPositionBack)
                                     ? CameraPositionFront
                                     : CameraPositionBack;

    [self.captureSession beginConfiguration];

    // 移除当前输入
    if (self.deviceInput) {
      [self.captureSession removeInput:self.deviceInput];
    }

    NSArray<AVCaptureDevice *> *devices =
        [self discoverDevicesForPosition:newPosition];
    [self rebuildLensOptionsForPosition:newPosition
                                devices:devices
                           shouldNotify:NO];

    AVCaptureDevice *newDevice =
        [self deviceForLensOption:self.currentLensOption devices:devices];
    if (!newDevice) {
      newDevice = devices.firstObject ?: [self cameraWithPosition:newPosition];
    }

    NSError *error = nil;
    AVCaptureDeviceInput *newInput =
        newDevice ? [AVCaptureDeviceInput deviceInputWithDevice:newDevice
                                                          error:&error]
                  : nil;
    if (newInput && [self.captureSession canAddInput:newInput]) {
      [self.captureSession addInput:newInput];
      self.deviceInput = newInput;
      self.currentDevice = newDevice;
      self.currentPosition = newPosition;
      [self primeFormatCachesForDevice:self.currentDevice];
    } else if (error) {
      NSLog(@"⚠️ 切换摄像头失败: %@", error.localizedDescription);
      if (self.deviceInput) {
        [self.captureSession addInput:self.deviceInput];
      }
    }

    [self.captureSession commitConfiguration];

    [self updateUltraHighResolutionSupportForDevice:self.currentDevice];

    [self notifyLensUpdate];
  });
}

- (void)switchResolutionMode:(CameraResolutionMode)mode {
  dispatch_async(self.sessionQueue, ^{
    self.preferredResolutionMode = mode;
    [self applyPreferredResolutionModeLockedWithSupportChanged:NO];
  });
}

- (void)switchFlashMode:(FlashMode)mode {
  // 现代闪光灯控制通过PhotoSettings实现，这里只保存状态
  self.currentFlashMode = mode;

  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(cameraManager:
                                               didChangeFlashMode:)]) {
      [self.delegate cameraManager:self didChangeFlashMode:mode];
    }
  });
}

- (void)switchAspectRatio:(CameraAspectRatio)ratio {
  self.currentAspectRatio = ratio;

  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(cameraManager:
                                              didChangeAspectRatio:)]) {
      [self.delegate cameraManager:self didChangeAspectRatio:ratio];
    }
  });
}

- (void)switchToLensOption:(CMCameraLensOption *)lensOption {
  if (!lensOption) {
    return;
  }

  dispatch_async(self.sessionQueue, ^{
    CMCameraLensOption *targetOption = nil;
    for (CMCameraLensOption *option in self.availableLensOptions) {
      if ([option.identifier isEqualToString:lensOption.identifier]) {
        targetOption = option;
        break;
      }
    }
    if (!targetOption) {
      return;
    }

    AVCaptureDevice *targetDevice =
        self.lensDeviceMap[targetOption.deviceUniqueID];
    if (!targetDevice) {
      NSArray<AVCaptureDevice *> *devices =
          [self discoverDevicesForPosition:self.currentPosition];
      [self rebuildLensOptionsForPosition:self.currentPosition
                                  devices:devices
                             shouldNotify:NO];
      targetOption = nil;
      for (CMCameraLensOption *option in self.availableLensOptions) {
        if ([option.identifier isEqualToString:lensOption.identifier]) {
          targetOption = option;
          break;
        }
      }
      if (!targetOption) {
        return;
      }
      targetDevice = self.lensDeviceMap[targetOption.deviceUniqueID];
    }

    if (!targetDevice ||
        [targetDevice.uniqueID isEqualToString:self.currentDevice.uniqueID]) {
      self.currentLensOption = targetOption;
      [self notifyLensUpdate];
      return;
    }

    NSError *inputError = nil;
    AVCaptureDeviceInput *newInput =
        [AVCaptureDeviceInput deviceInputWithDevice:targetDevice
                                              error:&inputError];
    if (!newInput) {
      NSLog(@"⚠️ 切换镜头失败: %@", inputError.localizedDescription);
      return;
    }

    [self.captureSession beginConfiguration];
    AVCaptureDeviceInput *previousInput = self.deviceInput;
    if (previousInput) {
      [self.captureSession removeInput:previousInput];
    }

    BOOL didAddInput = NO;
    if ([self.captureSession canAddInput:newInput]) {
      [self.captureSession addInput:newInput];
      self.deviceInput = newInput;
      self.currentDevice = targetDevice;
      self.currentLensOption = targetOption;
      [self primeFormatCachesForDevice:self.currentDevice];
      didAddInput = YES;
    } else if (previousInput) {
      [self.captureSession addInput:previousInput];
    }
    [self.captureSession commitConfiguration];

    if (!didAddInput) {
      NSLog(@"⚠️ 切换镜头失败: 无法添加输入");
      return;
    }

    [self updateUltraHighResolutionSupportForDevice:self.currentDevice];

    [self notifyLensUpdate];
  });
}

#pragma mark - 设备方向相关

- (void)startDeviceOrientationMonitoring {
  // 启用设备方向通知
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

  // 注册通知监听
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(deviceOrientationDidChange:)
             name:UIDeviceOrientationDidChangeNotification
           object:nil];

  // 获取当前方向
  [self updateDeviceOrientation:[UIDevice currentDevice].orientation];

  NSLog(@"开始设备方向监听");
}

- (void)stopDeviceOrientationMonitoring {
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIDeviceOrientationDidChangeNotification
              object:nil];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

  NSLog(@"停止设备方向监听");
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
  UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
  [self updateDeviceOrientation:deviceOrientation];
}

- (void)updateDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
  CameraDeviceOrientation newOrientation;

  switch (deviceOrientation) {
  case UIDeviceOrientationPortrait:
    newOrientation = CameraDeviceOrientationPortrait;
    break;
  case UIDeviceOrientationLandscapeLeft:
    newOrientation = CameraDeviceOrientationLandscapeLeft;
    break;
  case UIDeviceOrientationLandscapeRight:
    newOrientation = CameraDeviceOrientationLandscapeRight;
    break;
  default:
    // 忽略其他方向（面朝上、面朝下等）
    return;
  }

  if (newOrientation != self.currentDeviceOrientation) {
    self.currentDeviceOrientation = newOrientation;

    NSLog(@"设备方向变化: %ld", (long)newOrientation);

    // 立即更新预览层方向
    [self updatePreviewLayerOrientation];

    // 通知代理
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                didChangeDeviceOrientation:)]) {
        [self.delegate cameraManager:self
            didChangeDeviceOrientation:newOrientation];
      }
    });
  }
}

// 新增方法：更新预览层方向
- (void)updatePreviewLayerOrientation {
  if (!self.previewLayer || !self.previewLayer.connection) {
    return;
  }

  AVCaptureVideoOrientation videoOrientation = [self currentVideoOrientation];

  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.previewLayer.connection.isVideoOrientationSupported) {
      // 使用CATransaction确保同步更新
      [CATransaction begin];
      [CATransaction setDisableActions:YES]; // 禁用隐式动画
      self.previewLayer.connection.videoOrientation = videoOrientation;
      [CATransaction commit];

      NSLog(@"🔄 预览层方向已更新: %ld, frame: %@", (long)videoOrientation,
            NSStringFromCGRect(self.previewLayer.frame));
    }
  });
}

// 新增方法：获取当前视频方向
- (AVCaptureVideoOrientation)currentVideoOrientation {
  switch (self.currentDeviceOrientation) {
  case CameraDeviceOrientationPortrait:
    return AVCaptureVideoOrientationPortrait;
  case CameraDeviceOrientationLandscapeLeft:
    return AVCaptureVideoOrientationLandscapeRight;
  case CameraDeviceOrientationLandscapeRight:
    return AVCaptureVideoOrientationLandscapeLeft;
  }

  UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationPortrait;

  if (@available(iOS 13.0, *)) {
    UIWindowScene *windowScene =
        (UIWindowScene *)[UIApplication sharedApplication]
            .connectedScenes.anyObject;
    if (windowScene) {
      interfaceOrientation = windowScene.interfaceOrientation;
    }
  }

  switch (interfaceOrientation) {
  case UIInterfaceOrientationPortrait:
    return AVCaptureVideoOrientationPortrait;
  case UIInterfaceOrientationPortraitUpsideDown:
    return AVCaptureVideoOrientationPortraitUpsideDown;
  case UIInterfaceOrientationLandscapeLeft:
    return AVCaptureVideoOrientationLandscapeLeft;
  case UIInterfaceOrientationLandscapeRight:
    return AVCaptureVideoOrientationLandscapeRight;
  default:
    return AVCaptureVideoOrientationPortrait;
  }
}

#pragma mark - 比例相关工具方法

- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio
                     inImageSize:(CGSize)imageSize {
  const CGFloat imageWidth = imageSize.width;
  const CGFloat imageHeight = imageSize.height;

  if (imageWidth <= 0.0f || imageHeight <= 0.0f) {
    return CGRectZero;
  }

  const CGFloat targetAspect =
      [self aspectRatioValueForRatio:ratio
                       inOrientation:self.currentDeviceOrientation];
  if (targetAspect <= 0.0f) {
    return CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);
  }

  const CGFloat imageAspect = imageWidth / imageHeight;
  CGRect cropRect = CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);

  if (fabs(imageAspect - targetAspect) < 0.0001f) {
    return CGRectIntegral(cropRect);
  }

  if (imageAspect > targetAspect) {
    // 图像比目标更宽，需要裁剪左右两侧
    const CGFloat targetWidth = imageHeight * targetAspect;
    const CGFloat xOffset = (imageWidth - targetWidth) / 2.0f;
    cropRect = CGRectMake(xOffset, 0.0f, targetWidth, imageHeight);
  } else {
    // 图像比目标更窄（或更高），裁剪上下
    const CGFloat targetHeight = imageWidth / targetAspect;
    const CGFloat yOffset = (imageHeight - targetHeight) / 2.0f;
    cropRect = CGRectMake(0.0f, yOffset, imageWidth, targetHeight);
  }

  NSLog(@"裁剪区域: %@, 原图尺寸: %.0fx%.0f, 目标比例: %.3f",
        NSStringFromCGRect(cropRect), imageWidth, imageHeight, targetAspect);
  return CGRectIntegral(cropRect);
}

- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio {
  if (!image)
    return nil;

  NSLog(@"原始图像信息 - 尺寸: (%.0fx%.0f), 方向: %ld, 比例目标: %ld",
        image.size.width, image.size.height, (long)image.imageOrientation,
        (long)ratio);

  // 第一步：将图像标准化为UIImageOrientationUp方向
  UIImage *normalizedImage = [self normalizeImageOrientation:image];

  NSLog(@"标准化后图像 - 尺寸: (%.0fx%.0f), 方向: %ld",
        normalizedImage.size.width, normalizedImage.size.height,
        (long)normalizedImage.imageOrientation);

  // 第二步：在标准化的图像上进行裁剪
  CGRect cropRect = [self cropRectForAspectRatio:ratio
                                     inImageSize:normalizedImage.size];

  NSLog(@"计算的裁剪区域: (%.0f, %.0f, %.0f, %.0f)", cropRect.origin.x,
        cropRect.origin.y, cropRect.size.width, cropRect.size.height);

  // 第三步：执行裁剪
  CGImageRef croppedCGImage =
      CGImageCreateWithImageInRect(normalizedImage.CGImage, cropRect);
  if (!croppedCGImage) {
    NSLog(@"裁剪失败，返回原图");
    return image;
  }

  UIImage *croppedImage = [UIImage imageWithCGImage:croppedCGImage];
  CGImageRelease(croppedCGImage);

  NSLog(@"最终裁剪结果 - 尺寸: (%.0fx%.0f), 实际比例: %.2f:1",
        croppedImage.size.width, croppedImage.size.height,
        croppedImage.size.width / croppedImage.size.height);

  return croppedImage;
}

// 新增方法：标准化图像方向
- (UIImage *)normalizeImageOrientation:(UIImage *)image {
  if (image.imageOrientation == UIImageOrientationUp) {
    return image; // 已经是标准方向
  }

  CGSize size = image.size;
  UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
  [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return normalizedImage ? normalizedImage : image;
}

- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio {
  return [self aspectRatioValueForRatio:ratio
                          inOrientation:self.currentDeviceOrientation];
}

- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio
                      inOrientation:(CameraDeviceOrientation)orientation {
  BOOL isPortrait = (orientation == CameraDeviceOrientationPortrait);

  switch (ratio) {
  case CameraAspectRatio4to3:
    // 竖屏: 3:4 (0.75), 横屏: 4:3 (1.33)
    return isPortrait ? (3.0f / 4.0f) : (4.0f / 3.0f);
  case CameraAspectRatio1to1:
    // 正方形在任何方向都是1:1
    return 1.0f;
  case CameraAspectRatioXpan:
    // 竖屏: 24:65 (0.37), 横屏: 65:24 (2.7)
    return isPortrait ? (24.0f / 65.0f) : (65.0f / 24.0f);
  }
  return 1.0f;
}

- (CGSize)activeFormatDimensions {
  AVCaptureDevice *device = self.currentDevice ?: self.deviceInput.device;
  if (!device) {
    return CGSizeZero;
  }

  CMFormatDescriptionRef description = device.activeFormat.formatDescription;
  if (!description) {
    return CGSizeZero;
  }

  CMVideoDimensions dimensions =
      CMVideoFormatDescriptionGetDimensions(description);
  if (dimensions.width <= 0 || dimensions.height <= 0) {
    return CGSizeZero;
  }

  return CGSizeMake(dimensions.width, dimensions.height);
}

- (CGRect)previewRectForAspectRatio:(CameraAspectRatio)ratio
                         inViewSize:(CGSize)viewSize {
  const CGFloat viewWidth = viewSize.width;
  const CGFloat viewHeight = viewSize.height;

  if (viewWidth <= 0.0f || viewHeight <= 0.0f) {
    return CGRectZero;
  }

  const CGFloat targetAspect =
      [self aspectRatioValueForRatio:ratio
                       inOrientation:self.currentDeviceOrientation];
  const CGFloat viewAspect = viewWidth / viewHeight;

  CGRect rect = CGRectMake(0.0f, 0.0f, viewWidth, viewHeight);

  if (fabs(viewAspect - targetAspect) < 0.0001f) {
    return CGRectIntegral(rect);
  }

  if (viewAspect > targetAspect) {
    const CGFloat targetWidth = viewHeight * targetAspect;
    const CGFloat xOffset = (viewWidth - targetWidth) / 2.0f;
    rect = CGRectMake(xOffset, 0.0f, targetWidth, viewHeight);
  } else {
    const CGFloat targetHeight = viewWidth / targetAspect;
    const CGFloat yOffset = (viewHeight - targetHeight) / 2.0f;
    rect = CGRectMake(0.0f, yOffset, viewWidth, targetHeight);
  }

  return CGRectIntegral(rect);
}

- (CGRect)activeFormatPreviewRectInViewSize:(CGSize)viewSize {
  const CGFloat viewWidth = viewSize.width;
  const CGFloat viewHeight = viewSize.height;

  if (viewWidth <= 0.0f || viewHeight <= 0.0f) {
    return CGRectZero;
  }

  CGSize activeDimensions = [self activeFormatDimensions];
  if (activeDimensions.width <= 0.0f || activeDimensions.height <= 0.0f) {
    return CGRectIntegral(CGRectMake(0.0f, 0.0f, viewWidth, viewHeight));
  }

  CGRect boundingRect = CGRectMake(0.0f, 0.0f, viewWidth, viewHeight);
  CGRect videoRect =
      AVMakeRectWithAspectRatioInsideRect(activeDimensions, boundingRect);
  return CGRectIntegral(videoRect);
}

- (void)focusAtPoint:(CGPoint)point {
  dispatch_async(self.sessionQueue, ^{
    if (self.currentDevice &&
        [self.currentDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
      NSError *error = nil;

      if ([self.currentDevice lockForConfiguration:&error]) {
        // 设置对焦点
        if ([self.currentDevice isFocusPointOfInterestSupported]) {
          self.currentDevice.focusPointOfInterest = point;
          self.currentDevice.focusMode = AVCaptureFocusModeAutoFocus;
        }

        // 设置曝光点
        if ([self.currentDevice isExposurePointOfInterestSupported]) {
          self.currentDevice.exposurePointOfInterest = point;
          self.currentDevice.exposureMode = AVCaptureExposureModeAutoExpose;
        }

        [self.currentDevice unlockForConfiguration];

        NSLog(@"对焦设置成功: (%.2f, %.2f)", point.x, point.y);
      } else {
        NSLog(@"对焦设置失败: %@", error.localizedDescription);
      }
    }
  });
}

- (void)setExposureCompensation:(float)value {
  dispatch_async(self.sessionQueue, ^{
    if (self.currentDevice) {
      NSError *error = nil;

      if ([self.currentDevice lockForConfiguration:&error]) {
        // 限制曝光补偿范围
        float minEV = self.currentDevice.minExposureTargetBias;
        float maxEV = self.currentDevice.maxExposureTargetBias;
        float clampedValue = MAX(minEV, MIN(maxEV, value));

        [self.currentDevice
            setExposureTargetBias:clampedValue
                completionHandler:^(CMTime syncTime) {
                  NSLog(@"曝光补偿设置成功: %.1f", clampedValue);
                }];

        [self.currentDevice unlockForConfiguration];
      } else {
        NSLog(@"曝光补偿设置失败: %@", error.localizedDescription);
      }
    }
  });
}

#pragma mark - 私有方法

#pragma mark 镜头管理

- (NSArray<AVCaptureDevice *> *)discoverDevicesForPosition:
    (CameraPosition)position {
  AVCaptureDevicePosition avPosition = (position == CameraPositionBack)
                                           ? AVCaptureDevicePositionBack
                                           : AVCaptureDevicePositionFront;
  NSMutableArray<AVCaptureDeviceType> *deviceTypes = [NSMutableArray array];

  if (position == CameraPositionBack) {
    [deviceTypes addObjectsFromArray:@[
      AVCaptureDeviceTypeBuiltInWideAngleCamera,
      AVCaptureDeviceTypeBuiltInUltraWideCamera,
      AVCaptureDeviceTypeBuiltInTelephotoCamera
    ]];
  } else {
    [deviceTypes addObject:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    if (@available(iOS 13.0, *)) {
      [deviceTypes addObject:AVCaptureDeviceTypeBuiltInTrueDepthCamera];
    }
  }

  AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
      discoverySessionWithDeviceTypes:deviceTypes
                            mediaType:AVMediaTypeVideo
                             position:avPosition];
  NSMutableArray<AVCaptureDevice *> *uniqueDevices = [NSMutableArray array];
  NSMutableSet<NSString *> *seenIDs = [NSMutableSet set];
  for (AVCaptureDevice *device in session.devices) {
    if (![seenIDs containsObject:device.uniqueID]) {
      [uniqueDevices addObject:device];
      [seenIDs addObject:device.uniqueID];
    }
  }

  if (uniqueDevices.count == 0) {
    AVCaptureDevice *fallback = [self cameraWithPosition:position];
    if (fallback) {
      [uniqueDevices addObject:fallback];
    }
  }
  return [uniqueDevices copy];
}

- (CGFloat)canonicalZoomForDevice:(AVCaptureDevice *)device
                        reference:(AVCaptureDevice *)referenceDevice {
  if (device.position == AVCaptureDevicePositionFront) {
    return 1.0f;
  }

  CGFloat referenceFOV = referenceDevice.activeFormat.videoFieldOfView;
  CGFloat targetFOV = device.activeFormat.videoFieldOfView;
  CGFloat rawZoom = (referenceFOV > 0.0f && targetFOV > 0.0f)
                        ? (referenceFOV / targetFOV)
                        : 1.0f;

  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInUltraWideCamera]) {
    return 0.5f;
  }
  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
    return 1.0f;
  }
  if ([device.deviceType
          isEqualToString:AVCaptureDeviceTypeBuiltInTelephotoCamera]) {
    if (rawZoom >= 4.5f) {
      return 5.0f;
    }
    if (rawZoom >= 2.7f) {
      return 3.0f;
    }
    if (rawZoom >= 1.6f) {
      return 2.0f;
    }
    return MAX(1.5f, rawZoom);
  }
  return MAX(0.1f, rawZoom);
}

- (NSString *)titleForZoomFactor:(CGFloat)zoomFactor {
  CGFloat rounded = zoomFactor;
  if (zoomFactor < 0.8f) {
    rounded = 0.5f;
  } else if (fabs(zoomFactor - 1.0f) < 0.15f) {
    rounded = 1.0f;
  } else if (fabs(zoomFactor - 2.0f) < 0.4f) {
    rounded = 2.0f;
  } else if (fabs(zoomFactor - 3.0f) < 0.5f) {
    rounded = 3.0f;
  } else if (fabs(zoomFactor - 5.0f) < 0.6f) {
    rounded = 5.0f;
  } else {
    rounded = roundf(zoomFactor * 10.0f) / 10.0f;
  }

  if (fabs(rounded - roundf(rounded)) < 0.05f) {
    return [NSString stringWithFormat:@"%.0fx", roundf(rounded)];
  }
  return [NSString stringWithFormat:@"%.1fx", rounded];
}

- (void)rebuildLensOptionsForPosition:(CameraPosition)position
                              devices:(NSArray<AVCaptureDevice *> *)devices
                         shouldNotify:(BOOL)notify {
  if (devices.count == 0) {
    self.availableLensOptions = @[];
    self.lensDeviceMap = @{};
    self.currentLensOption = nil;
    if (notify) {
      [self notifyLensUpdate];
    }
    return;
  }

  AVCaptureDevice *referenceDevice = nil;
  if (position == CameraPositionBack) {
    for (AVCaptureDevice *device in devices) {
      if ([device.deviceType
              isEqualToString:AVCaptureDeviceTypeBuiltInWideAngleCamera]) {
        referenceDevice = device;
        break;
      }
    }
  }
  if (!referenceDevice) {
    referenceDevice = devices.firstObject;
  }

  NSMutableArray<CMCameraLensOption *> *options = [NSMutableArray array];
  NSMutableDictionary<NSString *, AVCaptureDevice *> *deviceMap =
      [NSMutableDictionary dictionary];

  for (AVCaptureDevice *device in devices) {
    CGFloat zoom = [self canonicalZoomForDevice:device
                                      reference:referenceDevice];
    NSString *title = [self titleForZoomFactor:zoom];
    NSString *identifier =
        [NSString stringWithFormat:@"lens.%@", device.uniqueID];
    CMCameraLensOption *option =
        [CMCameraLensOption optionWithIdentifier:identifier
                                     displayName:title
                                      zoomFactor:zoom
                                  deviceUniqueID:device.uniqueID];
    [options addObject:option];
    if (device.uniqueID) {
      deviceMap[device.uniqueID] = device;
    }
  }

  [options sortUsingComparator:^NSComparisonResult(CMCameraLensOption *obj1,
                                                   CMCameraLensOption *obj2) {
    if (obj1.zoomFactor < obj2.zoomFactor) {
      return NSOrderedAscending;
    }
    if (obj1.zoomFactor > obj2.zoomFactor) {
      return NSOrderedDescending;
    }
    return [obj1.displayName compare:obj2.displayName];
  }];

  self.availableLensOptions = [options copy];
  self.lensDeviceMap = [deviceMap copy];

  CMCameraLensOption *selected = nil;
  if (self.currentLensOption) {
    for (CMCameraLensOption *candidate in self.availableLensOptions) {
      if ([candidate.identifier
              isEqualToString:self.currentLensOption.identifier]) {
        selected = candidate;
        break;
      }
    }
  }

  if (!selected) {
    CGFloat closestDiff = CGFLOAT_MAX;
    for (CMCameraLensOption *candidate in self.availableLensOptions) {
      CGFloat diff = fabs(candidate.zoomFactor - 1.0f);
      if (diff < closestDiff) {
        closestDiff = diff;
        selected = candidate;
      }
    }
  }
  if (!selected) {
    selected = self.availableLensOptions.firstObject;
  }
  self.currentLensOption = selected;

  if (notify) {
    [self notifyLensUpdate];
  }
}

- (AVCaptureDevice *)deviceForLensOption:(CMCameraLensOption *)lensOption
                                 devices:(NSArray<AVCaptureDevice *> *)devices {
  if (!lensOption) {
    return nil;
  }
  if (lensOption.deviceUniqueID.length > 0) {
    AVCaptureDevice *mappedDevice =
        self.lensDeviceMap[lensOption.deviceUniqueID];
    if (mappedDevice) {
      return mappedDevice;
    }
  }
  for (AVCaptureDevice *device in devices) {
    if ([device.uniqueID isEqualToString:lensOption.deviceUniqueID]) {
      return device;
    }
  }
  return devices.firstObject;
}

- (void)notifyLensUpdate {
  NSArray<CMCameraLensOption *> *lensSnapshot =
      [[NSArray alloc] initWithArray:self.availableLensOptions copyItems:YES];
  CMCameraLensOption *currentSnapshot = [self.currentLensOption copy];
  if (!lensSnapshot) {
    lensSnapshot = @[];
  }
  if (!currentSnapshot && lensSnapshot.count > 0) {
    currentSnapshot = [lensSnapshot.firstObject copy];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector
                       (cameraManager:didUpdateAvailableLenses:currentLens:)]) {
      [self.delegate cameraManager:self
          didUpdateAvailableLenses:lensSnapshot
                       currentLens:currentSnapshot];
    }
  });
}

- (BOOL)performCameraSetup:(NSError **)error {
  // 创建capture session
  self.captureSession = [[AVCaptureSession alloc] init];

  // 设置session preset - 性能优化
  if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
    [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
  }

  NSArray<AVCaptureDevice *> *availableDevices =
      [self discoverDevicesForPosition:self.currentPosition];
  [self rebuildLensOptionsForPosition:self.currentPosition
                              devices:availableDevices
                         shouldNotify:NO];

  self.currentDevice = [self deviceForLensOption:self.currentLensOption
                                         devices:availableDevices];
  if (!self.currentDevice) {
    self.currentDevice = availableDevices.firstObject
                             ?: [self cameraWithPosition:self.currentPosition];
  }
  if (!self.currentDevice) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"CameraManager"
                     code:1002
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"No camera device available"
                 }];
    }
    return NO;
  }

  // 创建设备输入
  NSError *inputError = nil;
  self.deviceInput =
      [AVCaptureDeviceInput deviceInputWithDevice:self.currentDevice
                                            error:&inputError];
  if (!self.deviceInput) {
    if (error)
      *error = inputError;
    return NO;
  }

  // 添加输入到session
  if ([self.captureSession canAddInput:self.deviceInput]) {
    [self.captureSession addInput:self.deviceInput];
  } else {
    if (error) {
      *error = [NSError
          errorWithDomain:@"CameraManager"
                     code:1003
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Cannot add camera input"
                 }];
    }
    return NO;
  }

  [self primeFormatCachesForDevice:self.currentDevice];

  // 创建照片输出
  self.photoOutput = [[AVCapturePhotoOutput alloc] init];
  if ([self.captureSession canAddOutput:self.photoOutput]) {
    [self.captureSession addOutput:self.photoOutput];
    self.photoOutput.highResolutionCaptureEnabled = YES;
    [self
        configurePhotoOutputForResolutionMode:self.currentResolutionMode
                                   withFormat:self.currentDevice.activeFormat];
  } else {
    if (error) {
      *error = [NSError
          errorWithDomain:@"CameraManager"
                     code:1004
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Cannot add photo output"
                 }];
    }
    return NO;
  }

  [self updateUltraHighResolutionSupportForDevice:self.currentDevice];

  return YES;
}

- (void)setupPreviewLayerWithView:(UIView *)view {
  self.previewLayer =
      [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
  self.previewLayer.frame = view.bounds;
  self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  [view.layer insertSublayer:self.previewLayer atIndex:0];

  // 设置初始方向
  [self updatePreviewLayerOrientation];

  NSLog(@"📱 预览层初始化完成，frame: %@",
        NSStringFromCGRect(self.previewLayer.frame));
}

- (AVCaptureDevice *)cameraWithPosition:(CameraPosition)position {
  AVCaptureDevicePosition avPosition = (position == CameraPositionBack)
                                           ? AVCaptureDevicePositionBack
                                           : AVCaptureDevicePositionFront;

  // 优先使用多摄像头系统
  AVCaptureDeviceDiscoverySession *discoverySession =
      [AVCaptureDeviceDiscoverySession
          discoverySessionWithDeviceTypes:@[
            AVCaptureDeviceTypeBuiltInTripleCamera,
            AVCaptureDeviceTypeBuiltInDualWideCamera,
            AVCaptureDeviceTypeBuiltInWideAngleCamera
          ]
                                mediaType:AVMediaTypeVideo
                                 position:avPosition];

  return discoverySession.devices.firstObject;
}

- (void)checkUltraHighResolutionSupport {
  AVCaptureDevice *backCamera = [self cameraWithPosition:CameraPositionBack];
  [self primeFormatCachesForDevice:backCamera];
  BOOL supported = [self deviceSupportsUltraHighResolution:backCamera];
  self.isUltraHighResolutionSupported = supported;
  if (!supported) {
    self.preferredResolutionMode = CameraResolutionModeStandard;
    self.currentResolutionMode = CameraResolutionModeStandard;
  }
}

- (void)configurePhotoOutputForResolutionMode:(CameraResolutionMode)mode
                                   withFormat:(AVCaptureDeviceFormat *)format {
  if (!self.photoOutput) {
    return;
  }

  if (@available(iOS 17.0, *)) {
    CMVideoDimensions dimensions = [self maxPhotoDimensionsForFormat:format];
    if (dimensions.width > 0 && dimensions.height > 0) {
      self.photoOutput.maxPhotoDimensions = dimensions;
    }
  }

  if (@available(iOS 16.0, *)) {
    if (mode == CameraResolutionModeUltraHigh &&
        self.isUltraHighResolutionSupported) {
      self.photoOutput.maxPhotoQualityPrioritization =
          AVCapturePhotoQualityPrioritizationQuality;
    } else {
      self.photoOutput.maxPhotoQualityPrioritization =
          AVCapturePhotoQualityPrioritizationBalanced;
    }
  }

  if (@available(iOS 11.0, *)) {
    self.photoOutput.highResolutionCaptureEnabled = YES;
  }
}

#pragma mark - 分辨率管理

- (BOOL)deviceSupportsUltraHighResolution:(AVCaptureDevice *)device {
  if (!device) {
    return NO;
  }
  return ([self ultraHighResolutionFormatForDevice:device] != nil);
}

- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return;
  }
  [self standardFormatForDevice:device];
  [self ultraHighResolutionFormatForDevice:device];
}

- (CMVideoDimensions)maxPhotoDimensionsForFormat:
    (AVCaptureDeviceFormat *)format {
  if (!format) {
    return (CMVideoDimensions){0, 0};
  }

  CMVideoDimensions bestDimensions = format.highResolutionStillImageDimensions;

  if (@available(iOS 17.0, *)) {
    for (NSValue *value in format.supportedMaxPhotoDimensions) {
      CMVideoDimensions candidate = {0, 0};
      [value getValue:&candidate];
      int64_t candidatePixels =
          (int64_t)candidate.width * (int64_t)candidate.height;
      int64_t bestPixels =
          (int64_t)bestDimensions.width * (int64_t)bestDimensions.height;
      if (candidatePixels > bestPixels) {
        bestDimensions = candidate;
      }
    }
  }

  if (bestDimensions.width <= 0 || bestDimensions.height <= 0) {
    bestDimensions =
        CMVideoFormatDescriptionGetDimensions(format.formatDescription);
  }

  return bestDimensions;
}

- (void)configureMaxPhotoDimensionsForSettings:
    (AVCapturePhotoSettings *)settings {
  if (!settings) {
    return;
  }

  if (@available(iOS 17.0, *)) {
    CMVideoDimensions targetDimensions = self.photoOutput.maxPhotoDimensions;

    if ((targetDimensions.width <= 0 || targetDimensions.height <= 0) &&
        self.currentDevice.activeFormat) {
      targetDimensions =
          [self maxPhotoDimensionsForFormat:self.currentDevice.activeFormat];
    }

    if (targetDimensions.width > 0 && targetDimensions.height > 0) {
      settings.maxPhotoDimensions = targetDimensions;
    }
  }
}

- (NSString *)formatCacheKeyForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }
  NSString *uniqueID = device.uniqueID;
  if (uniqueID.length > 0) {
    return uniqueID;
  }
  return [NSString stringWithFormat:@"%p", device];
}

- (AVCaptureDeviceFormat *)standardFormatForDevice:(AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }
  NSString *key = [self formatCacheKeyForDevice:device];
  if (key.length == 0) {
    return device.activeFormat;
  }
  AVCaptureDeviceFormat *cached = self.standardDeviceFormats[key];
  if (!cached) {
    AVCaptureDeviceFormat *active = device.activeFormat;
    if (active) {
      self.standardDeviceFormats[key] = active;
      cached = active;
    }
  }
  return cached ?: device.activeFormat;
}

- (AVCaptureDeviceFormat *)ultraHighResolutionFormatForDevice:
    (AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }
  NSString *key = [self formatCacheKeyForDevice:device];
  if (key.length == 0) {
    return [self findUltraHighResolutionFormatForDevice:device];
  }
  AVCaptureDeviceFormat *cached = self.ultraHighDeviceFormats[key];
  if (!cached) {
    cached = [self findUltraHighResolutionFormatForDevice:device];
    if (cached) {
      self.ultraHighDeviceFormats[key] = cached;
    }
  }
  return cached;
}

- (AVCaptureDeviceFormat *)findUltraHighResolutionFormatForDevice:
    (AVCaptureDevice *)device {
  if (!device) {
    return nil;
  }

  AVCaptureDeviceFormat *bestFormat = nil;
  int64_t bestPixelCount = 0;
  CGFloat bestAspectPenalty = CGFLOAT_MAX;

  for (AVCaptureDeviceFormat *format in device.formats) {
    CMVideoDimensions stillDimensions =
        [self maxPhotoDimensionsForFormat:format];
    if (stillDimensions.width <= 0 || stillDimensions.height <= 0) {
      continue;
    }

    int64_t pixelCount =
        (int64_t)stillDimensions.width * (int64_t)stillDimensions.height;
    if (pixelCount < 40000000) { // 约4000万像素以上再考虑，48MP约为8064x6048
      continue;
    }

    CGFloat aspect =
        (CGFloat)stillDimensions.width / (CGFloat)stillDimensions.height;
    CGFloat penalty = fabs(aspect - (4.0f / 3.0f));

    if (!bestFormat || pixelCount > bestPixelCount ||
        (pixelCount == bestPixelCount && penalty < bestAspectPenalty)) {
      bestFormat = format;
      bestPixelCount = pixelCount;
      bestAspectPenalty = penalty;
    }
  }

  return bestFormat;
}

- (BOOL)applyFormat:(AVCaptureDeviceFormat *)format
           toDevice:(AVCaptureDevice *)device {
  if (!device || !format) {
    return NO;
  }

  if (device.activeFormat == format) {
    return NO;
  }

  NSError *configurationError = nil;
  if (![device lockForConfiguration:&configurationError]) {
    NSLog(@"⚠️ 无法锁定设备配置: %@", configurationError.localizedDescription);
    return NO;
  }

  CGFloat previousZoom = device.videoZoomFactor;
  device.activeFormat = format;

  CGFloat minZoom = device.minAvailableVideoZoomFactor;
  CGFloat maxZoom = device.maxAvailableVideoZoomFactor;
  CGFloat clampedZoom = MIN(MAX(previousZoom, minZoom), maxZoom);
  if (fabs(clampedZoom - previousZoom) > 0.001f) {
    device.videoZoomFactor = clampedZoom;
  }

  [device unlockForConfiguration];
  return YES;
}

- (void)updateUltraHighResolutionSupportForDevice:(AVCaptureDevice *)device {
  BOOL previousSupport = self.isUltraHighResolutionSupported;
  [self primeFormatCachesForDevice:device];
  BOOL currentSupport = [self deviceSupportsUltraHighResolution:device];
  self.isUltraHighResolutionSupported = currentSupport;

  BOOL supportChanged = (previousSupport != currentSupport);
  [self applyPreferredResolutionModeLockedWithSupportChanged:supportChanged];
}

- (void)applyPreferredResolutionModeLockedWithSupportChanged:
    (BOOL)supportChanged {
  CameraResolutionMode desiredMode = self.preferredResolutionMode;
  CameraResolutionMode resolvedMode = desiredMode;
  AVCaptureDevice *device = self.currentDevice;

  BOOL requestedUltra = (desiredMode == CameraResolutionModeUltraHigh);
  BOOL fallbackDueToSupport = NO;

  if (requestedUltra && !self.isUltraHighResolutionSupported) {
    fallbackDueToSupport = YES;
    resolvedMode = CameraResolutionModeStandard;
  }

  if (!self.captureSession || !self.photoOutput || !device) {
    self.currentResolutionMode = resolvedMode;
    return;
  }

  [self primeFormatCachesForDevice:device];

  AVCaptureDeviceFormat *targetFormat = nil;
  if (resolvedMode == CameraResolutionModeUltraHigh) {
    targetFormat = [self ultraHighResolutionFormatForDevice:device];
    if (!targetFormat) {
      fallbackDueToSupport = YES;
      resolvedMode = CameraResolutionModeStandard;
    }
  }

  if (resolvedMode == CameraResolutionModeStandard) {
    targetFormat = [self standardFormatForDevice:device];
  }

  if (!targetFormat) {
    targetFormat = device.activeFormat;
  }

  BOOL didChangeMode = (self.currentResolutionMode != resolvedMode);
  BOOL alreadyUsingTargetFormat = (device.activeFormat == targetFormat);

  if (!didChangeMode && alreadyUsingTargetFormat) {
    self.currentResolutionMode = resolvedMode;
    if (supportChanged) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                  didChangeResolutionMode:)]) {
          [self.delegate cameraManager:self
               didChangeResolutionMode:self.currentResolutionMode];
        }
      });
    }
    return;
  }

  [self.captureSession beginConfiguration];
  BOOL formatChanged = [self applyFormat:targetFormat toDevice:device];
  AVCaptureDeviceFormat *appliedFormat =
      formatChanged ? targetFormat : device.activeFormat;
  BOOL formatApplied = (appliedFormat == targetFormat);
  if (resolvedMode == CameraResolutionModeUltraHigh && !formatApplied) {
    fallbackDueToSupport = YES;
    resolvedMode = CameraResolutionModeStandard;
  }
  [self configurePhotoOutputForResolutionMode:resolvedMode
                                   withFormat:appliedFormat];
  [self.captureSession commitConfiguration];

  BOOL finalModeChanged = (self.currentResolutionMode != resolvedMode);
  self.currentResolutionMode = resolvedMode;

  if (resolvedMode == CameraResolutionModeStandard && appliedFormat) {
    NSString *cacheKey = [self formatCacheKeyForDevice:device];
    if (cacheKey.length > 0) {
      self.standardDeviceFormats[cacheKey] = appliedFormat;
    }
  }

  if (resolvedMode == CameraResolutionModeUltraHigh) {
    NSLog(@"✅ 已启用4800万像素模式");
  } else if (requestedUltra &&
             (finalModeChanged || formatChanged || fallbackDueToSupport)) {
    NSLog(@"⚠️ 当前镜头不支持4800万像素，回退到标准分辨率");
  }

  if (supportChanged || finalModeChanged || formatChanged) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                didChangeResolutionMode:)]) {
        [self.delegate cameraManager:self
             didChangeResolutionMode:self.currentResolutionMode];
      }
    });
  }
}

- (AVCapturePhotoSettings *)createPhotoSettings {
  AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];

  // 4800万像素模式配置
  if (self.currentResolutionMode == CameraResolutionModeUltraHigh &&
      self.isUltraHighResolutionSupported) {
    if (@available(iOS 16.0, *)) {
      settings.photoQualityPrioritization =
          AVCapturePhotoQualityPrioritizationQuality;
    }
    if (@available(iOS 11.0, *)) {
      settings.highResolutionPhotoEnabled = YES;
    }
  } else {
    if (@available(iOS 16.0, *)) {
      settings.photoQualityPrioritization =
          AVCapturePhotoQualityPrioritizationBalanced;
    }
    if (@available(iOS 11.0, *)) {
      settings.highResolutionPhotoEnabled = NO;
    }
  }

  // 应用闪光灯设置
  if (self.currentDevice && [self.currentDevice hasFlash]) {
    switch (self.currentFlashMode) {
    case FlashModeAuto:
      settings.flashMode = AVCaptureFlashModeAuto;
      break;
    case FlashModeOn:
      settings.flashMode = AVCaptureFlashModeOn;
      break;
    case FlashModeOff:
      settings.flashMode = AVCaptureFlashModeOff;
      break;
    }
  }

  // 启用高质量拍摄
  if ([self.photoOutput.availablePhotoCodecTypes
          containsObject:AVVideoCodecTypeHEVC]) {
    settings = [AVCapturePhotoSettings
        photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeHEVC}];

    // 重新应用闪光灯设置
    if (self.currentDevice && [self.currentDevice hasFlash]) {
      switch (self.currentFlashMode) {
      case FlashModeAuto:
        settings.flashMode = AVCaptureFlashModeAuto;
        break;
      case FlashModeOn:
        settings.flashMode = AVCaptureFlashModeOn;
        break;
      case FlashModeOff:
        settings.flashMode = AVCaptureFlashModeOff;
        break;
      }
    }

    // 重新应用分辨率设置
    if (self.currentResolutionMode == CameraResolutionModeUltraHigh &&
        self.isUltraHighResolutionSupported) {
      if (@available(iOS 16.0, *)) {
        settings.photoQualityPrioritization =
            AVCapturePhotoQualityPrioritizationQuality;
      }
      if (@available(iOS 11.0, *)) {
        settings.highResolutionPhotoEnabled = YES;
      }
    } else {
      if (@available(iOS 16.0, *)) {
        settings.photoQualityPrioritization =
            AVCapturePhotoQualityPrioritizationBalanced;
      }
      if (@available(iOS 11.0, *)) {
        settings.highResolutionPhotoEnabled = NO;
      }
    }
  }

  [self configureMaxPhotoDimensionsForSettings:settings];

  return settings;
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhoto:(AVCapturePhoto *)photo
                       error:(NSError *)error {

  dispatch_async(dispatch_get_main_queue(), ^{
    self.currentState = CameraStateRunning;
    [self notifyDelegateStateChanged];

    if (error) {
      if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                   didFailWithError:)]) {
        [self.delegate cameraManager:self didFailWithError:error];
      }
      return;
    }

    NSData *imageData = photo.fileDataRepresentation;
    if (imageData) {
      UIImage *image = [UIImage imageWithData:imageData];
      NSDictionary *metadata = photo.metadata;

      if ([self.delegate respondsToSelector:@selector
                         (cameraManager:didCapturePhoto:withMetadata:)]) {
        [self.delegate cameraManager:self
                     didCapturePhoto:image
                        withMetadata:metadata];
      }
    }
  });
}

#pragma mark - 相册保存

- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(NSDictionary *)metadata
                      completion:
                          (void (^)(BOOL success,
                                    NSError *_Nullable error))completion {
  if (!image) {
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(NO,
                   [NSError errorWithDomain:@"CameraManager"
                                       code:2001
                                   userInfo:@{
                                     NSLocalizedDescriptionKey : @"Image is nil"
                                   }]);
      });
    }
    return;
  }

  [PHPhotoLibrary
      requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                 handler:^(PHAuthorizationStatus status) {
                                   if (status ==
                                           PHAuthorizationStatusAuthorized ||
                                       status == PHAuthorizationStatusLimited) {
                                     [[PHPhotoLibrary sharedPhotoLibrary]
                                         performChanges:^{
                                           PHAssetCreationRequest *request =
                                               [PHAssetCreationRequest
                                                   creationRequestForAssetFromImage:
                                                       image];
                                           NSDate *creationDate =
                                               [self creationDateFromMetadata:
                                                         metadata];
                                           if (creationDate) {
                                             request.creationDate =
                                                 creationDate;
                                           }
                                           CLLocation *location = [self
                                               locationFromMetadata:metadata];
                                           if (location) {
                                             request.location = location;
                                           }
                                         }
                                         completionHandler:^(
                                             BOOL success,
                                             NSError *_Nullable error) {
                                           if (!success && error) {
                                             NSLog(@"保存图片失败: %@",
                                                   error.localizedDescription);
                                           }
                                           if (completion) {
                                             dispatch_async(
                                                 dispatch_get_main_queue(), ^{
                                                   completion(success, error);
                                                 });
                                           }
                                         }];
                                   } else {
                                     if (completion) {
                                       NSError *permissionError = [NSError
                                           errorWithDomain:@"CameraManager"
                                                      code:2002
                                                  userInfo:@{
                                                    NSLocalizedDescriptionKey :
                                                        @"Photo library "
                                                        @"permission denied"
                                                  }];
                                       dispatch_async(
                                           dispatch_get_main_queue(), ^{
                                             completion(NO, permissionError);
                                           });
                                     }
                                   }
                                 }];
}

#pragma mark - 元数据辅助

- (NSDate *)creationDateFromMetadata:(NSDictionary *)metadata {
  if (!metadata) {
    return nil;
  }
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  NSString *timestamp = exif[(NSString *)kCGImagePropertyExifDateTimeOriginal];
  if (!timestamp) {
    timestamp = exif[(NSString *)kCGImagePropertyExifDateTimeDigitized];
  }
  if (!timestamp) {
    return nil;
  }
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
  formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  return [formatter dateFromString:timestamp];
}

- (CLLocation *)locationFromMetadata:(NSDictionary *)metadata {
  if (!metadata) {
    return nil;
  }
  NSDictionary *gps = metadata[(NSString *)kCGImagePropertyGPSDictionary];
  if (!gps) {
    return nil;
  }

  NSNumber *latValue = gps[(NSString *)kCGImagePropertyGPSLatitude];
  NSNumber *lonValue = gps[(NSString *)kCGImagePropertyGPSLongitude];
  if (!latValue || !lonValue) {
    return nil;
  }

  NSString *latRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef];
  NSString *lonRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef];

  CLLocationDegrees latitude =
      latValue.doubleValue *
      ((latRef && [latRef isEqualToString:@"S"]) ? -1.0 : 1.0);
  CLLocationDegrees longitude =
      lonValue.doubleValue *
      ((lonRef && [lonRef isEqualToString:@"W"]) ? -1.0 : 1.0);

  NSNumber *altitudeValue = gps[(NSString *)kCGImagePropertyGPSAltitude];
  CLLocationDistance altitude = altitudeValue ? altitudeValue.doubleValue : 0.0;

  CLLocationDirection course = -1.0;
  CLLocationSpeed speed = -1.0;

  return [[CLLocation alloc]
      initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude)
                altitude:altitude
      horizontalAccuracy:kCLLocationAccuracyNearestTenMeters
        verticalAccuracy:kCLLocationAccuracyNearestTenMeters
                  course:course
                   speed:speed
               timestamp:[NSDate date]];
}

#pragma mark - 代理通知

- (void)notifyDelegateStateChanged {
  if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                 didChangeState:)]) {
    [self.delegate cameraManager:self didChangeState:self.currentState];
  }
}

#pragma mark - 内存管理

- (void)cleanup {
  [self stopSession];
  [self stopDeviceOrientationMonitoring]; // 停止方向监听

  dispatch_async(self.sessionQueue, ^{
    // 清理AVFoundation组件
    if (self.captureSession) {
      for (AVCaptureInput *input in self.captureSession.inputs) {
        [self.captureSession removeInput:input];
      }
      for (AVCaptureOutput *output in self.captureSession.outputs) {
        [self.captureSession removeOutput:output];
      }
    }

    // 清理预览层
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.previewLayer removeFromSuperlayer];
      self.previewLayer = nil;
    });

    // 清理其他组件
    self.captureSession = nil;
    self.currentDevice = nil;
    self.deviceInput = nil;
    self.photoOutput = nil;
    self.motionManager = nil; // 清理方向监听器

    self.currentState = CameraStateIdle;
  });
}

- (void)dealloc {
  [self cleanup];
}

@end
