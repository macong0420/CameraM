//
//  CameraViewController.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraViewController.h"
#import "Managers/CameraManager.h"

@interface CameraViewController () <CameraManagerDelegate>

// 相机预览容器
@property (nonatomic, strong) UIView *previewContainer;

// 顶部控制栏
@property (nonatomic, strong) UIView *topControlsView;
@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIButton *gridButton;
@property (nonatomic, strong) UIButton *switchCameraButton;
@property (nonatomic, strong) UIButton *frameWatermarkButton; // 相框水印按钮
@property (nonatomic, strong) UIButton *settingsButton;

// 底部控制栏
@property (nonatomic, strong) UIView *bottomControlsView;
@property (nonatomic, strong) UIView *modeSelector;
@property (nonatomic, strong) UIButton *galleryButton;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *filterButton;

// 右侧专业控制区
@property (nonatomic, strong) UIView *professionalControlsView;
@property (nonatomic, strong) UISlider *exposureSlider;

// 状态指示器
@property (nonatomic, strong) UILabel *resolutionModeLabel;
@property (nonatomic, strong) UIView *frameWatermarkIndicator;

// 相机管理器
@property (nonatomic, strong) CameraManager *cameraManager;

@end

@implementation CameraViewController

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupCameraManager];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.cameraManager startSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.cameraManager stopSession];
}

- (void)dealloc {
    [self.cameraManager cleanup];
}

#pragma mark - UI设置

- (void)setupUI {
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupPreviewContainer];
    [self setupTopControls];
    [self setupBottomControls];
    [self setupProfessionalControls];
    [self setupStatusIndicators];
    [self setupConstraints];
}

- (void)setupPreviewContainer {
    // 相机预览容器 - 全屏
    self.previewContainer = [[UIView alloc] init];
    self.previewContainer.backgroundColor = [UIColor blackColor];
    self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.previewContainer];
}

- (void)setupTopControls {
    // 顶部控制栏
    self.topControlsView = [[UIView alloc] init];
    self.topControlsView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.topControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.topControlsView];
    
    // 闪光灯按钮
    self.flashButton = [self createControlButtonWithImageName:@"bolt.fill" action:@selector(flashButtonTapped:)];
    
    // 网格按钮
    self.gridButton = [self createControlButtonWithImageName:@"grid" action:@selector(gridButtonTapped:)];
    
    // 切换摄像头按钮
    self.switchCameraButton = [self createControlButtonWithImageName:@"arrow.triangle.2.circlepath.camera" action:@selector(switchCameraButtonTapped:)];
    
    // 相框水印按钮（新增）
    self.frameWatermarkButton = [self createControlButtonWithImageName:@"photo.on.rectangle" action:@selector(frameWatermarkButtonTapped:)];
    
    // 设置按钮
    self.settingsButton = [self createControlButtonWithImageName:@"ellipsis" action:@selector(settingsButtonTapped:)];
    
    // 添加到顶部控制栏
    [self.topControlsView addSubview:self.flashButton];
    [self.topControlsView addSubview:self.gridButton];
    [self.topControlsView addSubview:self.switchCameraButton];
    [self.topControlsView addSubview:self.frameWatermarkButton];
    [self.topControlsView addSubview:self.settingsButton];
}

- (void)setupBottomControls {
    // 底部控制栏
    self.bottomControlsView = [[UIView alloc] init];
    self.bottomControlsView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.bottomControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomControlsView];
    
    // 相册按钮
    self.galleryButton = [self createControlButtonWithImageName:@"photo.on.rectangle.angled" action:@selector(galleryButtonTapped:)];
    
    // 拍摄按钮
    self.captureButton = [[UIButton alloc] init];
    self.captureButton.backgroundColor = [UIColor whiteColor];
    self.captureButton.layer.cornerRadius = 35;
    self.captureButton.layer.borderWidth = 4;
    self.captureButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.captureButton addTarget:self action:@selector(captureButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.captureButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 滤镜按钮
    self.filterButton = [self createControlButtonWithImageName:@"camera.filters" action:@selector(filterButtonTapped:)];
    
    // 拍摄模式选择器
    self.modeSelector = [[UIView alloc] init];
    self.modeSelector.translatesAutoresizingMaskIntoConstraints = NO;
    [self setupModeSelector];
    
    // 添加到底部控制栏
    [self.bottomControlsView addSubview:self.galleryButton];
    [self.bottomControlsView addSubview:self.captureButton];
    [self.bottomControlsView addSubview:self.filterButton];
    [self.bottomControlsView addSubview:self.modeSelector];
}

