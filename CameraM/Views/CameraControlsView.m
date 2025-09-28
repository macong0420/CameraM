//
//  CameraControlsView.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraControlsView.h"
#import "../Managers/CameraManager.h"
#import "WatermarkPanelView.h"
#import <math.h>

static inline CGFloat CMAspectRatioValue(CameraAspectRatio ratio,
                                         CameraDeviceOrientation orientation) {
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

static const CGFloat CMModeSelectorWidth = 60.0f;

@interface CameraControlsView () <WatermarkPanelViewDelegate>

// 主要容器
@property(nonatomic, strong) UIView *previewContainer;

// 顶部控制栏
@property(nonatomic, strong) UIView *topControlsView;
@property(nonatomic, strong) UIButton *flashButton;
@property(nonatomic, strong) UIButton *gridButton;
@property(nonatomic, strong) UIButton *switchCameraButton;
@property(nonatomic, strong) UIButton *frameWatermarkButton;
@property(nonatomic, strong) UIButton *settingsButton;

// 底部控制栏
@property(nonatomic, strong) UIView *bottomControlsView;
@property(nonatomic, strong) UIView *modeSelector;
@property(nonatomic, strong) UIButton *galleryButton;
@property(nonatomic, strong) UIButton *captureButton;
@property(nonatomic, strong) UIActivityIndicatorView *captureLoadingIndicator;
@property(nonatomic, assign) BOOL captureButtonLoading;
@property(nonatomic, assign) BOOL captureButtonDesiredEnabled;

// 右侧专业控制区
@property(nonatomic, strong) UIView *professionalControlsView;
@property(nonatomic, strong) UISlider *exposureSlider;

// 状态指示器
@property(nonatomic, strong) UILabel *resolutionModeLabel;
@property(nonatomic, strong) UIView *frameWatermarkIndicator;
@property(nonatomic, strong) UILabel *flashModeLabel;

// 网格线和对焦
@property(nonatomic, strong) UIView *gridLinesView;
@property(nonatomic, strong) UIView *focusIndicator;

// 比例相关
@property(nonatomic, strong) UIButton *aspectRatioButton;
@property(nonatomic, strong) UIView *aspectRatioPopover;
@property(nonatomic, strong) CAShapeLayer *aspectRatioMaskLayer;

// 镜头选择
@property(nonatomic, strong) UIView *lensSelectorContainer;
@property(nonatomic, strong) UIStackView *lensStackView;
@property(nonatomic, copy) NSArray<UIButton *> *lensButtons;
@property(nonatomic, copy) NSArray<CMCameraLensOption *> *lensOptions;
@property(nonatomic, copy) NSString *currentLensIdentifier;

// 横屏适配
@property(nonatomic, assign) CameraDeviceOrientation currentOrientation;
@property(nonatomic, strong) NSArray<NSLayoutConstraint *> *portraitConstraints;
@property(nonatomic, strong)
    NSArray<NSLayoutConstraint *> *landscapeConstraints;

// 水印配置
@property(nonatomic, strong) UIView *watermarkBackdropView;
@property(nonatomic, strong) WatermarkPanelView *watermarkPanel;
@property(nonatomic, strong) NSLayoutConstraint *watermarkPanelBottomConstraint;
@property(nonatomic, strong) NSLayoutConstraint *watermarkPanelHeightConstraint;
@property(nonatomic, assign) BOOL watermarkPanelVisible;
@property(nonatomic, strong) CMWatermarkConfiguration *watermarkConfiguration;
@property(nonatomic, assign) CameraAspectRatio activeAspectRatio;
@property(nonatomic, assign) CGRect previewVideoRect;

@end

@implementation CameraControlsView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _currentOrientation = CameraDeviceOrientationPortrait; // 默认竖屏
    _watermarkConfiguration = [CMWatermarkConfiguration defaultConfiguration];
    _activeAspectRatio = CameraAspectRatio4to3;
    _lensOptions = @[];
    _lensButtons = @[];
    _currentLensIdentifier = @"";
    _captureButtonDesiredEnabled = YES;
    _captureButtonLoading = NO;
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
  [self setupAspectRatioButton];
  [self setupAspectRatioMask];
  [self setupLensSelector];
  [self setupWatermarkPanel];
  [self setupPortraitLayout]; // 默认竖屏布局
}

- (void)setupPreviewContainer {
  self.previewContainer = [[UIView alloc] initWithFrame:self.bounds];
  self.previewContainer.backgroundColor = [UIColor blackColor];
  self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
  self.previewContainer.contentMode = UIViewContentModeScaleAspectFill;
  self.previewContainer.clipsToBounds = YES;

  [self addSubview:self.previewContainer];

  // 添加手势
  UITapGestureRecognizer *tapGesture =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(previewTapped:)];
  [self.previewContainer addGestureRecognizer:tapGesture];

  UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(previewDoubleTapped:)];
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
  self.flashButton =
      [self createControlButtonWithImageName:@"bolt.fill"
                                      action:@selector(flashButtonTapped:)];
  self.gridButton =
      [self createControlButtonWithImageName:@"grid"
                                      action:@selector(gridButtonTapped:)];

  // 比例按钮（显示当前比例文字）
  self.aspectRatioButton = [[UIButton alloc] init];
  [self.aspectRatioButton setTitle:@"4:3" forState:UIControlStateNormal];
  [self.aspectRatioButton setTitleColor:[UIColor whiteColor]
                               forState:UIControlStateNormal];
  self.aspectRatioButton.titleLabel.font =
      [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  self.aspectRatioButton.backgroundColor = [UIColor colorWithWhite:0.0
                                                             alpha:0.3];
  self.aspectRatioButton.layer.cornerRadius = 6;
  [self.aspectRatioButton addTarget:self
                             action:@selector(aspectRatioButtonTapped:)
                   forControlEvents:UIControlEventTouchUpInside];
  self.aspectRatioButton.translatesAutoresizingMaskIntoConstraints = NO;

  self.switchCameraButton = [self
      createControlButtonWithImageName:@"arrow.triangle.2.circlepath.camera"
                                action:@selector(switchCameraButtonTapped:)];
  self.frameWatermarkButton = [self
      createControlButtonWithImageName:@"photo.on.rectangle"
                                action:@selector(frameWatermarkButtonTapped:)];
  self.settingsButton =
      [self createControlButtonWithImageName:@"ellipsis"
                                      action:@selector(settingsButtonTapped:)];

  [self.topControlsView addSubview:self.flashButton];
  [self.topControlsView addSubview:self.gridButton];
  [self.topControlsView addSubview:self.aspectRatioButton];
  [self.topControlsView addSubview:self.switchCameraButton];
  [self.topControlsView addSubview:self.frameWatermarkButton];
  [self.topControlsView addSubview:self.settingsButton];
}

- (void)setupBottomControls {
  self.bottomControlsView = [[UIView alloc] init];
  self.bottomControlsView.backgroundColor = [UIColor colorWithWhite:0.0
                                                              alpha:0.3];
  self.bottomControlsView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.bottomControlsView];

  // 相册按钮
  self.galleryButton =
      [self createControlButtonWithImageName:@"photo.on.rectangle.angled"
                                      action:@selector(galleryButtonTapped:)];

  // 拍摄按钮
  self.captureButton = [[UIButton alloc] init];
  self.captureButton.backgroundColor = [UIColor whiteColor];
  self.captureButton.layer.cornerRadius = 35;
  self.captureButton.layer.borderWidth = 4;
  self.captureButton.layer.borderColor = [UIColor whiteColor].CGColor;
  [self.captureButton addTarget:self
                         action:@selector(captureButtonTapped:)
               forControlEvents:UIControlEventTouchUpInside];
  self.captureButton.translatesAutoresizingMaskIntoConstraints = NO;

  self.captureLoadingIndicator =
      [[UIActivityIndicatorView alloc]
          initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  self.captureLoadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  self.captureLoadingIndicator.hidesWhenStopped = YES;
  self.captureLoadingIndicator.color = [UIColor systemOrangeColor];
  [self.captureButton addSubview:self.captureLoadingIndicator];

  // 拍摄模式选择器
  self.modeSelector = [[UIView alloc] init];
  self.modeSelector.translatesAutoresizingMaskIntoConstraints = NO;
  [self setupModeSelector];

  [self.bottomControlsView addSubview:self.galleryButton];
  [self.bottomControlsView addSubview:self.captureButton];
  [self.bottomControlsView addSubview:self.modeSelector];

  [NSLayoutConstraint activateConstraints:@[
    [self.captureLoadingIndicator.centerXAnchor
        constraintEqualToAnchor:self.captureButton.centerXAnchor],
    [self.captureLoadingIndicator.centerYAnchor
        constraintEqualToAnchor:self.captureButton.centerYAnchor]
  ]];
}

