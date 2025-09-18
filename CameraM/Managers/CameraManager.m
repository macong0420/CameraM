//
//  CameraManager.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraManager.h"
#import <Photos/Photos.h>

@interface CameraManager () <AVCapturePhotoCaptureDelegate>

// AVFoundation 核心组件
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *currentDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// 状态管理
@property (nonatomic, readwrite) CameraState currentState;
@property (nonatomic, readwrite) CameraPosition currentPosition;
@property (nonatomic, readwrite) CameraResolutionMode currentResolutionMode;

// 性能优化 - 队列管理
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

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
    
    // 创建专用队列 - 避免主线程阻塞
    _sessionQueue = dispatch_queue_create("com.cameram.session", DISPATCH_QUEUE_SERIAL);
    
    // 检查4800万像素支持
    [self checkUltraHighResolutionSupport];
}

#pragma mark - 公开方法

- (void)setupCameraWithPreviewView:(UIView *)previewView completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    // 状态检查
    if (self.currentState != CameraStateIdle) {
        NSError *error = [NSError errorWithDomain:@"CameraManager" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Camera is not in idle state"}];
        if (completion) completion(NO, error);
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
                if (completion) completion(YES, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.currentState = CameraStateError;
                if (completion) completion(NO, setupError);
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
        AVCapturePhotoSettings *settings = [self createPhotoSettings];
        [self.photoOutput capturePhotoWithSettings:settings delegate:self];
    });
}

- (void)switchCamera {
    dispatch_async(self.sessionQueue, ^{
        // 切换摄像头逻辑
        CameraPosition newPosition = (self.currentPosition == CameraPositionBack) ? CameraPositionFront : CameraPositionBack;
        
        [self.captureSession beginConfiguration];
        
        // 移除当前输入
        if (self.deviceInput) {
            [self.captureSession removeInput:self.deviceInput];
        }
        
        // 创建新的设备输入
        AVCaptureDevice *newDevice = [self cameraWithPosition:newPosition];
        NSError *error = nil;
        AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:&error];
        
        if (newInput && [self.captureSession canAddInput:newInput]) {
            [self.captureSession addInput:newInput];
            self.deviceInput = newInput;
            self.currentDevice = newDevice;
            self.currentPosition = newPosition;
        }
        
        [self.captureSession commitConfiguration];
    });
}

- (void)switchResolutionMode:(CameraResolutionMode)mode {
    if (!self.isUltraHighResolutionSupported && mode == CameraResolutionModeUltraHigh) {
        return;
    }
    
    dispatch_async(self.sessionQueue, ^{
        [self.captureSession beginConfiguration];
        [self configurePhotoOutputForResolutionMode:mode];
        [self.captureSession commitConfiguration];
        
        self.currentResolutionMode = mode;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(cameraManager:didChangeResolutionMode:)]) {
                [self.delegate cameraManager:self didChangeResolutionMode:mode];
            }
        });
    });
}

#pragma mark - 私有方法

- (BOOL)performCameraSetup:(NSError **)error {
    // 创建capture session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // 设置session preset - 性能优化
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
        [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    
    // 设置相机设备
    self.currentDevice = [self cameraWithPosition:self.currentPosition];
    if (!self.currentDevice) {
        if (error) {
            *error = [NSError errorWithDomain:@"CameraManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"No camera device available"}];
        }
        return NO;
    }
    
    // 创建设备输入
    NSError *inputError = nil;
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.currentDevice error:&inputError];
    if (!self.deviceInput) {
        if (error) *error = inputError;
        return NO;
    }
    
    // 添加输入到session
    if ([self.captureSession canAddInput:self.deviceInput]) {
        [self.captureSession addInput:self.deviceInput];
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"CameraManager" code:1003 userInfo:@{NSLocalizedDescriptionKey: @"Cannot add camera input"}];
        }
        return NO;
    }
    
    // 创建照片输出
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.captureSession canAddOutput:self.photoOutput]) {
        [self.captureSession addOutput:self.photoOutput];
        [self configurePhotoOutputForResolutionMode:self.currentResolutionMode];
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"CameraManager" code:1004 userInfo:@{NSLocalizedDescriptionKey: @"Cannot add photo output"}];
        }
        return NO;
    }
    
    return YES;
}

- (void)setupPreviewLayerWithView:(UIView *)view {
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.frame = view.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [view.layer insertSublayer:self.previewLayer atIndex:0];
}

- (AVCaptureDevice *)cameraWithPosition:(CameraPosition)position {
    AVCaptureDevicePosition avPosition = (position == CameraPositionBack) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    
    // 优先使用多摄像头系统
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTripleCamera, AVCaptureDeviceTypeBuiltInDualWideCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:avPosition];
    
    return discoverySession.devices.firstObject;
}

- (void)checkUltraHighResolutionSupport {
    AVCaptureDevice *backCamera = [self cameraWithPosition:CameraPositionBack];
    
    // 检查是否支持4800万像素
    if (@available(iOS 16.0, *)) {
        for (AVCaptureDeviceFormat *format in backCamera.formats) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            // 4800万像素大约是8000x6000
            if (dimensions.width >= 8000 || dimensions.height >= 6000) {
                _isUltraHighResolutionSupported = YES;
                break;
            }
        }
    }
}

- (void)configurePhotoOutputForResolutionMode:(CameraResolutionMode)mode {
    if (@available(iOS 16.0, *)) {
        if (mode == CameraResolutionModeUltraHigh && self.isUltraHighResolutionSupported) {
            // 启用最大分辨率
            self.photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
        } else {
            // 标准模式 - 平衡性能和质量
            self.photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationBalanced;
        }
    }
}

- (AVCapturePhotoSettings *)createPhotoSettings {
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    
    // 4800万像素模式配置
    if (self.currentResolutionMode == CameraResolutionModeUltraHigh && self.isUltraHighResolutionSupported) {
        if (@available(iOS 16.0, *)) {
            settings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
        }
    }
    
    // 启用高质量拍摄
    if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
        settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeHEVC}];
    }
    
    return settings;
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentState = CameraStateRunning;
        [self notifyDelegateStateChanged];
        
        if (error) {
            if ([self.delegate respondsToSelector:@selector(cameraManager:didFailWithError:)]) {
                [self.delegate cameraManager:self didFailWithError:error];
            }
            return;
        }
        
        // 获取图像数据 - 内存优化处理
        NSData *imageData = photo.fileDataRepresentation;
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            NSDictionary *metadata = photo.metadata;
            
            if ([self.delegate respondsToSelector:@selector(cameraManager:didCapturePhoto:withMetadata:)]) {
                [self.delegate cameraManager:self didCapturePhoto:image withMetadata:metadata];
            }
            
            // 保存到相册
            [self saveImageToPhotosLibrary:image];
        }
    });
}

#pragma mark - 相册保存

- (void)saveImageToPhotosLibrary:(UIImage *)image {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetCreationRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (!success && error) {
                    NSLog(@"保存图片失败: %@", error.localizedDescription);
                }
            }];
        }
    }];
}

#pragma mark - 代理通知

- (void)notifyDelegateStateChanged {
    if ([self.delegate respondsToSelector:@selector(cameraManager:didChangeState:)]) {
        [self.delegate cameraManager:self didChangeState:self.currentState];
    }
}

#pragma mark - 内存管理

- (void)cleanup {
    [self stopSession];
    
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
        
        self.currentState = CameraStateIdle;
    });
}

- (void)dealloc {
    [self cleanup];
}

@end