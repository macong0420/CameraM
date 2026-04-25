//
//  CameraManager.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraManager.h"
#import "../Models/CMCameraLensOption.h"
#import "../Services/CMLocationService.h"
#import "../Services/CMImageProcessor.h"
#import "../Services/CMFormatManager.h"
#import "../Services/CMDeviceManager.h"
#import "../Services/CMMetadataEnricher.h"
#import "../Services/CMOrientationManager.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>
#import <float.h>
#import <math.h>

@interface CameraManager () <AVCapturePhotoCaptureDelegate, CMLocationServiceDelegate, CMOrientationManagerDelegate>

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
// 格式缓存已迁移到CMFormatManager

// 方向监听
@property(nonatomic, strong) CMMotionManager *motionManager;

// 性能优化 - 队列管理
@property(nonatomic, strong) dispatch_queue_t sessionQueue;
@property(nonatomic, strong) dispatch_queue_t photoProcessingQueue;

// 镜头管理 - 已迁移到CMDeviceManager
// availableLensOptions, currentLensOption, lensDeviceMap 通过属性访问器桥接
// 位置管理
@property(nonatomic, strong) CMLocationService *locationService; // 位置服务
@property(nonatomic, strong) CLLocation *latestLocation; // 最新位置(由CMLocationService更新)

// 图片处理
@property(nonatomic, strong) CMImageProcessor *imageProcessor; // 图片处理模块

// 格式管理
@property(nonatomic, strong) CMFormatManager *formatManager; // 格式管理模块

// 设备管理
@property(nonatomic, strong) CMDeviceManager *deviceManager; // 设备管理模块

// 元数据增强
@property(nonatomic, strong) CMMetadataEnricher *metadataEnricher; // 元数据增强模块

// 方向管理
@property(nonatomic, strong) CMOrientationManager *orientationManager; // 方向管理模块

- (void)notifyLensUpdate;
- (CGSize)activeFormatDimensions;
- (BOOL)deviceSupportsUltraHighResolution:(AVCaptureDevice *)device;
- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device;
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
- (void)checkUltraHighResolutionSupport;
- (BOOL)performCameraSetup:(NSError **)error;
- (void)setupPreviewLayerWithView:(UIView *)previewView;
- (void)notifyDelegateStateChanged;
- (AVCaptureVideoOrientation)currentVideoOrientation;
- (AVCapturePhotoSettings *)createPhotoSettings;

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
  // 镜头选项初始化已迁移到CMDeviceManager
  // 格式缓存初始化已迁移到CMFormatManager

  // 创建专用队列 - 避免主线程阻塞
  _sessionQueue =
      dispatch_queue_create("com.cameram.session", DISPATCH_QUEUE_SERIAL);
  dispatch_queue_attr_t photoQueueAttr =
      dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                              QOS_CLASS_USER_INITIATED, 0);
  _photoProcessingQueue =
      dispatch_queue_create("com.cameram.photo.processing", photoQueueAttr);

  // 初始化方向监听
  _motionManager = [[CMMotionManager alloc] init];

  // 检查4800万像素支持
  [self checkUltraHighResolutionSupport];

  // 初始化新的位置服务
  _locationService = [[CMLocationService alloc] init];
  _locationService.delegate = self;

  // 初始化图片处理模块
  _imageProcessor = [[CMImageProcessor alloc] init];

  // 初始化格式管理模块
  _formatManager = [[CMFormatManager alloc] init];

  // 初始化设备管理模块
  _deviceManager = [[CMDeviceManager alloc] init];

  // 初始化元数据增强模块
  _metadataEnricher = [[CMMetadataEnricher alloc] init];

  // 初始化方向管理模块
  _orientationManager = [[CMOrientationManager alloc] init];
  _orientationManager.delegate = self;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.locationService configure]; // 启动位置服务
  });
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
        [self.locationService startUpdatingLocation]; // 启动位置更新
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
        [self.locationService stopUpdatingLocation]; // 停止位置更新
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
        AVCaptureVideoOrientation orientationForCapture =
            [self currentVideoOrientation];
        AVCaptureConnection *previewConnection = self.previewLayer.connection;
        if (previewConnection && previewConnection.isVideoOrientationSupported) {
          orientationForCapture = previewConnection.videoOrientation;
        }
        photoConnection.videoOrientation = orientationForCapture;
      }
      if (photoConnection.isVideoMirroringSupported) {
        photoConnection.videoMirrored =
            (self.currentPosition == CameraPositionFront);
      }
    }
    AVCapturePhotoSettings *settings = [self createPhotoSettings];
    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
  });

  // 后续状态更新在回调中处理
}