- (void)setupModeSelector {
  UIButton *photoButton = [[UIButton alloc] init];
  [photoButton setTitle:@"Photo" forState:UIControlStateNormal];
  [photoButton setTitleColor:[UIColor whiteColor]
                    forState:UIControlStateNormal];
  [photoButton setTitleColor:[UIColor systemYellowColor]
                    forState:UIControlStateSelected];
  photoButton.titleLabel.font = [UIFont systemFontOfSize:16
                                                  weight:UIFontWeightMedium];
  photoButton.tag = 0;
  [photoButton addTarget:self
                  action:@selector(modeButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
  photoButton.translatesAutoresizingMaskIntoConstraints = NO;
  photoButton.selected = YES;

  [self.modeSelector addSubview:photoButton];

  [NSLayoutConstraint activateConstraints:@[
    [photoButton.centerXAnchor
        constraintEqualToAnchor:self.modeSelector.centerXAnchor],
    [photoButton.centerYAnchor
        constraintEqualToAnchor:self.modeSelector.centerYAnchor],
    [photoButton.widthAnchor constraintEqualToConstant:CMModeSelectorWidth],
    [photoButton.heightAnchor constraintEqualToConstant:30]
  ]];
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
  [self.exposureSlider addTarget:self
                          action:@selector(exposureSliderChanged:)
                forControlEvents:UIControlEventValueChanged];
  self.exposureSlider.translatesAutoresizingMaskIntoConstraints = NO;
  [self.professionalControlsView addSubview:self.exposureSlider];
}

- (void)setupStatusIndicators {
  self.resolutionModeLabel = [[UILabel alloc] init];
  self.resolutionModeLabel.text = @"12MP";
  self.resolutionModeLabel.textColor = [UIColor whiteColor];
  self.resolutionModeLabel.font = [UIFont systemFontOfSize:12
                                                    weight:UIFontWeightMedium];
  self.resolutionModeLabel.backgroundColor = [UIColor colorWithWhite:0.0
                                                               alpha:0.5];
  self.resolutionModeLabel.layer.cornerRadius = 4;
  self.resolutionModeLabel.textAlignment = NSTextAlignmentCenter;
  self.resolutionModeLabel.layer.masksToBounds = YES;
  self.resolutionModeLabel.userInteractionEnabled = YES;
  self.resolutionModeLabel.accessibilityLabel =
      NSLocalizedString(@"Photo resolution", nil);
  self.resolutionModeLabel.accessibilityTraits = UIAccessibilityTraitButton;
  self.resolutionModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.resolutionModeLabel];

  UITapGestureRecognizer *resolutionTap = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(resolutionModeLabelTapped:)];
  [self.resolutionModeLabel addGestureRecognizer:resolutionTap];

  self.flashModeLabel = [[UILabel alloc] init];
  self.flashModeLabel.text = @"AUTO";
  self.flashModeLabel.textColor = [UIColor whiteColor];
  self.flashModeLabel.font = [UIFont systemFontOfSize:12
                                               weight:UIFontWeightMedium];
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

- (void)setupAspectRatioButton {
  // 比例按钮已在setupTopControls中创建
  // 这里创建弹层
  [self setupAspectRatioPopover];
}

- (void)setupAspectRatioPopover {
  self.aspectRatioPopover = [[UIView alloc] init];
  self.aspectRatioPopover.backgroundColor = [UIColor colorWithWhite:0.1
                                                              alpha:0.9];
  self.aspectRatioPopover.layer.cornerRadius = 12;
  self.aspectRatioPopover.layer.shadowColor = [UIColor blackColor].CGColor;
  self.aspectRatioPopover.layer.shadowOffset = CGSizeMake(0, 4);
  self.aspectRatioPopover.layer.shadowOpacity = 0.3;
  self.aspectRatioPopover.layer.shadowRadius = 8;
  self.aspectRatioPopover.hidden = YES;
  self.aspectRatioPopover.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.aspectRatioPopover];

  // 创建弹层内容
  NSArray *ratioData = @[
    @{
      @"title" : @"4:3",
      @"subtitle" : @"传统相机",
      @"tag" : @(CameraAspectRatio4to3)
    },
    @{
      @"title" : @"1:1",
      @"subtitle" : @"正方形",
      @"tag" : @(CameraAspectRatio1to1)
    },
    @{
      @"title" : @"Xpan",
      @"subtitle" : @"超宽",
      @"tag" : @(CameraAspectRatioXpan)
    }
  ];

  for (NSInteger i = 0; i < ratioData.count; i++) {
    NSDictionary *data = ratioData[i];

    UIButton *optionButton = [[UIButton alloc] init];
    optionButton.backgroundColor = [UIColor clearColor];
    optionButton.tag = [data[@"tag"] integerValue];
    [optionButton addTarget:self
                     action:@selector(aspectRatioOptionTapped:)
           forControlEvents:UIControlEventTouchUpInside];
    optionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.aspectRatioPopover addSubview:optionButton];

    // 主标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = data[@"title"];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [optionButton addSubview:titleLabel];

    // 副标题
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = data[@"subtitle"];
    subtitleLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12
                                           weight:UIFontWeightRegular];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [optionButton addSubview:subtitleLabel];

    // 选中标记
    UIImageView *checkmark = [[UIImageView alloc] init];
    checkmark.image = [UIImage systemImageNamed:@"checkmark"];
    checkmark.tintColor = [UIColor systemYellowColor];
    checkmark.hidden = (i != 0); // 默认4:3选中
    checkmark.tag = 1000 + i;    // 特殊tag用于查找
    checkmark.translatesAutoresizingMaskIntoConstraints = NO;
    [optionButton addSubview:checkmark];

    // 按钮约束
    [NSLayoutConstraint activateConstraints:@[
      [optionButton.leadingAnchor
          constraintEqualToAnchor:self.aspectRatioPopover.leadingAnchor],
      [optionButton.trailingAnchor
          constraintEqualToAnchor:self.aspectRatioPopover.trailingAnchor],
      [optionButton.topAnchor
          constraintEqualToAnchor:self.aspectRatioPopover.topAnchor
                         constant:i * 50],
      [optionButton.heightAnchor constraintEqualToConstant:50],

      [titleLabel.leadingAnchor
          constraintEqualToAnchor:optionButton.leadingAnchor
                         constant:20],
      [titleLabel.topAnchor constraintEqualToAnchor:optionButton.topAnchor
                                           constant:8],

      [subtitleLabel.leadingAnchor
          constraintEqualToAnchor:optionButton.leadingAnchor
                         constant:20],
      [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor
                                              constant:2],

      [checkmark.trailingAnchor
          constraintEqualToAnchor:optionButton.trailingAnchor
                         constant:-20],
      [checkmark.centerYAnchor
          constraintEqualToAnchor:optionButton.centerYAnchor],
      [checkmark.widthAnchor constraintEqualToConstant:20],
      [checkmark.heightAnchor constraintEqualToConstant:20]
    ]];
  }

  // 弹层约束
  [NSLayoutConstraint activateConstraints:@[
    [self.aspectRatioPopover.topAnchor
        constraintEqualToAnchor:self.aspectRatioButton.bottomAnchor
                       constant:10],
    [self.aspectRatioPopover.centerXAnchor
        constraintEqualToAnchor:self.aspectRatioButton.centerXAnchor],
    [self.aspectRatioPopover.widthAnchor constraintEqualToConstant:140],
    [self.aspectRatioPopover.heightAnchor constraintEqualToConstant:150]
  ]];
}