- (void)setupModeSelector {
    // 拍摄模式标签
    NSArray *modes = @[@"Photo", @"Video", @"Square", @"Portrait", @"Pro"];
    CGFloat buttonWidth = 60;
    
    for (NSInteger i = 0; i < modes.count; i++) {
        UIButton *modeButton = [[UIButton alloc] init];
        [modeButton setTitle:modes[i] forState:UIControlStateNormal];
        [modeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [modeButton setTitleColor:[UIColor systemYellowColor] forState:UIControlStateSelected];
        modeButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        modeButton.tag = i;
        [modeButton addTarget:self action:@selector(modeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        modeButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        // 默认选中Photo模式
        if (i == 0) {
            modeButton.selected = YES;
        }
        
        [self.modeSelector addSubview:modeButton];
        
        // 设置约束
        [NSLayoutConstraint activateConstraints:@[
            [modeButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [modeButton.heightAnchor constraintEqualToConstant:30],
            [modeButton.centerYAnchor constraintEqualToAnchor:self.modeSelector.centerYAnchor],
            [modeButton.leadingAnchor constraintEqualToAnchor:self.modeSelector.leadingAnchor constant:i * buttonWidth]
        ]];
    }
}

- (void)setupProfessionalControls {
    // 右侧专业控制区
    self.professionalControlsView = [[UIView alloc] init];
    self.professionalControlsView.backgroundColor = [UIColor clearColor];
    self.professionalControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.professionalControlsView];
    
    // 曝光滑动条
    self.exposureSlider = [[UISlider alloc] init];
    self.exposureSlider.minimumValue = -2.0;
    self.exposureSlider.maximumValue = 2.0;
    self.exposureSlider.value = 0.0;
    self.exposureSlider.transform = CGAffineTransformMakeRotation(-M_PI_2); // 垂直方向
    [self.exposureSlider addTarget:self action:@selector(exposureSliderChanged:) forControlEvents:UIControlEventValueChanged];
    self.exposureSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.professionalControlsView addSubview:self.exposureSlider];
}

- (void)setupStatusIndicators {
    // 分辨率模式指示器
    self.resolutionModeLabel = [[UILabel alloc] init];
    self.resolutionModeLabel.text = @"12MP";
    self.resolutionModeLabel.textColor = [UIColor whiteColor];
    self.resolutionModeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.resolutionModeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.resolutionModeLabel.layer.cornerRadius = 4;
    self.resolutionModeLabel.textAlignment = NSTextAlignmentCenter;
    self.resolutionModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.resolutionModeLabel];
    
    // 相框水印状态指示器
    self.frameWatermarkIndicator = [[UIView alloc] init];
    self.frameWatermarkIndicator.backgroundColor = [UIColor systemYellowColor];
    self.frameWatermarkIndicator.layer.cornerRadius = 3;
    self.frameWatermarkIndicator.hidden = YES; // 默认隐藏
    self.frameWatermarkIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.frameWatermarkButton addSubview:self.frameWatermarkIndicator];
}

