//
//  CameraControlsView.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraControlsView.h"

@interface CameraControlsView ()

// 主要容器
@property (nonatomic, strong) UIView *previewContainer;

// 顶部控制栏
@property (nonatomic, strong) UIView *topControlsView;
@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIButton *gridButton;
@property (nonatomic, strong) UIButton *switchCameraButton;
@property (nonatomic, strong) UIButton *frameWatermarkButton;
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
@property (nonatomic, strong) UILabel *flashModeLabel;

// 网格线和对焦
@property (nonatomic, strong) UIView *gridLinesView;
@property (nonatomic, strong) UIView *focusIndicator;

@end

@implementation CameraControlsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI设置

- (void)setupUI {
    self.backgroundColor = [UIColor blackColor];
    
    [self setupPreviewContainer];
    [self setupTopControls];
    [self setupBottomControls];
    [self setupProfessionalControls];
    [self setupStatusIndicators];
    [self setupGridLines];
    [self setupFocusIndicator];
    [self setupConstraints];
}

- (void)setupPreviewContainer {
    self.previewContainer = [[UIView alloc] init];
    self.previewContainer.backgroundColor = [UIColor blackColor];
    self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.previewContainer];
    
    // 添加手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewTapped:)];
    [self.previewContainer addGestureRecognizer:tapGesture];
    
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewDoubleTapped:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self.previewContainer addGestureRecognizer:doubleTapGesture];
    
    [tapGesture requireGestureRecognizerToFail:doubleTapGesture];
}

- (void)setupTopControls {
    self.topControlsView = [[UIView alloc] init];
    self.topControlsView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.topControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.topControlsView];
    
    // 创建控制按钮
    self.flashButton = [self createControlButtonWithImageName:@"bolt.fill" action:@selector(flashButtonTapped:)];
    self.gridButton = [self createControlButtonWithImageName:@"grid" action:@selector(gridButtonTapped:)];
    self.switchCameraButton = [self createControlButtonWithImageName:@"arrow.triangle.2.circlepath.camera" action:@selector(switchCameraButtonTapped:)];
    self.frameWatermarkButton = [self createControlButtonWithImageName:@"photo.on.rectangle" action:@selector(frameWatermarkButtonTapped:)];
    self.settingsButton = [self createControlButtonWithImageName:@"ellipsis" action:@selector(settingsButtonTapped:)];
    
    [self.topControlsView addSubview:self.flashButton];
    [self.topControlsView addSubview:self.gridButton];
    [self.topControlsView addSubview:self.switchCameraButton];
    [self.topControlsView addSubview:self.frameWatermarkButton];
    [self.topControlsView addSubview:self.settingsButton];
}

- (void)setupBottomControls {
    self.bottomControlsView = [[UIView alloc] init];
    self.bottomControlsView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
    self.bottomControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.bottomControlsView];
    
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
    
    [self.bottomControlsView addSubview:self.galleryButton];
    [self.bottomControlsView addSubview:self.captureButton];
    [self.bottomControlsView addSubview:self.filterButton];
    [self.bottomControlsView addSubview:self.modeSelector];
}

- (void)setupModeSelector {
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
        
        if (i == 0) modeButton.selected = YES; // 默认选中Photo
        
        [self.modeSelector addSubview:modeButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [modeButton.widthAnchor constraintEqualToConstant:buttonWidth],
            [modeButton.heightAnchor constraintEqualToConstant:30],
            [modeButton.centerYAnchor constraintEqualToAnchor:self.modeSelector.centerYAnchor],
            [modeButton.leadingAnchor constraintEqualToAnchor:self.modeSelector.leadingAnchor constant:i * buttonWidth]
        ]];
    }
}

- (void)setupProfessionalControls {
    self.professionalControlsView = [[UIView alloc] init];
    self.professionalControlsView.backgroundColor = [UIColor clearColor];
    self.professionalControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.professionalControlsView];
    
    self.exposureSlider = [[UISlider alloc] init];
    self.exposureSlider.minimumValue = -2.0;
    self.exposureSlider.maximumValue = 2.0;
    self.exposureSlider.value = 0.0;
    self.exposureSlider.transform = CGAffineTransformMakeRotation(-M_PI_2);
    [self.exposureSlider addTarget:self action:@selector(exposureSliderChanged:) forControlEvents:UIControlEventValueChanged];
    self.exposureSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.professionalControlsView addSubview:self.exposureSlider];
}