- (void)setupAspectRatioMask {
  // 创建比例遮罩层
  self.aspectRatioMaskLayer = [CAShapeLayer layer];
  self.aspectRatioMaskLayer.fillColor =
      [UIColor colorWithWhite:0.0 alpha:0.4].CGColor;
  self.aspectRatioMaskLayer.fillRule = kCAFillRuleEvenOdd;
  [self.previewContainer.layer addSublayer:self.aspectRatioMaskLayer];
}

- (void)setupLensSelector {
  self.lensSelectorContainer = [[UIView alloc] init];
  self.lensSelectorContainer.translatesAutoresizingMaskIntoConstraints = NO;
  self.lensSelectorContainer.backgroundColor =
      [[UIColor colorWithWhite:0.0 alpha:0.75] colorWithAlphaComponent:0.35];
  self.lensSelectorContainer.layer.cornerRadius = 28.0;
  self.lensSelectorContainer.layer.masksToBounds = YES;
  self.lensSelectorContainer.hidden = YES;
  [self addSubview:self.lensSelectorContainer];

  self.lensStackView = [[UIStackView alloc] init];
  self.lensStackView.translatesAutoresizingMaskIntoConstraints = NO;
  self.lensStackView.axis = UILayoutConstraintAxisHorizontal;
  self.lensStackView.alignment = UIStackViewAlignmentCenter;
  self.lensStackView.spacing = 6.0;
  [self.lensSelectorContainer addSubview:self.lensStackView];

  [NSLayoutConstraint activateConstraints:@[
    [self.lensStackView.topAnchor
        constraintEqualToAnchor:self.lensSelectorContainer.topAnchor
                       constant:8.0],
    [self.lensStackView.bottomAnchor
        constraintEqualToAnchor:self.lensSelectorContainer.bottomAnchor
                       constant:-8.0],
    [self.lensStackView.leadingAnchor
        constraintEqualToAnchor:self.lensSelectorContainer.leadingAnchor
                       constant:12.0],
    [self.lensStackView.trailingAnchor
        constraintEqualToAnchor:self.lensSelectorContainer.trailingAnchor
                       constant:-12.0]
  ]];
}

- (void)setupWatermarkPanel {

  self.watermarkBackdropView = [[UIView alloc] init];
  self.watermarkBackdropView.translatesAutoresizingMaskIntoConstraints = NO;
  self.watermarkBackdropView.backgroundColor = [UIColor colorWithWhite:0
                                                                 alpha:0.6];
  self.watermarkBackdropView.alpha = 0.0;
  self.watermarkBackdropView.hidden = YES;
  [self addSubview:self.watermarkBackdropView];

  [NSLayoutConstraint activateConstraints:@[
    [self.watermarkBackdropView.topAnchor
        constraintEqualToAnchor:self.topAnchor],
    [self.watermarkBackdropView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.watermarkBackdropView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.watermarkBackdropView.bottomAnchor
        constraintEqualToAnchor:self.bottomAnchor]
  ]];

  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(handleWatermarkBackdropTap)];
  [self.watermarkBackdropView addGestureRecognizer:tap];

  self.watermarkPanel = [[WatermarkPanelView alloc] initWithFrame:CGRectZero];
  self.watermarkPanel.translatesAutoresizingMaskIntoConstraints = NO;
  self.watermarkPanel.delegate = self;
  self.watermarkPanel.hidden = YES;
  [self addSubview:self.watermarkPanel];

  self.watermarkPanelBottomConstraint = [self.watermarkPanel.bottomAnchor
      constraintEqualToAnchor:self.bottomAnchor
                     constant:0.0];
  self.watermarkPanelHeightConstraint =
      [self.watermarkPanel.heightAnchor constraintEqualToConstant:0.0];

  [NSLayoutConstraint activateConstraints:@[
    [self.watermarkPanel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.watermarkPanel.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    self.watermarkPanelHeightConstraint, self.watermarkPanelBottomConstraint
  ]];

  [self updateWatermarkPanelHeightConstraints];
}

- (CGFloat)desiredWatermarkPanelHeight {
  CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
  CGFloat targetHeight = screenHeight * 0.7f;
  CGFloat minimumHeight = 360.0f;
  CGFloat availableHeight = screenHeight - self.safeAreaInsets.top - 24.0f;
  if (availableHeight < minimumHeight) {
    availableHeight = minimumHeight;
  }
  targetHeight = MIN(targetHeight, availableHeight);
  targetHeight = MAX(targetHeight, minimumHeight);
  return targetHeight;
}

- (void)updateWatermarkPanelHeightConstraints {
  if (!self.watermarkPanelHeightConstraint ||
      !self.watermarkPanelBottomConstraint) {
    return;
  }
  CGFloat panelHeight = [self desiredWatermarkPanelHeight];
  self.watermarkPanelHeightConstraint.constant = panelHeight;
  self.watermarkPanelBottomConstraint.constant =
      self.watermarkPanelVisible ? 0.0f : panelHeight;
}