- (void)setupConstraints {
    // 安全区域
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    
    // 预览容器 - 全屏
    [NSLayoutConstraint activateConstraints:@[
        [self.previewContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.previewContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.previewContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    // 顶部控制栏
    [NSLayoutConstraint activateConstraints:@[
        [self.topControlsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.topControlsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.topControlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.topControlsView.heightAnchor constraintEqualToConstant:60]
    ]];
    
    // 顶部控制按钮布局
    [NSLayoutConstraint activateConstraints:@[
        [self.flashButton.leadingAnchor constraintEqualToAnchor:self.topControlsView.leadingAnchor constant:20],
        [self.flashButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.flashButton.widthAnchor constraintEqualToConstant:40],
        [self.flashButton.heightAnchor constraintEqualToConstant:40],
        
        [self.gridButton.leadingAnchor constraintEqualToAnchor:self.flashButton.trailingAnchor constant:20],
        [self.gridButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.gridButton.widthAnchor constraintEqualToConstant:40],
        [self.gridButton.heightAnchor constraintEqualToConstant:40],
        
        [self.switchCameraButton.trailingAnchor constraintEqualToAnchor:self.settingsButton.leadingAnchor constant:-20],
        [self.switchCameraButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.switchCameraButton.widthAnchor constraintEqualToConstant:40],
        [self.switchCameraButton.heightAnchor constraintEqualToConstant:40],
        
        [self.frameWatermarkButton.trailingAnchor constraintEqualToAnchor:self.switchCameraButton.leadingAnchor constant:-20],
        [self.frameWatermarkButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.frameWatermarkButton.widthAnchor constraintEqualToConstant:40],
        [self.frameWatermarkButton.heightAnchor constraintEqualToConstant:40],
        
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.topControlsView.trailingAnchor constant:-20],
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.settingsButton.widthAnchor constraintEqualToConstant:40],
        [self.settingsButton.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // 底部控制栏
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomControlsView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.bottomControlsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomControlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomControlsView.heightAnchor constraintEqualToConstant:120]
    ]];
    
    // 拍摄模式选择器
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSelector.bottomAnchor constraintEqualToAnchor:self.captureButton.topAnchor constant:-20],
        [self.modeSelector.centerXAnchor constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
        [self.modeSelector.widthAnchor constraintEqualToConstant:300],
        [self.modeSelector.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // 底部控制按钮布局
    [NSLayoutConstraint activateConstraints:@[
        [self.galleryButton.leadingAnchor constraintEqualToAnchor:self.bottomControlsView.leadingAnchor constant:30],
        [self.galleryButton.bottomAnchor constraintEqualToAnchor:self.bottomControlsView.bottomAnchor constant:-20],
        [self.galleryButton.widthAnchor constraintEqualToConstant:50],
        [self.galleryButton.heightAnchor constraintEqualToConstant:50],
        
        [self.captureButton.centerXAnchor constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
        [self.captureButton.bottomAnchor constraintEqualToAnchor:self.bottomControlsView.bottomAnchor constant:-20],
        [self.captureButton.widthAnchor constraintEqualToConstant:70],
        [self.captureButton.heightAnchor constraintEqualToConstant:70],
        
        [self.filterButton.trailingAnchor constraintEqualToAnchor:self.bottomControlsView.trailingAnchor constant:-30],
        [self.filterButton.bottomAnchor constraintEqualToAnchor:self.bottomControlsView.bottomAnchor constant:-20],
        [self.filterButton.widthAnchor constraintEqualToConstant:50],
        [self.filterButton.heightAnchor constraintEqualToConstant:50]
    ]];
    
    // 右侧专业控制区
    [NSLayoutConstraint activateConstraints:@[
        [self.professionalControlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.professionalControlsView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.professionalControlsView.widthAnchor constraintEqualToConstant:50],
        [self.professionalControlsView.heightAnchor constraintEqualToConstant:200]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.exposureSlider.centerXAnchor constraintEqualToAnchor:self.professionalControlsView.centerXAnchor],
        [self.exposureSlider.centerYAnchor constraintEqualToAnchor:self.professionalControlsView.centerYAnchor],
        [self.exposureSlider.widthAnchor constraintEqualToConstant:150] // 旋转后的高度
    ]];
    
    // 状态指示器
    [NSLayoutConstraint activateConstraints:@[
        [self.resolutionModeLabel.topAnchor constraintEqualToAnchor:self.topControlsView.bottomAnchor constant:10],
        [self.resolutionModeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.resolutionModeLabel.widthAnchor constraintEqualToConstant:50],
        [self.resolutionModeLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.frameWatermarkIndicator.topAnchor constraintEqualToAnchor:self.frameWatermarkButton.topAnchor constant:5],
        [self.frameWatermarkIndicator.trailingAnchor constraintEqualToAnchor:self.frameWatermarkButton.trailingAnchor constant:-5],
        [self.frameWatermarkIndicator.widthAnchor constraintEqualToConstant:6],
        [self.frameWatermarkIndicator.heightAnchor constraintEqualToConstant:6]
    ]];
}

#pragma mark - 辅助方法

- (UIButton *)createControlButtonWithImageName:(NSString *)imageName action:(SEL)action {
    UIButton *button = [[UIButton alloc] init];
    UIImage *image = [UIImage systemImageNamed:imageName];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

#pragma mark - 相机管理器设置

- (void)setupCameraManager {
    self.cameraManager = [CameraManager sharedManager];
    self.cameraManager.delegate = self;
    
    // 设置相机
    [self.cameraManager setupCameraWithPreviewView:self.previewContainer completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"相机设置成功");
            [self updateResolutionLabel];
        } else {
            NSLog(@"相机设置失败: %@", error.localizedDescription);
            // 显示错误提示
            [self showErrorAlert:error.localizedDescription];
        }
    }];
}

- (void)updateResolutionLabel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.cameraManager.currentResolutionMode == CameraResolutionModeUltraHigh) {
            self.resolutionModeLabel.text = @"48MP";
            self.resolutionModeLabel.backgroundColor = [UIColor systemYellowColor];
        } else {
            self.resolutionModeLabel.text = @"12MP";
            self.resolutionModeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        }
    });
}