- (void)setupStatusIndicators {
    self.resolutionModeLabel = [[UILabel alloc] init];
    self.resolutionModeLabel.text = @"12MP";
    self.resolutionModeLabel.textColor = [UIColor whiteColor];
    self.resolutionModeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.resolutionModeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.resolutionModeLabel.layer.cornerRadius = 4;
    self.resolutionModeLabel.textAlignment = NSTextAlignmentCenter;
    self.resolutionModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.resolutionModeLabel];
    
    self.flashModeLabel = [[UILabel alloc] init];
    self.flashModeLabel.text = @"AUTO";
    self.flashModeLabel.textColor = [UIColor whiteColor];
    self.flashModeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.flashModeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.flashModeLabel.layer.cornerRadius = 4;
    self.flashModeLabel.textAlignment = NSTextAlignmentCenter;
    self.flashModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.flashModeLabel];
    
    self.frameWatermarkIndicator = [[UIView alloc] init];
    self.frameWatermarkIndicator.backgroundColor = [UIColor systemYellowColor];
    self.frameWatermarkIndicator.layer.cornerRadius = 3;
    self.frameWatermarkIndicator.hidden = YES;
    self.frameWatermarkIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.frameWatermarkButton addSubview:self.frameWatermarkIndicator];
}

- (void)setupGridLines {
    self.gridLinesView = [[UIView alloc] init];
    self.gridLinesView.backgroundColor = [UIColor clearColor];
    self.gridLinesView.hidden = YES;
    self.gridLinesView.userInteractionEnabled = NO;
    self.gridLinesView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.previewContainer addSubview:self.gridLinesView];
}

- (void)setupFocusIndicator {
    self.focusIndicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    self.focusIndicator.backgroundColor = [UIColor clearColor];
    self.focusIndicator.layer.borderColor = [UIColor yellowColor].CGColor;
    self.focusIndicator.layer.borderWidth = 2.0;
    self.focusIndicator.layer.cornerRadius = 40;
    self.focusIndicator.hidden = YES;
    [self.previewContainer addSubview:self.focusIndicator];
}