- (void)setupConstraints {
  UILayoutGuide *safeArea = self.safeAreaLayoutGuide;

  // 预览容器
  [NSLayoutConstraint activateConstraints:@[
    [self.previewContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.previewContainer.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.previewContainer.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.previewContainer.bottomAnchor
        constraintEqualToAnchor:self.bottomAnchor]
  ]];

  // 调试：在下一个运行循环中检查约束是否生效
  dispatch_async(dispatch_get_main_queue(), ^{
    NSLog(@"🔍 约束设置后 - CameraControlsView: %@, 预览容器: %@",
          NSStringFromCGRect(self.frame),
          NSStringFromCGRect(self.previewContainer.frame));
  });

  // 顶部控制栏
  [NSLayoutConstraint activateConstraints:@[
    [self.topControlsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [self.topControlsView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.topControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.topControlsView.heightAnchor constraintEqualToConstant:60]
  ]];

  // 顶部按钮约束
  [NSLayoutConstraint activateConstraints:@[
    [self.flashButton.leadingAnchor
        constraintEqualToAnchor:self.topControlsView.leadingAnchor
                       constant:20],
    [self.flashButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.flashButton.widthAnchor constraintEqualToConstant:40],
    [self.flashButton.heightAnchor constraintEqualToConstant:40],

    [self.gridButton.leadingAnchor
        constraintEqualToAnchor:self.flashButton.trailingAnchor
                       constant:15],
    [self.gridButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.gridButton.widthAnchor constraintEqualToConstant:40],
    [self.gridButton.heightAnchor constraintEqualToConstant:40],

    // 比例按钮
    [self.aspectRatioButton.leadingAnchor
        constraintEqualToAnchor:self.gridButton.trailingAnchor
                       constant:15],
    [self.aspectRatioButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.aspectRatioButton.widthAnchor constraintEqualToConstant:45],
    [self.aspectRatioButton.heightAnchor constraintEqualToConstant:30],

    [self.settingsButton.trailingAnchor
        constraintEqualToAnchor:self.topControlsView.trailingAnchor
                       constant:-20],
    [self.settingsButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.settingsButton.widthAnchor constraintEqualToConstant:40],
    [self.settingsButton.heightAnchor constraintEqualToConstant:40],

    [self.switchCameraButton.trailingAnchor
        constraintEqualToAnchor:self.settingsButton.leadingAnchor
                       constant:-15],
    [self.switchCameraButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.switchCameraButton.widthAnchor constraintEqualToConstant:40],
    [self.switchCameraButton.heightAnchor constraintEqualToConstant:40],

    [self.frameWatermarkButton.trailingAnchor
        constraintEqualToAnchor:self.switchCameraButton.leadingAnchor
                       constant:-15],
    [self.frameWatermarkButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.frameWatermarkButton.widthAnchor constraintEqualToConstant:40],
    [self.frameWatermarkButton.heightAnchor constraintEqualToConstant:40]
  ]];

  // 底部控制栏
  [NSLayoutConstraint activateConstraints:@[
    [self.bottomControlsView.bottomAnchor
        constraintEqualToAnchor:safeArea.bottomAnchor],
    [self.bottomControlsView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.bottomControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.bottomControlsView.heightAnchor constraintEqualToConstant:120]
  ]];

  // 底部按钮约束
  [NSLayoutConstraint activateConstraints:@[
    [self.modeSelector.bottomAnchor
        constraintEqualToAnchor:self.captureButton.topAnchor
                       constant:-20],
    [self.modeSelector.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.modeSelector.widthAnchor
        constraintEqualToConstant:CMModeSelectorWidth],
    [self.modeSelector.heightAnchor constraintEqualToConstant:30],

    [self.galleryButton.leadingAnchor
        constraintEqualToAnchor:self.bottomControlsView.leadingAnchor
                       constant:30],
    [self.galleryButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-20],
    [self.galleryButton.widthAnchor constraintEqualToConstant:50],
    [self.galleryButton.heightAnchor constraintEqualToConstant:50],

    [self.captureButton.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.captureButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-20],
    [self.captureButton.widthAnchor constraintEqualToConstant:70],
    [self.captureButton.heightAnchor constraintEqualToConstant:70],

  ]];

  // 专业控制区
  [NSLayoutConstraint activateConstraints:@[
    [self.professionalControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.professionalControlsView.centerYAnchor
        constraintEqualToAnchor:self.centerYAnchor],
    [self.professionalControlsView.widthAnchor constraintEqualToConstant:50],
    [self.professionalControlsView.heightAnchor constraintEqualToConstant:200]
  ]];

  [NSLayoutConstraint activateConstraints:@[
    [self.exposureSlider.centerXAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerXAnchor],
    [self.exposureSlider.centerYAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerYAnchor],
    [self.exposureSlider.widthAnchor constraintEqualToConstant:150]
  ]];

  // 状态指示器
  [NSLayoutConstraint activateConstraints:@[
    [self.resolutionModeLabel.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor
                       constant:10],
    [self.resolutionModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:20],
    [self.resolutionModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.resolutionModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.flashModeLabel.topAnchor
        constraintEqualToAnchor:self.resolutionModeLabel.bottomAnchor
                       constant:5],
    [self.flashModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:20],
    [self.flashModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.flashModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.frameWatermarkIndicator.topAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.topAnchor
                       constant:5],
    [self.frameWatermarkIndicator.trailingAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.trailingAnchor
                       constant:-5],
    [self.frameWatermarkIndicator.widthAnchor constraintEqualToConstant:6],
    [self.frameWatermarkIndicator.heightAnchor constraintEqualToConstant:6]
  ]];

  // 网格线约束
  [NSLayoutConstraint activateConstraints:@[
    [self.gridLinesView.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor],
    [self.gridLinesView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.gridLinesView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.gridLinesView.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.topAnchor]
  ]];
}

#pragma mark - 辅助方法

- (UIButton *)createControlButtonWithImageName:(NSString *)imageName
                                        action:(SEL)action {
  UIButton *button = [[UIButton alloc] init];
  UIImage *image = [UIImage systemImageNamed:imageName];
  [button setImage:image forState:UIControlStateNormal];
  button.tintColor = [UIColor whiteColor];
  [button addTarget:self
                action:action
      forControlEvents:UIControlEventTouchUpInside];
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
  if (self.watermarkPanelVisible) {
    [self dismissWatermarkPanel];
  } else {
    [self presentWatermarkPanel];
  }
  if ([self.delegate
          respondsToSelector:@selector(didTapFrameWatermarkButton)]) {
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
  [UIView animateWithDuration:0.1
      animations:^{
        sender.transform = CGAffineTransformMakeScale(0.9, 0.9);
      }
      completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1
                         animations:^{
                           sender.transform = CGAffineTransformIdentity;
                         }];
      }];

  if ([self.delegate respondsToSelector:@selector(didTapCaptureButton)]) {
    [self.delegate didTapCaptureButton];
  }
}

- (void)handleWatermarkBackdropTap {
  [self dismissWatermarkPanel];
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

- (void)resolutionModeLabelTapped:(UITapGestureRecognizer *)gesture {
  if (gesture.state != UIGestureRecognizerStateEnded) {
    return;
  }

  if ([self.delegate respondsToSelector:@selector(didTapResolutionMode)]) {
    [self.delegate didTapResolutionMode];
  }
}

- (void)aspectRatioButtonTapped:(UIButton *)sender {
  // 显示/隐藏弹层
  BOOL isCurrentlyVisible = !self.aspectRatioPopover.hidden;

  if (isCurrentlyVisible) {
    [self hideAspectRatioPopover];
  } else {
    [self showAspectRatioPopover];
  }
}

- (void)aspectRatioOptionTapped:(UIButton *)sender {
  CameraAspectRatio selectedRatio = (CameraAspectRatio)sender.tag;

  // 隐藏弹层
  [self hideAspectRatioPopover];

  // 转发事件
  if ([self.delegate respondsToSelector:@selector(didSelectAspectRatio:)]) {
    [self.delegate didSelectAspectRatio:selectedRatio];
  }
}

- (void)showAspectRatioPopover {
  self.aspectRatioPopover.hidden = NO;
  self.aspectRatioPopover.alpha = 0.0;
  self.aspectRatioPopover.transform = CGAffineTransformMakeScale(0.8, 0.8);

  [UIView animateWithDuration:0.2
                        delay:0
       usingSpringWithDamping:0.8
        initialSpringVelocity:0.5
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     self.aspectRatioPopover.alpha = 1.0;
                     self.aspectRatioPopover.transform =
                         CGAffineTransformIdentity;
                   }
                   completion:nil];
}

- (void)hideAspectRatioPopover {
  [UIView animateWithDuration:0.15
      animations:^{
        self.aspectRatioPopover.alpha = 0.0;
        self.aspectRatioPopover.transform =
            CGAffineTransformMakeScale(0.9, 0.9);
      }
      completion:^(BOOL finished) {
        self.aspectRatioPopover.hidden = YES;
        self.aspectRatioPopover.transform = CGAffineTransformIdentity;
      }];
}

- (void)exposureSliderChanged:(UISlider *)sender {
  if ([self.delegate respondsToSelector:@selector(didChangeExposure:)]) {
    [self.delegate didChangeExposure:sender.value];
  }
}