#pragma mark - CMLocationServiceDelegate

- (void)locationService:(CMLocationService *)service
     didUpdateLocation:(CLLocation *)location {
  // 同步到旧属性,保持向后兼容
  self.latestLocation = location;
  NSLog(@"✅ [NEW] Location updated via CMLocationService: %@", location);
}

- (void)locationService:(CMLocationService *)service
       didFailWithError:(NSError *)error {
  NSLog(@"⚠️ [NEW] Location failed via CMLocationService: %@", error.localizedDescription);
}

- (void)locationService:(CMLocationService *)service
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  NSLog(@"ℹ️ [NEW] Location authorization changed via CMLocationService: %ld", (long)status);
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

    // 通过CMDeviceManager获取设备
    AVCaptureDevice *targetDevice =
        [self.deviceManager deviceByUniqueID:targetOption.deviceUniqueID];
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
      targetDevice = [self.deviceManager deviceByUniqueID:targetOption.deviceUniqueID];
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
  // 委托给CMOrientationManager
  [self.orientationManager startMonitoring];
}

- (void)stopDeviceOrientationMonitoring {
  // 委托给CMOrientationManager
  [self.orientationManager stopMonitoring];
}

#pragma mark - CMOrientationManagerDelegate

- (void)orientationManager:(CMOrientationManager *)manager
    didChangeDeviceOrientation:(CameraDeviceOrientation)orientation {
  // 同步到本地属性
  self.currentDeviceOrientation = orientation;

  // 立即更新预览层方向
  [self updatePreviewLayerOrientation];

  // 通知代理
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.delegate respondsToSelector:@selector(cameraManager:
                                              didChangeDeviceOrientation:)]) {
      [self.delegate cameraManager:self
          didChangeDeviceOrientation:orientation];
    }
  });
}

// 更新预览层方向
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

// 获取当前视频方向 - 委托给CMOrientationManager
- (AVCaptureVideoOrientation)currentVideoOrientation {
  return [self.orientationManager currentVideoOrientation];
}

#pragma mark - 比例相关工具方法

- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio
                     inImageSize:(CGSize)imageSize {
  // 委托给CMImageProcessor
  return [self.imageProcessor cropRectForAspectRatio:ratio
                                         inImageSize:imageSize
                                     withOrientation:self.currentDeviceOrientation];
}

- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio {
  // 使用CMImageProcessor处理图片裁剪
  return [self.imageProcessor cropImage:image
                         toAspectRatio:ratio
                       withOrientation:self.currentDeviceOrientation];
}

// 标准化图像方向 - 委托给CMImageProcessor
- (UIImage *)normalizeImageOrientation:(UIImage *)image {
  return [self.imageProcessor normalizeImageOrientation:image];
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
  // 委托给CMDeviceManager
  return [self.deviceManager discoverDevicesForPosition:position];
}

// canonicalZoomForDevice 和 titleForZoomFactor 方法已迁移到 CMDeviceManager

- (void)rebuildLensOptionsForPosition:(CameraPosition)position
                              devices:(NSArray<AVCaptureDevice *> *)devices
                         shouldNotify:(BOOL)notify {
  // 委托给CMDeviceManager
  [self.deviceManager rebuildLensOptionsForPosition:position
                                            devices:devices
                                       shouldNotify:notify];
  if (notify) {
    [self notifyLensUpdate];
  }
}

- (AVCaptureDevice *)deviceForLensOption:(CMCameraLensOption *)lensOption
                                 devices:(NSArray<AVCaptureDevice *> *)devices {
  // 委托给CMDeviceManager
  return [self.deviceManager deviceForLensOption:lensOption devices:devices];
}

- (void)notifyLensUpdate {
  // 使用CMDeviceManager的快照方法
  NSArray<CMCameraLensOption *> *lensSnapshot = [self.deviceManager lensOptionsSnapshot];
  CMCameraLensOption *currentSnapshot = [self.deviceManager currentLensOptionSnapshot];

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
  // 委托给CMFormatManager
  return [self.formatManager deviceSupportsUltraHighResolution:device];
}

- (void)primeFormatCachesForDevice:(AVCaptureDevice *)device {
  // 委托给CMFormatManager
  [self.formatManager primeFormatCachesForDevice:device];
}

- (CMVideoDimensions)maxPhotoDimensionsForFormat:(AVCaptureDeviceFormat *)format {
  // 委托给CMFormatManager
  return [self.formatManager maxPhotoDimensionsForFormat:format];
}