- (void)setupConstraints {
    UILayoutGuide *safeArea = self.safeAreaLayoutGuide;
    
    // 预览容器
    [NSLayoutConstraint activateConstraints:@[
        [self.previewContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.previewContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.previewContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    
    // 顶部控制栏
    [NSLayoutConstraint activateConstraints:@[
        [self.topControlsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.topControlsView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.topControlsView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.topControlsView.heightAnchor constraintEqualToConstant:60]
    ]];
    
    // 顶部按钮约束
    [NSLayoutConstraint activateConstraints:@[
        [self.flashButton.leadingAnchor constraintEqualToAnchor:self.topControlsView.leadingAnchor constant:20],
        [self.flashButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.flashButton.widthAnchor constraintEqualToConstant:40],
        [self.flashButton.heightAnchor constraintEqualToConstant:40],
        
        [self.gridButton.leadingAnchor constraintEqualToAnchor:self.flashButton.trailingAnchor constant:20],
        [self.gridButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.gridButton.widthAnchor constraintEqualToConstant:40],
        [self.gridButton.heightAnchor constraintEqualToConstant:40],
        
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.topControlsView.trailingAnchor constant:-20],
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.settingsButton.widthAnchor constraintEqualToConstant:40],
        [self.settingsButton.heightAnchor constraintEqualToConstant:40],
        
        [self.switchCameraButton.trailingAnchor constraintEqualToAnchor:self.settingsButton.leadingAnchor constant:-20],
        [self.switchCameraButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.switchCameraButton.widthAnchor constraintEqualToConstant:40],
        [self.switchCameraButton.heightAnchor constraintEqualToConstant:40],
        
        [self.frameWatermarkButton.trailingAnchor constraintEqualToAnchor:self.switchCameraButton.leadingAnchor constant:-20],
        [self.frameWatermarkButton.centerYAnchor constraintEqualToAnchor:self.topControlsView.centerYAnchor],
        [self.frameWatermarkButton.widthAnchor constraintEqualToConstant:40],
        [self.frameWatermarkButton.heightAnchor constraintEqualToConstant:40]
    ]];
    
    // 底部控制栏
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomControlsView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.bottomControlsView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.bottomControlsView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.bottomControlsView.heightAnchor constraintEqualToConstant:120]
    ]];
    
    // 底部按钮约束
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSelector.bottomAnchor constraintEqualToAnchor:self.captureButton.topAnchor constant:-20],
        [self.modeSelector.centerXAnchor constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
        [self.modeSelector.widthAnchor constraintEqualToConstant:300],
        [self.modeSelector.heightAnchor constraintEqualToConstant:30],
        
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
    
    // 专业控制区
    [NSLayoutConstraint activateConstraints:@[
        [self.professionalControlsView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.professionalControlsView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.professionalControlsView.widthAnchor constraintEqualToConstant:50],
        [self.professionalControlsView.heightAnchor constraintEqualToConstant:200]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.exposureSlider.centerXAnchor constraintEqualToAnchor:self.professionalControlsView.centerXAnchor],
        [self.exposureSlider.centerYAnchor constraintEqualToAnchor:self.professionalControlsView.centerYAnchor],
        [self.exposureSlider.widthAnchor constraintEqualToConstant:150]
    ]];
    
    // 状态指示器
    [NSLayoutConstraint activateConstraints:@[
        [self.resolutionModeLabel.topAnchor constraintEqualToAnchor:self.topControlsView.bottomAnchor constant:10],
        [self.resolutionModeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.resolutionModeLabel.widthAnchor constraintEqualToConstant:50],
        [self.resolutionModeLabel.heightAnchor constraintEqualToConstant:20],
        
        [self.flashModeLabel.topAnchor constraintEqualToAnchor:self.resolutionModeLabel.bottomAnchor constant:5],
        [self.flashModeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [self.flashModeLabel.widthAnchor constraintEqualToConstant:50],
        [self.flashModeLabel.heightAnchor constraintEqualToConstant:20],
        
        [self.frameWatermarkIndicator.topAnchor constraintEqualToAnchor:self.frameWatermarkButton.topAnchor constant:5],
        [self.frameWatermarkIndicator.trailingAnchor constraintEqualToAnchor:self.frameWatermarkButton.trailingAnchor constant:-5],
        [self.frameWatermarkIndicator.widthAnchor constraintEqualToConstant:6],
        [self.frameWatermarkIndicator.heightAnchor constraintEqualToConstant:6]
    ]];
    
    // 网格线约束
    [NSLayoutConstraint activateConstraints:@[
        [self.gridLinesView.topAnchor constraintEqualToAnchor:self.topControlsView.bottomAnchor],
        [self.gridLinesView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.gridLinesView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.gridLinesView.bottomAnchor constraintEqualToAnchor:self.bottomControlsView.topAnchor]
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

#pragma mark - 事件处理 (转发给代理)

- (void)flashButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapFlashButton)]) {
        [self.delegate didTapFlashButton];
    }
}

- (void)gridButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapGridButton)]) {
        [self.delegate didTapGridButton];
    }
}

- (void)switchCameraButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapSwitchCameraButton)]) {
        [self.delegate didTapSwitchCameraButton];
    }
}

- (void)frameWatermarkButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapFrameWatermarkButton)]) {
        [self.delegate didTapFrameWatermarkButton];
    }
}

- (void)settingsButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapSettingsButton)]) {
        [self.delegate didTapSettingsButton];
    }
}

- (void)galleryButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapGalleryButton)]) {
        [self.delegate didTapGalleryButton];
    }
}

- (void)captureButtonTapped:(UIButton *)sender {
    // 按钮动画
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
    
    if ([self.delegate respondsToSelector:@selector(didTapCaptureButton)]) {
        [self.delegate didTapCaptureButton];
    }
}

- (void)filterButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didTapFilterButton)]) {
        [self.delegate didTapFilterButton];
    }
}

- (void)modeButtonTapped:(UIButton *)sender {
    // 更新UI状态
    for (UIView *subview in self.modeSelector.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            ((UIButton *)subview).selected = NO;
        }
    }
    sender.selected = YES;
    
    if ([self.delegate respondsToSelector:@selector(didSelectMode:)]) {
        [self.delegate didSelectMode:sender.tag];
    }
}