- (void)previewTapped:(UITapGestureRecognizer *)gesture {
  // 如果弹层显示，先关闭弹层
  if (!self.aspectRatioPopover.hidden) {
    [self hideAspectRatioPopover];
    return;
  }

  // 否则执行对焦
  CGPoint location = [gesture locationInView:self.previewContainer];
  CGRect videoRect = CGRectIsEmpty(self.previewVideoRect)
                         ? self.previewContainer.bounds
                         : self.previewVideoRect;
  if (!CGRectContainsPoint(videoRect, location)) {
    return;
  }
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

- (void)updateResolutionMode:(NSString *)modeText
                 highlighted:(BOOL)highlighted {
  self.resolutionModeLabel.text = modeText;
  self.resolutionModeLabel.backgroundColor =
      highlighted ? [UIColor systemYellowColor]
                  : [UIColor colorWithWhite:0.0 alpha:0.5];
}

- (void)setResolutionModeEnabled:(BOOL)enabled {
  self.resolutionModeLabel.userInteractionEnabled = enabled;
  self.resolutionModeLabel.alpha = enabled ? 1.0 : 0.4;
  self.resolutionModeLabel.accessibilityTraits =
      enabled ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
}

- (void)updateFlashMode:(NSString *)modeText highlighted:(BOOL)highlighted {
  self.flashModeLabel.text = modeText;
  self.flashModeLabel.backgroundColor =
      highlighted ? [UIColor systemYellowColor]
                  : [UIColor colorWithWhite:0.0 alpha:0.5];
}

- (void)updateFrameWatermarkStatus:(BOOL)enabled {
  self.frameWatermarkIndicator.hidden = !enabled;
  self.frameWatermarkButton.tintColor =
      enabled ? [UIColor systemOrangeColor] : [UIColor whiteColor];
}

- (void)applyWatermarkConfiguration:(CMWatermarkConfiguration *)configuration {
  if (!configuration) {
    return;
  }
  self.watermarkConfiguration = [configuration copy];
  [self updateFrameWatermarkStatus:configuration.isEnabled];
  if (self.watermarkPanelVisible) {
    [self.watermarkPanel applyConfiguration:self.watermarkConfiguration
                                   animated:YES];
  } else {
    [self.watermarkPanel applyConfiguration:self.watermarkConfiguration
                                   animated:NO];
  }
}

- (void)presentWatermarkPanel {
  if (self.watermarkPanelVisible) {
    return;
  }
  [self updateWatermarkPanelHeightConstraints];
  [self layoutIfNeeded];

  self.watermarkPanelVisible = YES;
  self.watermarkBackdropView.hidden = NO;
  self.watermarkBackdropView.alpha = 0.0;
  self.watermarkPanel.hidden = NO;
  [self bringSubviewToFront:self.watermarkBackdropView];
  [self bringSubviewToFront:self.watermarkPanel];
  [self.watermarkPanel applyConfiguration:self.watermarkConfiguration
                                 animated:NO];
  [self updateWatermarkPanelHeightConstraints];
  [UIView animateWithDuration:0.3
                        delay:0
       usingSpringWithDamping:0.85
        initialSpringVelocity:0.4
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     self.watermarkBackdropView.alpha = 1.0;
                     [self layoutIfNeeded];
                   }
                   completion:nil];
  if ([self.delegate
          respondsToSelector:@selector(didChangeWatermarkPanelVisibility:)]) {
    [self.delegate didChangeWatermarkPanelVisibility:YES];
  }
}

- (void)dismissWatermarkPanel {
  if (!self.watermarkPanelVisible) {
    return;
  }
  [self layoutIfNeeded];
  self.watermarkPanelVisible = NO;
  [self updateWatermarkPanelHeightConstraints];
  [UIView animateWithDuration:0.25
      animations:^{
        self.watermarkBackdropView.alpha = 0.0;
        [self layoutIfNeeded];
      }
      completion:^(BOOL finished) {
        self.watermarkBackdropView.hidden = YES;
        self.watermarkPanel.hidden = YES;
      }];
  if ([self.delegate
          respondsToSelector:@selector(didChangeWatermarkPanelVisibility:)]) {
    [self.delegate didChangeWatermarkPanelVisibility:NO];
  }
}

- (BOOL)isWatermarkPanelVisible {
  return self.watermarkPanelVisible;
}

#pragma mark - WatermarkPanelViewDelegate

- (void)watermarkPanelDidRequestDismiss:(WatermarkPanelView *)panel {
  [self dismissWatermarkPanel];
}

- (void)watermarkPanel:(WatermarkPanelView *)panel
    didUpdateConfiguration:(CMWatermarkConfiguration *)configuration {
  self.watermarkConfiguration = [configuration copy];
  [self updateFrameWatermarkStatus:configuration.isEnabled];
  if ([self.delegate
          respondsToSelector:@selector(didUpdateWatermarkConfiguration:)]) {
    [self.delegate didUpdateWatermarkConfiguration:configuration];
  }
}

- (void)updateGalleryButtonWithImage:(UIImage *)image {
  if (image) {
    // 创建缩略图
    CGSize thumbnailSize = CGSizeMake(50, 50);
    UIGraphicsBeginImageContextWithOptions(thumbnailSize, NO, 0.0);
    [image
        drawInRect:CGRectMake(0, 0, thumbnailSize.width, thumbnailSize.height)];
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    [self.galleryButton setBackgroundImage:thumbnail
                                  forState:UIControlStateNormal];
    self.galleryButton.layer.cornerRadius = 8;
    self.galleryButton.layer.masksToBounds = YES;
    self.galleryButton.layer.borderWidth = 2;
    self.galleryButton.layer.borderColor = [UIColor whiteColor].CGColor;
  }
}

- (void)showGridLines:(BOOL)show {
  [UIView animateWithDuration:0.3
                   animations:^{
                     self.gridLinesView.hidden = !show;
                     self.gridButton.tintColor =
                         show ? [UIColor systemYellowColor]
                              : [UIColor whiteColor];
                   }];
}

- (void)showFocusIndicatorAtPoint:(CGPoint)point {
  self.focusIndicator.center = point;
  self.focusIndicator.hidden = NO;
  self.focusIndicator.transform = CGAffineTransformMakeScale(1.2, 1.2);
  self.focusIndicator.layer.borderColor = [UIColor systemYellowColor].CGColor;

  [UIView animateWithDuration:0.15
      animations:^{
        self.focusIndicator.transform = CGAffineTransformIdentity;
      }
      completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5
            delay:1.0
            options:UIViewAnimationOptionCurveEaseOut
            animations:^{
              self.focusIndicator.alpha = 0.0;
            }
            completion:^(BOOL finished) {
              self.focusIndicator.alpha = 1.0;
              self.focusIndicator.hidden = YES;
              self.focusIndicator.layer.borderColor =
                  [UIColor yellowColor].CGColor;
            }];
      }];
}

- (void)setCaptureButtonEnabled:(BOOL)enabled {
  self.captureButtonDesiredEnabled = enabled;
  BOOL shouldEnable = enabled && !self.captureButtonLoading;
  self.captureButton.enabled = shouldEnable;
  self.captureButton.alpha = shouldEnable ? 1.0f : 0.6f;
}

- (void)setCaptureButtonLoading:(BOOL)isLoading {
  if (_captureButtonLoading == isLoading) {
    return;
  }

  _captureButtonLoading = isLoading;

  if (isLoading) {
    [self.captureLoadingIndicator startAnimating];
    self.captureButton.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.3];
    self.captureButton.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
  } else {
    [self.captureLoadingIndicator stopAnimating];
    self.captureButton.backgroundColor = [UIColor whiteColor];
    self.captureButton.layer.borderColor = [UIColor whiteColor].CGColor;
  }

  [self setCaptureButtonEnabled:self.captureButtonDesiredEnabled];
}

- (void)updatePreviewVideoRect:(CGRect)videoRect {
  CGRect normalizedRect = CGRectIntegral(videoRect);
  if (CGRectEqualToRect(self.previewVideoRect, normalizedRect)) {
    return;
  }

  self.previewVideoRect = normalizedRect;

  if (self.aspectRatioMaskLayer) {
    [self updateAspectRatioMask:self.activeAspectRatio];
  }
}

- (void)updateAspectRatioMask:(CameraAspectRatio)ratio {
  self.activeAspectRatio = ratio;

  CGRect bounds = self.previewContainer.bounds;
  if (CGRectIsEmpty(bounds)) {
    return;
  }

  const CGFloat targetAspect =
      CMAspectRatioValue(ratio, self.currentOrientation);
  const CGFloat screenAspect = bounds.size.width / bounds.size.height;

  // 计算最大化利用屏幕的活动区域
  CGRect activeRect = bounds;

  if (fabs(screenAspect - targetAspect) >= 0.0001f) {
    if (screenAspect > targetAspect) {
      // 屏幕比目标更宽，在左右裁剪（横屏4:3 vs 屏幕16:9）
      const CGFloat targetWidth = bounds.size.height * targetAspect;
      const CGFloat xOffset = (bounds.size.width - targetWidth) / 2.0f;
      activeRect = CGRectMake(xOffset, 0.0f, targetWidth, bounds.size.height);
    } else {
      // 屏幕比目标更窄，在上下裁剪（竖屏3:4 vs 屏幕19.5:9）
      // 这种情况下，充分利用屏幕宽度，在上下裁剪
      const CGFloat targetHeight = bounds.size.width / targetAspect;
      const CGFloat yOffset = (bounds.size.height - targetHeight) / 2.0f;
      activeRect = CGRectMake(0.0f, yOffset, bounds.size.width, targetHeight);
    }
  }

  NSLog(@"🎯 比例遮罩计算 - 屏幕: %.1fx%.1f (%.2f), 目标比例: %.2f, 活动区域: "
        @"%.1fx%.1f",
        bounds.size.width, bounds.size.height, screenAspect, targetAspect,
        activeRect.size.width, activeRect.size.height);

  UIBezierPath *maskPath = [UIBezierPath bezierPathWithRect:bounds];
  UIBezierPath *activePath =
      [UIBezierPath bezierPathWithRect:CGRectIntegral(activeRect)];
  [maskPath appendPath:activePath];
  maskPath.usesEvenOddFillRule = YES;

  [CATransaction begin];
  [CATransaction setAnimationDuration:0.3];
  self.aspectRatioMaskLayer.path = maskPath.CGPath;
  [CATransaction commit];
}