- (void)configureMaxPhotoDimensionsForSettings:(AVCapturePhotoSettings *)settings {
  // 委托给CMFormatManager
  [self.formatManager configureMaxPhotoDimensionsForSettings:settings
                                                 photoOutput:self.photoOutput
                                                currentDevice:self.currentDevice];
}

// 格式管理方法已迁移到CMFormatManager

- (AVCaptureDeviceFormat *)standardFormatForDevice:(AVCaptureDevice *)device {
  return [self.formatManager standardFormatForDevice:device];
}

- (AVCaptureDeviceFormat *)ultraHighResolutionFormatForDevice:(AVCaptureDevice *)device {
  return [self.formatManager ultraHighResolutionFormatForDevice:device];
}

- (AVCaptureDeviceFormat *)findUltraHighResolutionFormatForDevice:(AVCaptureDevice *)device {
  return [self.formatManager findUltraHighResolutionFormatForDevice:device];
}

- (BOOL)applyFormat:(AVCaptureDeviceFormat *)format toDevice:(AVCaptureDevice *)device {
  return [self.formatManager applyFormat:format toDevice:device];
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

  // 格式缓存更新已由CMFormatManager内部处理

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
  });

  NSData *imageData = photo.fileDataRepresentation;
  if (!imageData) {
    NSError *invalidDataError =
        [NSError errorWithDomain:@"CameraManager"
                            code:1006
                        userInfo:@{
                          NSLocalizedDescriptionKey : @"无法从拍照结果中获取图像数据"
                        }];
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self.delegate respondsToSelector:@selector(cameraManager:
                                                   didFailWithError:)]) {
        [self.delegate cameraManager:self didFailWithError:invalidDataError];
      }
    });
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(self.photoProcessingQueue, ^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }

      UIImage *image = [UIImage imageWithData:imageData];
      if (!image) {
        NSError *decodeError =
            [NSError errorWithDomain:@"CameraManager"
                                code:1007
                            userInfo:@{
                              NSLocalizedDescriptionKey : @"图像解码失败"
                            }];
        dispatch_async(dispatch_get_main_queue(), ^{
          if ([strongSelf.delegate
                  respondsToSelector:@selector(cameraManager:
                                               didFailWithError:)]) {
            [strongSelf.delegate cameraManager:strongSelf
                                didFailWithError:decodeError];
          }
        });
        return;
      }

      NSDictionary *enrichedMetadata = [strongSelf
          enrichedMetadataFromPhoto:photo
                   originalMetadata:photo.metadata];

      dispatch_async(dispatch_get_main_queue(), ^{
        if ([strongSelf.delegate respondsToSelector:@selector
                                 (cameraManager:didCapturePhoto:
                                                  withMetadata:)]) {
          [strongSelf.delegate cameraManager:strongSelf
                             didCapturePhoto:image
                                withMetadata:enrichedMetadata];
        }
      });
    }
  });
}

#pragma mark - 相册保存

- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(NSDictionary *)metadata
                      completion:
                          (void (^)(BOOL success,
                                    NSError *_Nullable error))completion {
  // 使用CMImageProcessor保存图片到相册
  [self.imageProcessor saveImageToPhotosLibrary:image
                                       metadata:metadata
                                     completion:completion];
}

#pragma mark - 元数据辅助

// 元数据辅助方法已迁移到CMMetadataEnricher

- (NSDictionary *)enrichedMetadataFromPhoto:(AVCapturePhoto *)photo
                           originalMetadata:(NSDictionary *)metadata {
  // 委托给CMMetadataEnricher
  return [self.metadataEnricher enrichMetadataFromPhoto:photo
                                       originalMetadata:metadata
                                               location:self.latestLocation
                                                 device:self.currentDevice
                                             lensOption:self.currentLensOption];
}

- (NSDate *)creationDateFromMetadata:(NSDictionary *)metadata {
  // 委托给CMImageProcessor
  return [self.imageProcessor creationDateFromMetadata:metadata];
}

- (CLLocation *)locationFromMetadata:(NSDictionary *)metadata {
  // 委托给CMImageProcessor
  return [self.imageProcessor locationFromMetadata:metadata];
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

#pragma mark - 属性访问器桥接

// 桥接到CMDeviceManager的属性
- (NSArray<CMCameraLensOption *> *)availableLensOptions {
  return self.deviceManager.availableLensOptions;
}

- (CMCameraLensOption *)currentLensOption {
  return self.deviceManager.currentLensOption;
}

- (void)setCurrentLensOption:(CMCameraLensOption *)currentLensOption {
  [self.deviceManager selectLensOption:currentLensOption];
}

@end