- (void)exposureSliderChanged:(UISlider *)sender {
    if ([self.delegate respondsToSelector:@selector(didChangeExposure:)]) {
        [self.delegate didChangeExposure:sender.value];
    }
}

- (void)previewTapped:(UITapGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.previewContainer];
    if ([self.delegate respondsToSelector:@selector(didTapPreviewAtPoint:)]) {
        [self.delegate didTapPreviewAtPoint:location];
    }
}

- (void)previewDoubleTapped:(UITapGestureRecognizer *)gesture {
    if ([self.delegate respondsToSelector:@selector(didDoubleTapPreview)]) {
        [self.delegate didDoubleTapPreview];
    }
}

#pragma mark - 公开更新接口

- (void)updateResolutionMode:(NSString *)modeText highlighted:(BOOL)highlighted {
    self.resolutionModeLabel.text = modeText;
    self.resolutionModeLabel.backgroundColor = highlighted ? [UIColor systemYellowColor] : [UIColor colorWithWhite:0.0 alpha:0.5];
}

- (void)updateFlashMode:(NSString *)modeText highlighted:(BOOL)highlighted {
    self.flashModeLabel.text = modeText;
    self.flashModeLabel.backgroundColor = highlighted ? [UIColor systemYellowColor] : [UIColor colorWithWhite:0.0 alpha:0.5];
}

- (void)updateFrameWatermarkStatus:(BOOL)enabled {
    self.frameWatermarkIndicator.hidden = !enabled;
}

- (void)updateGalleryButtonWithImage:(UIImage *)image {
    if (image) {
        // 创建缩略图
        CGSize thumbnailSize = CGSizeMake(50, 50);
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, NO, 0.0);
        [image drawInRect:CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height)];
        UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [self.galleryButton setBackgroundImage:thumbnail forState:UIControlStateNormal];
        self.galleryButton.layer.cornerRadius = 8;
        self.galleryButton.layer.masksToBounds = YES;
        self.galleryButton.layer.borderWidth = 2;
        self.galleryButton.layer.borderColor = [UIColor whiteColor].CGColor;
    }
}

- (void)showGridLines:(BOOL)show {
    [UIView animateWithDuration:0.3 animations:^{
        self.gridLinesView.hidden = !show;
        self.gridButton.tintColor = show ? [UIColor systemYellowColor] : [UIColor whiteColor];
    }];
}

- (void)showFocusIndicatorAtPoint:(CGPoint)point {
    self.focusIndicator.center = point;
    self.focusIndicator.hidden = NO;
    self.focusIndicator.transform = CGAffineTransformMakeScale(1.2, 1.2);
    self.focusIndicator.layer.borderColor = [UIColor systemYellowColor].CGColor;
    
    [UIView animateWithDuration:0.15 animations:^{
        self.focusIndicator.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 delay:1.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.focusIndicator.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.focusIndicator.alpha = 1.0;
            self.focusIndicator.hidden = YES;
            self.focusIndicator.layer.borderColor = [UIColor yellowColor].CGColor;
        }];
    }];
}

#pragma mark - 布局更新

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 重新创建网格线以适应屏幕尺寸
    if (self.gridLinesView.subviews.count == 0) {
        [self createGridLinesWithFrame];
    }
}

- (void)createGridLinesWithFrame {
    [self.gridLinesView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    CGRect gridFrame = self.gridLinesView.bounds;
    if (CGRectIsEmpty(gridFrame)) return;
    
    for (int i = 1; i <= 2; i++) {
        // 竖线
        UIView *verticalLine = [[UIView alloc] init];
        verticalLine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        CGFloat x = gridFrame.size.width / 3.0 * i;
        verticalLine.frame = CGRectMake(x, 0, 1, gridFrame.size.height);
        [self.gridLinesView addSubview:verticalLine];
        
        // 横线
        UIView *horizontalLine = [[UIView alloc] init];
        horizontalLine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        CGFloat y = gridFrame.size.height / 3.0 * i;
        horizontalLine.frame = CGRectMake(0, y, gridFrame.size.width, 1);
        [self.gridLinesView addSubview:horizontalLine];
    }
}

@end