- (void)updateAspectRatioSelection:(CameraAspectRatio)ratio {
  self.activeAspectRatio = ratio;
  // 更新顶部按钮显示 - 根据方向动态调整文本
  NSString *ratioText = [self ratioTextForRatio:ratio
                                    orientation:self.currentOrientation];
  [self.aspectRatioButton setTitle:ratioText forState:UIControlStateNormal];

  // 更新弹层中的选中状态
  for (UIView *subview in self.aspectRatioPopover.subviews) {
    if ([subview isKindOfClass:[UIButton class]]) {
      UIButton *optionButton = (UIButton *)subview;

      // 查找checkmark
      for (UIView *child in optionButton.subviews) {
        if ([child isKindOfClass:[UIImageView class]] && child.tag >= 1000) {
          child.hidden = (optionButton.tag != ratio);
        }
      }
    }
  }
}

- (NSString *)ratioTextForRatio:(CameraAspectRatio)ratio
                    orientation:(CameraDeviceOrientation)orientation {
  BOOL isPortrait = (orientation == CameraDeviceOrientationPortrait);

  switch (ratio) {
  case CameraAspectRatio4to3:
    return isPortrait ? @"3:4" : @"4:3";
  case CameraAspectRatio1to1:
    return @"1:1"; // 正方形在任何方向都是1:1
  case CameraAspectRatioXpan:
    return isPortrait ? @"24:65" : @"Xpan"; // 竖屏显示具体比例，横屏显示名称
  }
  return @"4:3";
}

