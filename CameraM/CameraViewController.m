//
//  CameraViewController_New.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraViewController.h"
#import "Views/CameraControlsView.h"
#import "Controllers/CameraBusinessController.h"

@interface CameraViewController () <CameraControlsDelegate, CameraBusinessDelegate>

// 分离的组件 - 高内聚低耦合
@property (nonatomic, strong) CameraControlsView *controlsView;
@property (nonatomic, strong) CameraBusinessController *businessController;

@end

@implementation CameraViewController

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupComponents];
    [self setupCamera];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.businessController startSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.businessController stopSession];
}

- (void)dealloc {
    [self.businessController stopOrientationMonitoring]; // 停止方向监听
    [self.businessController cleanup];
}

#pragma mark - 组件设置 (协调者职责)

- (void)setupComponents {
    // 创建UI组件
    self.controlsView = [[CameraControlsView alloc] initWithFrame:self.view.bounds];
    self.controlsView.delegate = self;
    self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.controlsView];
    
    // 创建业务控制器
    self.businessController = [[CameraBusinessController alloc] init];
    self.businessController.delegate = self;
    
    // UI组件约束
    [NSLayoutConstraint activateConstraints:@[
        [self.controlsView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.controlsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.controlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.controlsView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupCamera {
    [self.businessController setupCameraWithPreviewView:self.controlsView.previewContainer completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"相机设置成功");
            [self updateUIState];
            
            // 启动方向监听
            [self.businessController startOrientationMonitoring];
        } else {
            NSLog(@"相机设置失败: %@", error.localizedDescription);
            [self showErrorAlert:error.localizedDescription];
        }
    }];
}

- (void)updateUIState {
    // 协调UI状态更新
    CameraResolutionMode mode = self.businessController.currentResolutionMode;
    NSString *modeText = (mode == CameraResolutionModeUltraHigh) ? @"48MP" : @"12MP";
    BOOL highlighted = (mode == CameraResolutionModeUltraHigh);
    [self.controlsView updateResolutionMode:modeText highlighted:highlighted];
    
    FlashMode flashMode = self.businessController.currentFlashMode;
    NSString *flashText = [self flashModeText:flashMode];
    BOOL flashHighlighted = (flashMode == FlashModeOn);
    [self.controlsView updateFlashMode:flashText highlighted:flashHighlighted];
}

- (NSString *)flashModeText:(FlashMode)mode {
    switch (mode) {
        case FlashModeAuto: return @"AUTO";
        case FlashModeOn: return @"ON";
        case FlashModeOff: return @"OFF";
    }
}

#pragma mark - CameraControlsDelegate (UI事件转发)

- (void)didTapCaptureButton {
    [self.businessController capturePhoto];
}

- (void)didTapGalleryButton {
    UIImage *latestImage = self.businessController.latestCapturedImage;
    if (latestImage) {
        [self showImagePreview:latestImage];
    } else {
        [self openSystemPhotosApp];
    }
}

- (void)didSelectMode:(NSInteger)modeIndex {
    NSLog(@"模式切换: %ld", (long)modeIndex);
    
    // Square模式自动切换到1:1比例
    if (modeIndex == 2) { // Square模式
        [self.businessController switchAspectRatio:CameraAspectRatio1to1];
    }
}

- (void)didSelectAspectRatio:(CameraAspectRatio)ratio {
    [self.businessController switchAspectRatio:ratio];
    NSLog(@"比例切换: %ld", (long)ratio);
}

- (void)didTapFlashButton {
    [self.businessController switchFlashMode];
}

- (void)didTapGridButton {
    [self.businessController toggleGridLines];
    [self.controlsView showGridLines:[self.businessController isGridLinesVisible]];
}

- (void)didTapSwitchCameraButton {
    [self.businessController switchCamera];
}

- (void)didTapFrameWatermarkButton {
    NSLog(@"相框水印按钮点击");
    
    // 模拟状态切换
    static BOOL frameWatermarkEnabled = NO;
    frameWatermarkEnabled = !frameWatermarkEnabled;
    [self.controlsView updateFrameWatermarkStatus:frameWatermarkEnabled];
}

- (void)didTapSettingsButton {
    NSLog(@"设置按钮点击");
}

- (void)didTapFilterButton {
    NSLog(@"滤镜按钮点击");
}

- (void)didChangeExposure:(float)value {
    [self.businessController setExposureCompensation:value];
}

