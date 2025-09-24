//
//  CameraBusinessController.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraBusinessController.h"
#import "../Managers/CMWatermarkRenderer.h"

static NSString * const kCMWatermarkConfigurationStorageKey = @"com.cameram.watermark.configuration";

@interface CameraBusinessController () <CameraManagerDelegate>

@property (nonatomic, strong) CameraManager *cameraManager;
@property (nonatomic, strong) UIImage *latestCapturedImage;
@property (nonatomic, assign) BOOL isGridLinesVisible;
@property (nonatomic, copy) CMWatermarkConfiguration *watermarkConfiguration;
@property (nonatomic, strong) CMWatermarkRenderer *watermarkRenderer;
@property (nonatomic, strong) dispatch_queue_t renderQueue;

- (void)persistWatermarkConfiguration;
- (void)loadPersistedWatermarkConfiguration;

@end

@implementation CameraBusinessController

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupCameraManager];
        _isGridLinesVisible = NO;
        _watermarkConfiguration = [CMWatermarkConfiguration defaultConfiguration];
        [self loadPersistedWatermarkConfiguration];
        _watermarkRenderer = [[CMWatermarkRenderer alloc] init];
        _renderQueue = dispatch_queue_create("com.cameram.render", DISPATCH_QUEUE_SERIAL);
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

- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
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
    CameraResolutionMode newMode = (currentMode == CameraResolutionModeStandard) ? CameraResolutionModeUltraHigh : CameraResolutionModeStandard;
    
    if (newMode == CameraResolutionModeUltraHigh && !self.cameraManager.isUltraHighResolutionSupported) {
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
}

- (void)switchAspectRatio:(CameraAspectRatio)ratio {
    [self.cameraManager switchAspectRatio:ratio];
}

#pragma mark - 对焦和曝光

- (void)focusAtPoint:(CGPoint)screenPoint withPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    // 转换屏幕坐标到设备坐标
    CGPoint devicePoint = [previewLayer captureDevicePointOfInterestForPoint:screenPoint];
    [self.cameraManager focusAtPoint:devicePoint];
}

- (void)setExposureCompensation:(float)value {
    [self.cameraManager setExposureCompensation:value];
}

#pragma mark - 网格线状态管理

- (void)toggleGridLines {
    self.isGridLinesVisible = !self.isGridLinesVisible;
}

- (BOOL)isGridLinesVisible {
    return _isGridLinesVisible;
}

- (CGRect)previewRectForCurrentAspectRatioInViewSize:(CGSize)viewSize {
    return [self.cameraManager previewRectForAspectRatio:self.currentAspectRatio inViewSize:viewSize];
}

- (void)updateWatermarkConfiguration:(CMWatermarkConfiguration *)configuration {
    if (!configuration) { return; }
    self.watermarkConfiguration = [configuration copy];
    [self persistWatermarkConfiguration];
}

- (void)persistWatermarkConfiguration {
    if (!self.watermarkConfiguration) { return; }

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.watermarkConfiguration
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
    NSData *storedData = [[NSUserDefaults standardUserDefaults] objectForKey:kCMWatermarkConfigurationStorageKey];
    if (!storedData) { return; }

    NSError *unarchiveError = nil;
    CMWatermarkConfiguration *storedConfig = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMWatermarkConfiguration class]
                                                                               fromData:storedData
                                                                                  error:&unarchiveError];
    if (storedConfig && !unarchiveError) {
        self.watermarkConfiguration = [storedConfig copy];
    } else if (unarchiveError) {
        NSLog(@"⚠️ 水印配置读取失败: %@", unarchiveError.localizedDescription);
    }
}

#pragma mark - CameraManagerDelegate

- (void)cameraManager:(CameraManager *)manager didChangeState:(CameraState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldEnable = (state == CameraStateRunning);
        
        if ([self.delegate respondsToSelector:@selector(shouldUpdateCaptureButtonEnabled:)]) {
            [self.delegate shouldUpdateCaptureButtonEnabled:shouldEnable];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata {
    if (!image) { return; }
    CMWatermarkConfiguration *configurationSnapshot = [self.watermarkConfiguration copy];
    CameraAspectRatio aspectRatio = self.currentAspectRatio;

    dispatch_async(self.renderQueue, ^{
        @autoreleasepool {
            UIImage *croppedImage = [self.cameraManager cropImage:image toAspectRatio:aspectRatio];
            UIImage *renderedImage = croppedImage;
            if (configurationSnapshot) {
                renderedImage = [self.watermarkRenderer renderImage:croppedImage
                                                  withConfiguration:configurationSnapshot
                                                           metadata:metadata] ?: croppedImage;
            }
            UIImage *finalImage = renderedImage ?: croppedImage;
            [self.cameraManager saveImageToPhotosLibrary:finalImage metadata:metadata completion:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.latestCapturedImage = finalImage;
                if ([self.delegate respondsToSelector:@selector(didCapturePhoto:withMetadata:)]) {
                    [self.delegate didCapturePhoto:finalImage withMetadata:metadata];
                }
                if ([self.delegate respondsToSelector:@selector(shouldShowCaptureFlashEffect)]) {
                    [self.delegate shouldShowCaptureFlashEffect];
                }
            });
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didFailWithError:)]) {
            [self.delegate didFailWithError:error];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeResolutionMode:(CameraResolutionMode)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeResolutionMode:)]) {
            [self.delegate didChangeResolutionMode:mode];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeFlashMode:(FlashMode)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeFlashMode:)]) {
            [self.delegate didChangeFlashMode:mode];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeAspectRatio:(CameraAspectRatio)ratio {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeAspectRatio:)]) {
            [self.delegate didChangeAspectRatio:ratio];
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeDeviceOrientation:(CameraDeviceOrientation)orientation {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(didChangeDeviceOrientation:)]) {
            [self.delegate didChangeDeviceOrientation:orientation];
        }
    });
}

@end