- (void)showErrorAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 按钮事件

- (void)flashButtonTapped:(UIButton *)sender {
    // TODO: 实现闪光灯控制
    NSLog(@"闪光灯按钮点击");
}

- (void)gridButtonTapped:(UIButton *)sender {
    // TODO: 实现网格线控制
    NSLog(@"网格按钮点击");
}

- (void)switchCameraButtonTapped:(UIButton *)sender {
    [self.cameraManager switchCamera];
    NSLog(@"切换摄像头");
}

- (void)frameWatermarkButtonTapped:(UIButton *)sender {
    // TODO: 实现相框水印设置界面
    NSLog(@"相框水印按钮点击");
    
    // 模拟开关状态
    self.frameWatermarkIndicator.hidden = !self.frameWatermarkIndicator.hidden;
}

- (void)settingsButtonTapped:(UIButton *)sender {
    // TODO: 实现设置界面
    NSLog(@"设置按钮点击");
}

- (void)galleryButtonTapped:(UIButton *)sender {
    // TODO: 实现相册界面
    NSLog(@"相册按钮点击");
}

- (void)captureButtonTapped:(UIButton *)sender {
    [self.cameraManager capturePhoto];
    
    // 拍照动画效果
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)filterButtonTapped:(UIButton *)sender {
    // TODO: 实现滤镜选择界面
    NSLog(@"滤镜按钮点击");
}

- (void)modeButtonTapped:(UIButton *)sender {
    // 更新模式选择状态
    for (UIView *subview in self.modeSelector.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            ((UIButton *)subview).selected = NO;
        }
    }
    sender.selected = YES;
    
    NSLog(@"模式切换: %ld", (long)sender.tag);
}

- (void)exposureSliderChanged:(UISlider *)sender {
    // TODO: 实现曝光调节
    NSLog(@"曝光调节: %.1f", sender.value);
}

#pragma mark - 手势识别

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // 添加点击手势到预览容器
    if (!self.previewContainer.gestureRecognizers.count) {
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewTapped:)];
        [self.previewContainer addGestureRecognizer:tapGesture];
        
        // 双击手势切换分辨率模式
        UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewDoubleTapped:)];
        doubleTapGesture.numberOfTapsRequired = 2;
        [self.previewContainer addGestureRecognizer:doubleTapGesture];
        
        [tapGesture requireGestureRecognizerToFail:doubleTapGesture];
    }
}

- (void)previewTapped:(UITapGestureRecognizer *)gesture {
    // TODO: 实现点击对焦
    CGPoint location = [gesture locationInView:self.previewContainer];
    NSLog(@"点击对焦: (%.1f, %.1f)", location.x, location.y);
}

- (void)previewDoubleTapped:(UITapGestureRecognizer *)gesture {
    // 切换分辨率模式
    if (self.cameraManager.isUltraHighResolutionSupported) {
        CameraResolutionMode newMode = (self.cameraManager.currentResolutionMode == CameraResolutionModeStandard) ? CameraResolutionModeUltraHigh : CameraResolutionModeStandard;
        [self.cameraManager switchResolutionMode:newMode];
    }
}

#pragma mark - CameraManagerDelegate

- (void)cameraManager:(CameraManager *)manager didChangeState:(CameraState)state {
    NSLog(@"相机状态变化: %ld", (long)state);
    
    // 根据状态更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (state) {
            case CameraStateRunning:
                self.captureButton.enabled = YES;
                break;
            case CameraStateCapturing:
                self.captureButton.enabled = NO;
                break;
            case CameraStateError:
                self.captureButton.enabled = NO;
                break;
            default:
                break;
        }
    });
}

- (void)cameraManager:(CameraManager *)manager didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata {
    NSLog(@"拍照成功，图片尺寸: %.0fx%.0f", image.size.width, image.size.height);
    
    // 显示拍照成功的视觉反馈
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCaptureFlashEffect];
    });
}

- (void)cameraManager:(CameraManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"相机错误: %@", error.localizedDescription);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showErrorAlert:error.localizedDescription];
    });
}

- (void)cameraManager:(CameraManager *)manager didChangeResolutionMode:(CameraResolutionMode)mode {
    [self updateResolutionLabel];
}

#pragma mark - 视觉效果

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
    NSLog(@"收到内存警告");
    
    // 清理非必要的资源
    // TODO: 实现内存优化策略
}

@end
