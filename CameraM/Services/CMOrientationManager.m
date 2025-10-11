//
//  CMOrientationManager.m
//  CameraM
//
//  设备方向管理模块实现
//

#import "CMOrientationManager.h"

@interface CMOrientationManager ()
@property (nonatomic, readwrite) CameraDeviceOrientation currentDeviceOrientation;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation CMOrientationManager

- (instancetype)init {
  self = [super init];
  if (self) {
    _currentDeviceOrientation = CameraDeviceOrientationPortrait;
    _isMonitoring = NO;
  }
  return self;
}

#pragma mark - Lifecycle

- (void)startMonitoring {
  if (self.isMonitoring) {
    return;
  }

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

  self.isMonitoring = YES;
  NSLog(@"📱 [CMOrientationManager] 开始设备方向监听");
}

- (void)stopMonitoring {
  if (!self.isMonitoring) {
    return;
  }

  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIDeviceOrientationDidChangeNotification
              object:nil];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

  self.isMonitoring = NO;
  NSLog(@"📱 [CMOrientationManager] 停止设备方向监听");
}

#pragma mark - Notification Handler

- (void)deviceOrientationDidChange:(NSNotification *)notification {
  UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
  [self updateDeviceOrientation:deviceOrientation];
}

- (void)updateDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
  CameraDeviceOrientation newOrientation =
      [self cameraOrientationFromDeviceOrientation:deviceOrientation];

  // 如果转换失败(返回值为0表示无效方向),则不更新
  if (newOrientation == 0) {
    return;
  }

  if (newOrientation != self.currentDeviceOrientation) {
    self.currentDeviceOrientation = newOrientation;

    NSLog(@"📱 [CMOrientationManager] 设备方向变化: %ld", (long)newOrientation);

    // 通知代理
    dispatch_async(dispatch_get_main_queue(), ^{
      if ([self.delegate respondsToSelector:@selector(orientationManager:didChangeDeviceOrientation:)]) {
        [self.delegate orientationManager:self
                didChangeDeviceOrientation:newOrientation];
      }
    });
  }
}

#pragma mark - Orientation Conversion

- (AVCaptureVideoOrientation)currentVideoOrientation {
  switch (self.currentDeviceOrientation) {
  case CameraDeviceOrientationPortrait:
    return AVCaptureVideoOrientationPortrait;
  case CameraDeviceOrientationLandscapeLeft:
    return AVCaptureVideoOrientationLandscapeRight;
  case CameraDeviceOrientationLandscapeRight:
    return AVCaptureVideoOrientationLandscapeLeft;
  }

  // 降级: 如果无法获取当前方向,使用interfaceOrientation
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

- (CameraDeviceOrientation)cameraOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
  switch (deviceOrientation) {
  case UIDeviceOrientationPortrait:
    return CameraDeviceOrientationPortrait;
  case UIDeviceOrientationLandscapeLeft:
    return CameraDeviceOrientationLandscapeLeft;
  case UIDeviceOrientationLandscapeRight:
    return CameraDeviceOrientationLandscapeRight;
  default:
    // 忽略其他方向(面朝上、面朝下等)
    return 0; // 返回0表示无效方向
  }
}

#pragma mark - Dealloc

- (void)dealloc {
  [self stopMonitoring];
}

@end
