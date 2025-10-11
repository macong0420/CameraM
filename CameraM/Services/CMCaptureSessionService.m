#import "CMCaptureSessionService.h"

@interface CMCaptureSessionService ()

@property (nonatomic, strong) CameraManager *cameraManager;

@end

@implementation CMCaptureSessionService

- (instancetype)initWithCameraManager:(CameraManager *)manager {
  NSParameterAssert(manager);
  self = [super init];
  if (self) {
    _cameraManager = manager;
  }
  return self;
}

#pragma mark - Delegate

- (id<CameraManagerDelegate>)delegate {
  return self.cameraManager.delegate;
}

- (void)setDelegate:(id<CameraManagerDelegate>)delegate {
  self.cameraManager.delegate = delegate;
}

#pragma mark - Readonly properties

- (CameraState)currentState {
  return self.cameraManager.currentState;
}

- (CameraPosition)currentPosition {
  return self.cameraManager.currentPosition;
}

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

- (NSArray<CMCameraLensOption *> *)availableLensOptions {
  return self.cameraManager.availableLensOptions;
}

- (CMCameraLensOption *)currentLensOption {
  return self.cameraManager.currentLensOption;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
  return self.cameraManager.previewLayer;
}

#pragma mark - Session lifecycle

- (void)setupCameraWithPreviewView:(UIView *)previewView
                        completion:(void (^)(BOOL, NSError *_Nullable))completion {
  [self.cameraManager setupCameraWithPreviewView:previewView completion:completion];
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

#pragma mark - Orientation

- (void)startDeviceOrientationMonitoring {
  [self.cameraManager startDeviceOrientationMonitoring];
}

- (void)stopDeviceOrientationMonitoring {
  [self.cameraManager stopDeviceOrientationMonitoring];
}

#pragma mark - Capture controls

- (void)capturePhoto {
  [self.cameraManager capturePhoto];
}

- (void)switchCamera {
  [self.cameraManager switchCamera];
}

- (void)switchResolutionMode:(CameraResolutionMode)mode {
  [self.cameraManager switchResolutionMode:mode];
}

- (void)switchFlashMode:(FlashMode)mode {
  [self.cameraManager switchFlashMode:mode];
}

- (void)switchAspectRatio:(CameraAspectRatio)ratio {
  [self.cameraManager switchAspectRatio:ratio];
}

- (void)switchToLensOption:(CMCameraLensOption *)lensOption {
  [self.cameraManager switchToLensOption:lensOption];
}

- (void)focusAtPoint:(CGPoint)devicePoint {
  [self.cameraManager focusAtPoint:devicePoint];
}

- (void)setExposureCompensation:(float)value {
  [self.cameraManager setExposureCompensation:value];
}

#pragma mark - Geometry helpers

- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio inImageSize:(CGSize)imageSize {
  return [self.cameraManager cropRectForAspectRatio:ratio inImageSize:imageSize];
}

- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio {
  return [self.cameraManager cropImage:image toAspectRatio:ratio];
}

- (CGRect)previewRectForAspectRatio:(CameraAspectRatio)ratio inViewSize:(CGSize)viewSize {
  return [self.cameraManager previewRectForAspectRatio:ratio inViewSize:viewSize];
}

- (CGRect)activeFormatPreviewRectInViewSize:(CGSize)viewSize {
  return [self.cameraManager activeFormatPreviewRectInViewSize:viewSize];
}

- (CGFloat)aspectRatioValueForRatio:(CameraAspectRatio)ratio
                    inOrientation:(CameraDeviceOrientation)orientation {
  return [self.cameraManager aspectRatioValueForRatio:ratio inOrientation:orientation];
}

#pragma mark - Persistence helpers

- (void)saveImageToPhotosLibrary:(UIImage *)image
                        metadata:(NSDictionary *)metadata
                       completion:(void (^)(BOOL, NSError *_Nullable))completion {
  [self.cameraManager saveImageToPhotosLibrary:image metadata:metadata completion:completion];
}

@end