- (void)didTapPreviewAtPoint:(CGPoint)point {
    [self.businessController focusAtPoint:point withPreviewLayer:self.businessController.cameraManager.previewLayer];
    [self.controlsView showFocusIndicatorAtPoint:point];
}

- (void)didDoubleTapPreview {
    if (self.businessController.isUltraHighResolutionSupported) {
        [self.businessController switchResolutionMode];
    }
}

#pragma mark - CameraBusinessDelegate (业务事件处理)

- (void)didChangeResolutionMode:(CameraResolutionMode)mode {
    [self updateUIState];
}

- (void)didChangeFlashMode:(FlashMode)mode {
    [self updateUIState];
}

- (void)didChangeAspectRatio:(CameraAspectRatio)ratio {
    // 更新UI遮罩和选择状态
    [self.controlsView updateAspectRatioMask:ratio];
    [self.controlsView updateAspectRatioSelection:ratio];
    NSLog(@"比例变化通知: %ld", (long)ratio);
}

- (void)didChangeDeviceOrientation:(CameraDeviceOrientation)orientation {
    // 更新UI布局适配
    [self.controlsView updateLayoutForOrientation:orientation];
    
    // 重要：更新预览层frame以适应新布局
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePreviewLayerFrame];
    });
    
    NSLog(@"设备方向变化，UI适配: %ld", (long)orientation);
}

// 新增方法：更新预览层frame
- (void)updatePreviewLayerFrame {
    CGRect newFrame = self.controlsView.previewContainer.bounds;
    
    if (!CGRectIsEmpty(newFrame)) {
        // 使用CATransaction确保frame和方向同步更新
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.businessController.cameraManager.previewLayer.frame = newFrame;
        [CATransaction commit];
        
        NSLog(@"📐 预览层frame已更新: %@", NSStringFromCGRect(newFrame));
    }
}

- (void)didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata {
    NSLog(@"拍照成功，图片尺寸: %.0fx%.0f", image.size.width, image.size.height);
    [self.controlsView updateGalleryButtonWithImage:image];
}

- (void)didFailWithError:(NSError *)error {
    [self showErrorAlert:error.localizedDescription];
}

- (void)shouldUpdateCaptureButtonEnabled:(BOOL)enabled {
    self.controlsView.captureButton.enabled = enabled;
}

- (void)shouldShowCaptureFlashEffect {
    [self showCaptureFlashEffect];
}

#pragma mark - 视图控制器辅助方法

- (void)showErrorAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showImagePreview:(UIImage *)image {
    UIViewController *previewVC = [[UIViewController alloc] init];
    previewVC.view.backgroundColor = [UIColor blackColor];
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [previewVC.view addSubview:imageView];
    
    UIButton *closeButton = [[UIButton alloc] init];
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    closeButton.layer.cornerRadius = 8;
    [closeButton addTarget:self action:@selector(dismissImagePreview) forControlEvents:UIControlEventTouchUpInside];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [previewVC.view addSubview:closeButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [imageView.topAnchor constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:previewVC.view.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:previewVC.view.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide.bottomAnchor],
        
        [closeButton.topAnchor constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide.topAnchor constant:20],
        [closeButton.trailingAnchor constraintEqualToAnchor:previewVC.view.trailingAnchor constant:-20],
        [closeButton.widthAnchor constraintEqualToConstant:60],
        [closeButton.heightAnchor constraintEqualToConstant:40]
    ]];
    
    previewVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:previewVC animated:YES completion:nil];
}

- (void)dismissImagePreview {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openSystemPhotosApp {
    NSURL *photosURL = [NSURL URLWithString:@"photos-redirect://"];
    if ([[UIApplication sharedApplication] canOpenURL:photosURL]) {
        [[UIApplication sharedApplication] openURL:photosURL options:@{} completionHandler:nil];
    }
}

- (void)showCaptureFlashEffect {
    UIView *flashView = [[UIView alloc] initWithFrame:self.view.bounds];
    flashView.backgroundColor = [UIColor whiteColor];
    flashView.alpha = 0.0;
    [self.view addSubview:flashView];
    
    [UIView animateWithDuration:0.1 animations:^{
        flashView.alpha = 0.8;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            flashView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [flashView removeFromSuperview];
        }];
    }];
}

#pragma mark - 内存管理

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"收到内存警告 - 协调者清理非必要资源");
}

@end