- (void)updateLensOptions:(NSArray<CMCameraLensOption *> *)lensOptions
              currentLens:(CMCameraLensOption *_Nullable)currentLens {
  self.lensOptions = [lensOptions copy];
  self.currentLensIdentifier =
      currentLens.identifier ?: lensOptions.firstObject.identifier;

  for (UIView *subview in self.lensStackView.arrangedSubviews) {
    [self.lensStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  if (lensOptions.count <= 1) {
    self.lensButtons = @[];
    self.lensSelectorContainer.hidden = YES;
    return;
  }

  NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
  [lensOptions
      enumerateObjectsUsingBlock:^(CMCameraLensOption *_Nonnull obj,
                                   NSUInteger idx, BOOL *_Nonnull stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:obj.displayName forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:16
                                                   weight:UIFontWeightSemibold];
        button.tag = (NSInteger)idx;
        [button addTarget:self
                      action:@selector(lensButtonTapped:)
            forControlEvents:UIControlEventTouchUpInside];
        button.layer.cornerRadius = 15;
        button.clipsToBounds = YES;
        [button.widthAnchor constraintEqualToConstant:56.0].active = YES;
        [button.heightAnchor constraintEqualToConstant:30].active = YES;
        [self.lensStackView addArrangedSubview:button];
        [buttons addObject:button];
      }];

  self.lensButtons = [buttons copy];
  self.lensSelectorContainer.hidden = NO;
  [self updateLensButtonsAppearanceAnimated:NO];
}

- (void)updateLensButtonsAppearanceAnimated:(BOOL)animated {
  if (self.currentLensIdentifier.length == 0 && self.lensOptions.count > 0) {
    self.currentLensIdentifier = self.lensOptions.firstObject.identifier;
  }
  [self.lensButtons enumerateObjectsUsingBlock:^(UIButton *_Nonnull button,
                                                 NSUInteger idx,
                                                 BOOL *_Nonnull stop) {
    if (idx >= self.lensOptions.count) {
      return;
    }
    CMCameraLensOption *option = self.lensOptions[idx];
    BOOL selected =
        [option.identifier isEqualToString:self.currentLensIdentifier];
    UIColor *selectedBackground =
        [[UIColor colorWithWhite:1.0 alpha:1.0] colorWithAlphaComponent:0.18];
    UIColor *normalBackground = [UIColor clearColor];
    UIColor *selectedTextColor = [UIColor systemOrangeColor];
    UIColor *normalTextColor =
        [[UIColor whiteColor] colorWithAlphaComponent:0.9];

    void (^applyAppearance)(void) = ^{
      button.backgroundColor = selected ? selectedBackground : normalBackground;
      [button setTitleColor:selected ? selectedTextColor : normalTextColor
                   forState:UIControlStateNormal];
      button.transform = selected ? CGAffineTransformMakeScale(1.1, 1.1)
                                  : CGAffineTransformIdentity;
    };

    if (animated) {
      [UIView animateWithDuration:0.2 animations:applyAppearance];
    } else {
      applyAppearance();
    }
  }];
}

- (void)lensButtonTapped:(UIButton *)sender {
  NSInteger index = sender.tag;
  if (index < 0 || index >= (NSInteger)self.lensOptions.count) {
    return;
  }
  CMCameraLensOption *selectedOption = self.lensOptions[index];
  self.currentLensIdentifier = selectedOption.identifier;
  [self updateLensButtonsAppearanceAnimated:YES];
  if ([self.delegate respondsToSelector:@selector(didSelectLensOption:)]) {
    [self.delegate didSelectLensOption:selectedOption];
  }
}

#pragma mark - 横屏适配

- (void)updateLayoutForOrientation:(CameraDeviceOrientation)orientation {
  if (orientation == self.currentOrientation) {
    return; // 方向未变化，无需更新
  }

  self.currentOrientation = orientation;

  // 隐藏弹层（如果显示）
  if (!self.aspectRatioPopover.hidden) {
    [self hideAspectRatioPopover];
  }

  // 执行布局切换动画
  [UIView animateWithDuration:0.3
      delay:0
      usingSpringWithDamping:0.8
      initialSpringVelocity:0.3
      options:UIViewAnimationOptionCurveEaseInOut
      animations:^{
        [self switchConstraintsForOrientation:orientation];
        [self updateWatermarkPanelHeightConstraints];
        [self layoutIfNeeded];
      }
      completion:^(BOOL finished) {
        // 更新比例弹层约束
        [self updateAspectRatioPopoverConstraintsForOrientation:orientation];
        [self updateWatermarkPanelHeightConstraints];

        // 重新计算比例遮罩，因为比例值可能已根据新方向改变
        if (self.aspectRatioMaskLayer) {
          [self updateAspectRatioMask:self.activeAspectRatio];
        }

        // 更新比例按钮文本显示
        NSString *ratioText = [self ratioTextForRatio:self.activeAspectRatio
                                          orientation:orientation];
        [self.aspectRatioButton setTitle:ratioText
                                forState:UIControlStateNormal];

        NSLog(@"UI布局切换完成: %ld", (long)orientation);
      }];
}

- (void)switchConstraintsForOrientation:(CameraDeviceOrientation)orientation {
  // 清理之前的约束
  if (self.portraitConstraints) {
    [NSLayoutConstraint deactivateConstraints:self.portraitConstraints];
    self.portraitConstraints = nil;
  }
  if (self.landscapeConstraints) {
    [NSLayoutConstraint deactivateConstraints:self.landscapeConstraints];
    self.landscapeConstraints = nil;
  }

  if (orientation == CameraDeviceOrientationPortrait) {
    [self setupPortraitLayout];
  } else {
    [self setupLandscapeLayout];
  }
}

- (void)setupPortraitLayout {
  // 重新设置竖屏布局（使用原有的约束逻辑）
  UILayoutGuide *safeArea = self.safeAreaLayoutGuide;

  NSMutableArray *constraints = [NSMutableArray array];

  // 预览容器 - 全屏
  [constraints addObjectsFromArray:@[
    [self.previewContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.previewContainer.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.previewContainer.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.previewContainer.bottomAnchor
        constraintEqualToAnchor:self.bottomAnchor]
  ]];

  // 顶部控制栏
  [constraints addObjectsFromArray:@[
    [self.topControlsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [self.topControlsView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.topControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.topControlsView.heightAnchor constraintEqualToConstant:60]
  ]];

  // 顶部按钮水平排列
  [constraints addObjectsFromArray:@[
    [self.flashButton.leadingAnchor
        constraintEqualToAnchor:self.topControlsView.leadingAnchor
                       constant:20],
    [self.flashButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.flashButton.widthAnchor constraintEqualToConstant:40],
    [self.flashButton.heightAnchor constraintEqualToConstant:40],

    [self.gridButton.leadingAnchor
        constraintEqualToAnchor:self.flashButton.trailingAnchor
                       constant:10],
    [self.gridButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.gridButton.widthAnchor constraintEqualToConstant:40],
    [self.gridButton.heightAnchor constraintEqualToConstant:40],

    [self.aspectRatioButton.leadingAnchor
        constraintEqualToAnchor:self.gridButton.trailingAnchor
                       constant:10],
    [self.aspectRatioButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.aspectRatioButton.widthAnchor constraintEqualToConstant:45],
    [self.aspectRatioButton.heightAnchor constraintEqualToConstant:30],

    // 右侧按钮（从右往左排列）
    [self.settingsButton.trailingAnchor
        constraintEqualToAnchor:self.topControlsView.trailingAnchor
                       constant:-20],
    [self.settingsButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.settingsButton.widthAnchor constraintEqualToConstant:40],
    [self.settingsButton.heightAnchor constraintEqualToConstant:40],

    [self.switchCameraButton.trailingAnchor
        constraintEqualToAnchor:self.settingsButton.leadingAnchor
                       constant:-10],
    [self.switchCameraButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.switchCameraButton.widthAnchor constraintEqualToConstant:40],
    [self.switchCameraButton.heightAnchor constraintEqualToConstant:40],

    [self.frameWatermarkButton.trailingAnchor
        constraintEqualToAnchor:self.switchCameraButton.leadingAnchor
                       constant:-10],
    [self.frameWatermarkButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.frameWatermarkButton.widthAnchor constraintEqualToConstant:40],
    [self.frameWatermarkButton.heightAnchor constraintEqualToConstant:40]
  ]];

  // 底部控制栏
  [constraints addObjectsFromArray:@[
    [self.bottomControlsView.bottomAnchor
        constraintEqualToAnchor:safeArea.bottomAnchor],
    [self.bottomControlsView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.bottomControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.bottomControlsView.heightAnchor constraintEqualToConstant:120]
  ]];

  // 底部控制元素约束（竖屏时也需要）
  [constraints addObjectsFromArray:@[
    // 模式选择器
    [self.modeSelector.bottomAnchor
        constraintEqualToAnchor:self.captureButton.topAnchor
                       constant:-20],
    [self.modeSelector.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.modeSelector.widthAnchor
        constraintEqualToConstant:CMModeSelectorWidth],
    [self.modeSelector.heightAnchor constraintEqualToConstant:30],

    // 相册按钮
    [self.galleryButton.leadingAnchor
        constraintEqualToAnchor:self.bottomControlsView.leadingAnchor
                       constant:30],
    [self.galleryButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-20],
    [self.galleryButton.widthAnchor constraintEqualToConstant:50],
    [self.galleryButton.heightAnchor constraintEqualToConstant:50],

    // 拍摄按钮（居中）
    [self.captureButton.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.captureButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-20],
    [self.captureButton.widthAnchor constraintEqualToConstant:70],
    [self.captureButton.heightAnchor constraintEqualToConstant:70],

    // 专业控制区域
    [self.professionalControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.professionalControlsView.centerYAnchor
        constraintEqualToAnchor:self.centerYAnchor],
    [self.professionalControlsView.widthAnchor constraintEqualToConstant:50],
    [self.professionalControlsView.heightAnchor constraintEqualToConstant:200],

    [self.exposureSlider.centerXAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerXAnchor],
    [self.exposureSlider.centerYAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerYAnchor],
    [self.exposureSlider.widthAnchor constraintEqualToConstant:150],

    // 状态指示器
    [self.resolutionModeLabel.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor
                       constant:10],
    [self.resolutionModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:20],
    [self.resolutionModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.resolutionModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.flashModeLabel.topAnchor
        constraintEqualToAnchor:self.resolutionModeLabel.bottomAnchor
                       constant:5],
    [self.flashModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:20],
    [self.flashModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.flashModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.frameWatermarkIndicator.topAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.topAnchor
                       constant:5],
    [self.frameWatermarkIndicator.trailingAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.trailingAnchor
                       constant:-5],
    [self.frameWatermarkIndicator.widthAnchor constraintEqualToConstant:6],
    [self.frameWatermarkIndicator.heightAnchor constraintEqualToConstant:6],

    // 网格线约束
    [self.gridLinesView.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor],
    [self.gridLinesView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.gridLinesView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.gridLinesView.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.topAnchor]
  ]];

  // 镜头选择器
  [constraints addObjectsFromArray:@[
    [self.lensSelectorContainer.centerXAnchor
        constraintEqualToAnchor:self.centerXAnchor],
    [self.lensSelectorContainer.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.topAnchor
                       constant:-16.0],
    [self.lensSelectorContainer.heightAnchor
        constraintGreaterThanOrEqualToConstant:56.0]
  ]];

  self.portraitConstraints = [constraints copy];
  [NSLayoutConstraint activateConstraints:self.portraitConstraints];
}

- (void)setupLandscapeLayout {
  // 横屏布局：保持顶部和底部横向排列，不改为纵向
  UILayoutGuide *safeArea = self.safeAreaLayoutGuide;

  NSMutableArray *constraints = [NSMutableArray array];

  // 预览容器 - 全屏（和竖屏一样）
  [constraints addObjectsFromArray:@[
    [self.previewContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.previewContainer.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.previewContainer.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.previewContainer.bottomAnchor
        constraintEqualToAnchor:self.bottomAnchor]
  ]];

  // 顶部控制栏 - 保持横向排列
  [constraints addObjectsFromArray:@[
    [self.topControlsView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [self.topControlsView.leadingAnchor
        constraintEqualToAnchor:safeArea.leadingAnchor],
    [self.topControlsView.trailingAnchor
        constraintEqualToAnchor:safeArea.trailingAnchor],
    [self.topControlsView.heightAnchor constraintEqualToConstant:60]
  ]];

  // 顶部按钮横向排列（横屏时适当调整间距）
  [constraints addObjectsFromArray:@[
    [self.flashButton.leadingAnchor
        constraintEqualToAnchor:self.topControlsView.leadingAnchor
                       constant:20],
    [self.flashButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.flashButton.widthAnchor constraintEqualToConstant:40],
    [self.flashButton.heightAnchor constraintEqualToConstant:40],

    [self.gridButton.leadingAnchor
        constraintEqualToAnchor:self.flashButton.trailingAnchor
                       constant:20],
    [self.gridButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.gridButton.widthAnchor constraintEqualToConstant:40],
    [self.gridButton.heightAnchor constraintEqualToConstant:40],

    [self.aspectRatioButton.leadingAnchor
        constraintEqualToAnchor:self.gridButton.trailingAnchor
                       constant:20],
    [self.aspectRatioButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.aspectRatioButton.widthAnchor constraintEqualToConstant:45],
    [self.aspectRatioButton.heightAnchor constraintEqualToConstant:30],

    // 右侧按钮
    [self.settingsButton.trailingAnchor
        constraintEqualToAnchor:self.topControlsView.trailingAnchor
                       constant:-20],
    [self.settingsButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.settingsButton.widthAnchor constraintEqualToConstant:40],
    [self.settingsButton.heightAnchor constraintEqualToConstant:40],

    [self.switchCameraButton.trailingAnchor
        constraintEqualToAnchor:self.settingsButton.leadingAnchor
                       constant:-20],
    [self.switchCameraButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.switchCameraButton.widthAnchor constraintEqualToConstant:40],
    [self.switchCameraButton.heightAnchor constraintEqualToConstant:40],

    [self.frameWatermarkButton.trailingAnchor
        constraintEqualToAnchor:self.switchCameraButton.leadingAnchor
                       constant:-20],
    [self.frameWatermarkButton.centerYAnchor
        constraintEqualToAnchor:self.topControlsView.centerYAnchor],
    [self.frameWatermarkButton.widthAnchor constraintEqualToConstant:40],
    [self.frameWatermarkButton.heightAnchor constraintEqualToConstant:40]
  ]];

  // 底部控制栏 - 保持横向排列
  [constraints addObjectsFromArray:@[
    [self.bottomControlsView.bottomAnchor
        constraintEqualToAnchor:safeArea.bottomAnchor],
    [self.bottomControlsView.leadingAnchor
        constraintEqualToAnchor:safeArea.leadingAnchor],
    [self.bottomControlsView.trailingAnchor
        constraintEqualToAnchor:safeArea.trailingAnchor],
    [self.bottomControlsView.heightAnchor
        constraintEqualToConstant:100] // 横屏时稍微缩小
  ]];

  // 底部控制元素约束（和竖屏保持一致）
  [constraints addObjectsFromArray:@[
    // 模式选择器
    [self.modeSelector.bottomAnchor
        constraintEqualToAnchor:self.captureButton.topAnchor
                       constant:-15],
    [self.modeSelector.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.modeSelector.widthAnchor
        constraintEqualToConstant:CMModeSelectorWidth],
    [self.modeSelector.heightAnchor constraintEqualToConstant:30],

    // 相册按钮
    [self.galleryButton.leadingAnchor
        constraintEqualToAnchor:self.bottomControlsView.leadingAnchor
                       constant:30],
    [self.galleryButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-15],
    [self.galleryButton.widthAnchor constraintEqualToConstant:50],
    [self.galleryButton.heightAnchor constraintEqualToConstant:50],

    // 拍摄按钮（居中）
    [self.captureButton.centerXAnchor
        constraintEqualToAnchor:self.bottomControlsView.centerXAnchor],
    [self.captureButton.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.bottomAnchor
                       constant:-15],
    [self.captureButton.widthAnchor constraintEqualToConstant:70],
    [self.captureButton.heightAnchor constraintEqualToConstant:70],

  ]];

  // 专业控制区域（横屏时保持右侧）
  [constraints addObjectsFromArray:@[
    [self.professionalControlsView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.professionalControlsView.centerYAnchor
        constraintEqualToAnchor:self.centerYAnchor],
    [self.professionalControlsView.widthAnchor constraintEqualToConstant:50],
    [self.professionalControlsView.heightAnchor constraintEqualToConstant:200]
  ]];

  [constraints addObjectsFromArray:@[
    [self.exposureSlider.centerXAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerXAnchor],
    [self.exposureSlider.centerYAnchor
        constraintEqualToAnchor:self.professionalControlsView.centerYAnchor],
    [self.exposureSlider.widthAnchor constraintEqualToConstant:150]
  ]];

  // 状态指示器与网格线
  [constraints addObjectsFromArray:@[
    [self.resolutionModeLabel.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor
                       constant:12],
    [self.resolutionModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:32],
    [self.resolutionModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.resolutionModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.flashModeLabel.topAnchor
        constraintEqualToAnchor:self.resolutionModeLabel.bottomAnchor
                       constant:6],
    [self.flashModeLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:32],
    [self.flashModeLabel.widthAnchor constraintEqualToConstant:50],
    [self.flashModeLabel.heightAnchor constraintEqualToConstant:20],

    [self.frameWatermarkIndicator.topAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.topAnchor
                       constant:5],
    [self.frameWatermarkIndicator.trailingAnchor
        constraintEqualToAnchor:self.frameWatermarkButton.trailingAnchor
                       constant:-5],
    [self.frameWatermarkIndicator.widthAnchor constraintEqualToConstant:6],
    [self.frameWatermarkIndicator.heightAnchor constraintEqualToConstant:6],

    [self.gridLinesView.topAnchor
        constraintEqualToAnchor:self.topControlsView.bottomAnchor],
    [self.gridLinesView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.gridLinesView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.gridLinesView.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.topAnchor]
  ]];

  // 镜头选择器（横屏）
  [constraints addObjectsFromArray:@[
    [self.lensSelectorContainer.centerXAnchor
        constraintEqualToAnchor:self.centerXAnchor],
    [self.lensSelectorContainer.bottomAnchor
        constraintEqualToAnchor:self.bottomControlsView.topAnchor
                       constant:-12.0],
    [self.lensSelectorContainer.heightAnchor
        constraintGreaterThanOrEqualToConstant:56.0]
  ]];

  self.landscapeConstraints = [constraints copy];
  [NSLayoutConstraint activateConstraints:self.landscapeConstraints];
}

- (void)updateAspectRatioPopoverConstraintsForOrientation:
    (CameraDeviceOrientation)orientation {
  // 移除现有约束
  [self.aspectRatioPopover removeFromSuperview];
  [self addSubview:self.aspectRatioPopover];
  self.aspectRatioPopover.translatesAutoresizingMaskIntoConstraints = NO;

  if (orientation == CameraDeviceOrientationPortrait) {
    // 竖屏时向下弹出
    [NSLayoutConstraint activateConstraints:@[
      [self.aspectRatioPopover.topAnchor
          constraintEqualToAnchor:self.aspectRatioButton.bottomAnchor
                         constant:10],
      [self.aspectRatioPopover.centerXAnchor
          constraintEqualToAnchor:self.aspectRatioButton.centerXAnchor],
      [self.aspectRatioPopover.widthAnchor constraintEqualToConstant:140],
      [self.aspectRatioPopover.heightAnchor constraintEqualToConstant:150]
    ]];
  } else {
    // 横屏时向左弹出
    [NSLayoutConstraint activateConstraints:@[
      [self.aspectRatioPopover.trailingAnchor
          constraintEqualToAnchor:self.aspectRatioButton.leadingAnchor
                         constant:-10],
      [self.aspectRatioPopover.centerYAnchor
          constraintEqualToAnchor:self.aspectRatioButton.centerYAnchor],
      [self.aspectRatioPopover.widthAnchor constraintEqualToConstant:140],
      [self.aspectRatioPopover.heightAnchor constraintEqualToConstant:150]
    ]];
  }
}

#pragma mark - 布局更新

- (void)layoutSubviews {
  [super layoutSubviews];

  // 重新创建网格线以适应屏幕尺寸
  if (self.gridLinesView.subviews.count == 0) {
    [self createGridLinesWithFrame];
  }

  // 更新比例遮罩尺寸
  if (self.aspectRatioMaskLayer &&
      !CGRectIsEmpty(self.previewContainer.bounds)) {
    [self updateAspectRatioMask:self.activeAspectRatio];
  }

  [self updateWatermarkPanelHeightConstraints];
}

- (void)createGridLinesWithFrame {
  [self.gridLinesView.subviews
      makeObjectsPerformSelector:@selector(removeFromSuperview)];

  CGRect gridFrame = self.gridLinesView.bounds;
  if (CGRectIsEmpty(gridFrame))
    return;

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
