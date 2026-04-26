//
//  CameraViewController_New.m
//  CameraM
//
//  Created by 马聪聪 on 2025/9/18.
//

#import "CameraViewController.h"
#import "Controllers/CameraBusinessController.h"
#import "Models/CMCameraLensOption.h"
#import "Views/CameraControlsView.h"
#import "Views/WatermarkPanelView.h"
#import "Controllers/GalleryViewController.h"
#import "Controllers/GalleryPreviewViewController.h"
#import "ViewModels/CameraViewModel.h"
#import "Common/CMPermissionManager.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

typedef NS_ENUM(NSInteger, CMWatermarkInteractionState) {
  CMWatermarkInteractionStateNone = 0,
  CMWatermarkInteractionStateQuickPanel = 1,
  CMWatermarkInteractionStateDetailCard = 2
};

@interface CameraViewController () <
    CameraControlsDelegate, CameraBusinessDelegate,
    PHPickerViewControllerDelegate, WatermarkPanelViewDelegate,
    GalleryViewControllerDelegate, GalleryPreviewViewControllerDelegate>

// 分离的组件 - 高内聚低耦合
@property(nonatomic, strong) CameraControlsView *controlsView;
@property(nonatomic, strong) CameraBusinessController *businessController;
@property(nonatomic, strong) CameraViewModel *viewModel;
@property(nonatomic, strong) UIView *processingOverlay;
@property(nonatomic, strong) UIActivityIndicatorView *processingIndicator;
@property(nonatomic, assign) BOOL isProcessingImportedImage;
@property(nonatomic, strong) UIView *importCustomizationOverlay;
@property(nonatomic, strong) UIView *importCustomizationContainer;
@property(nonatomic, strong) WatermarkPanelView *importWatermarkPanel;
@property(nonatomic, strong) UIImage *pendingImportedImage;
@property(nonatomic, strong)
    CMWatermarkConfiguration *pendingImportConfiguration;
@property(nonatomic, strong) NSDictionary *pendingImportMetadata;
@property(nonatomic, assign) BOOL hasCapturedPhotoInSession;
// 控制下次点击相册按钮时是否优先展示最新拍摄的快速预览
@property(nonatomic, assign) BOOL shouldShowCapturePreview;
@property(nonatomic, strong) NSDictionary *latestCaptureMetadata;
@property(nonatomic, assign)
    CMWatermarkInteractionState watermarkInteractionState;

@end

@implementation CameraViewController

#pragma mark - 生命周期

- (void)viewDidLoad {
  [super viewDidLoad];
  self.watermarkInteractionState = CMWatermarkInteractionStateNone;
  [self setupComponents];
  [self setupCamera];
  self.hasCapturedPhotoInSession =
      (self.businessController.latestCapturedImage != nil);
  self.shouldShowCapturePreview = self.hasCapturedPhotoInSession;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self.businessController startSession];
  [self applyWatermarkOrientationPolicyForCurrentState];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  [self.businessController stopSession];
  self.watermarkInteractionState = CMWatermarkInteractionStateNone;
  [self applyWatermarkOrientationPolicyForCurrentState];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updatePreviewLayerFrame];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:
           (id<UIViewControllerTransitionCoordinator>)coordinator {
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

  [coordinator
      animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>
                                       _Nonnull context) {
        [self.view layoutIfNeeded];
        [self updatePreviewLayerFrame];
      }
                      completion:^(
                          id<UIViewControllerTransitionCoordinatorContext>
                              _Nonnull context) {
                        [self.view layoutIfNeeded];
                        [self updatePreviewLayerFrame];
                      }];
}

- (void)dealloc {
  [self.businessController stopOrientationMonitoring]; // 停止方向监听
  [self.businessController cleanup];
}

#pragma mark - 组件设置 (协调者职责)

- (void)setupComponents {
  // 创建UI组件
  self.controlsView =
      [[CameraControlsView alloc] initWithFrame:self.view.bounds];
  self.controlsView.delegate = self;
  self.controlsView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.controlsView];

  // 创建业务控制器
  self.businessController = [[CameraBusinessController alloc] init];
  self.businessController.delegate = self;
  self.viewModel =
      [[CameraViewModel alloc] initWithBusinessController:self.businessController];

  [self.controlsView applyWatermarkConfiguration:self.businessController
                                                     .watermarkConfiguration];
  if (self.businessController.availableLensOptions.count > 0) {
    [self.controlsView
        updateLensOptions:self.businessController.availableLensOptions
              currentLens:self.businessController.currentLensOption];
  }

  // UI组件约束
  [NSLayoutConstraint activateConstraints:@[
    [self.controlsView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.controlsView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.controlsView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.controlsView.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor]
  ]];

  [self.controlsView
      showGridLines:[self.businessController isGridLinesVisible]];
}

- (void)setupCamera {
  [self.businessController
      setupCameraWithPreviewView:self.controlsView.previewContainer
                       completion:^(BOOL success, NSError *_Nullable error) {
                    if (success) {
                      NSLog(@"相机设置成功");
                      [self updateUIState];
                      [self updatePreviewLayerFrame];

                      // 启动方向监听
                      [self.businessController startOrientationMonitoring];
                    } else {
                      NSLog(@"相机设置失败: %@", error.localizedDescription);
                      [self showErrorAlert:error.localizedDescription];
                    }
                  }];
}

- (void)updateUIState {
  CMCameraControlDisplayState *state =
      [self.viewModel currentControlDisplayState];
  [self.controlsView updateResolutionMode:state.resolutionText
                               highlighted:state.resolutionHighlighted];
  [self.controlsView
      setResolutionModeEnabled:self.businessController
                                   .isUltraHighResolutionSupported];

  [self.controlsView updateFlashMode:state.flashText
                          highlighted:state.flashHighlighted];
}

#pragma mark - CameraControlsDelegate (UI事件转发)

- (void)didTapCaptureButton {
  [self.controlsView setCaptureButtonLoading:YES];
  [self.businessController capturePhoto];
}

- (void)didTapGalleryButton {
  if (self.shouldShowCapturePreview &&
      self.businessController.latestCapturedImage) {
    [self presentPreviewForCapturedImage];
  } else {
    [self presentCustomGallery];
  }
}

- (void)didSelectMode:(NSInteger)modeIndex {
  NSLog(@"模式切换: %ld", (long)modeIndex);
}

- (void)didSelectAspectRatio:(CameraAspectRatio)ratio {
  [self.businessController switchAspectRatio:ratio];
  NSLog(@"比例切换: %ld", (long)ratio);
}

- (void)didTapResolutionMode {
  if (!self.businessController.isUltraHighResolutionSupported) {
    return;
  }
  [self.businessController switchResolutionMode];
}

- (void)didTapFlashButton {
  [self.businessController switchFlashMode];
}

- (void)didTapGridButton {
  [self.businessController toggleGridLines];
  [self.controlsView
      showGridLines:[self.businessController isGridLinesVisible]];
}

- (void)didTapSwitchCameraButton {
  [self.businessController switchCamera];
}

- (void)didTapFrameWatermarkButton {
  NSLog(@"相框水印按钮点击");
}

- (void)didTapSettingsButton {
  NSLog(@"设置按钮点击");
}

- (void)didChangeExposure:(float)value {
  [self.businessController setExposureCompensation:value];
}

- (void)didSelectLensOption:(CMCameraLensOption *)lensOption {
  [self.businessController switchToLensOption:lensOption];
}

- (void)didTapPreviewAtPoint:(CGPoint)point {
  [self.businessController
          focusAtPoint:point
      withPreviewLayer:self.businessController.previewLayer];
  [self.controlsView showFocusIndicatorAtPoint:point];
}

- (void)didDoubleTapPreview {
  if (self.businessController.isUltraHighResolutionSupported) {
    [self.businessController switchResolutionMode];
  }
}

- (void)didUpdateWatermarkConfiguration:
    (CMWatermarkConfiguration *)configuration {
  [self.businessController updateWatermarkConfiguration:configuration];
}

- (void)didChangeWatermarkPanelVisibility:(BOOL)isVisible {
  self.watermarkInteractionState =
      isVisible ? CMWatermarkInteractionStateQuickPanel
                : CMWatermarkInteractionStateNone;
  [self applyWatermarkOrientationPolicyForCurrentState];
  NSLog(@"水印面板%@", isVisible ? @"展开" : @"收起");
}

- (void)didChangeWatermarkDetailVisibility:(BOOL)isVisible {
  if (isVisible) {
    self.watermarkInteractionState = CMWatermarkInteractionStateDetailCard;
  } else if ([self.controlsView isWatermarkPanelVisible]) {
    self.watermarkInteractionState = CMWatermarkInteractionStateQuickPanel;
  } else {
    self.watermarkInteractionState = CMWatermarkInteractionStateNone;
  }
  [self applyWatermarkOrientationPolicyForCurrentState];
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
  if (self.watermarkInteractionState != CMWatermarkInteractionStateNone) {
    [self.controlsView updateLayoutForOrientation:CameraDeviceOrientationPortrait];
    [self updatePreviewLayerFrame];
    return;
  }

  // 更新UI布局适配
  [self.controlsView updateLayoutForOrientation:orientation];

  // 重要：在方向切换时与动画结束后都刷新预览层，避免取景框错位
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.view layoutIfNeeded];
    [self updatePreviewLayerFrame];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          [self.view layoutIfNeeded];
          [self updatePreviewLayerFrame];
        });
  });

  NSLog(@"设备方向变化，UI适配: %ld", (long)orientation);
}

#pragma mark - Orientation Policy

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  if (self.watermarkInteractionState == CMWatermarkInteractionStateNone) {
    return UIInterfaceOrientationMaskAllButUpsideDown;
  }
  return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
  return YES;
}

- (void)applyWatermarkOrientationPolicyForCurrentState {
  if (@available(iOS 16.0, *)) {
    [self setNeedsUpdateOfSupportedInterfaceOrientations];
  }
  [UIViewController attemptRotationToDeviceOrientation];

  if (@available(iOS 16.0, *)) {
    UIWindowScene *scene = self.view.window.windowScene;
    if (!scene) {
      return;
    }
    UIInterfaceOrientationMask mask =
        (self.watermarkInteractionState == CMWatermarkInteractionStateNone)
            ? UIInterfaceOrientationMaskAllButUpsideDown
            : UIInterfaceOrientationMaskPortrait;
    UIWindowSceneGeometryPreferencesIOS *preferences =
        [[UIWindowSceneGeometryPreferencesIOS alloc]
            initWithInterfaceOrientations:mask];
    [scene requestGeometryUpdateWithPreferences:preferences
                                   errorHandler:^(NSError *_Nonnull error) {
                                     NSLog(@"方向策略切换失败: %@",
                                           error.localizedDescription);
                                   }];
  }
}

- (void)didUpdateAvailableLensOptions:
            (NSArray<CMCameraLensOption *> *)lensOptions
                          currentLens:(CMCameraLensOption *)currentLens {
  [self.controlsView updateLensOptions:lensOptions currentLens:currentLens];
  [self updateUIState];
}

// 新增方法：更新预览层frame
- (void)updatePreviewLayerFrame {
  CGRect newFrame = self.controlsView.previewContainer.bounds;

  if (!CGRectIsEmpty(newFrame)) {
    AVCaptureVideoPreviewLayer *previewLayer =
        self.businessController.previewLayer;
    if (!previewLayer) {
      return;
    }

    // 使用CATransaction确保frame和方向同步更新
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    AVCaptureConnection *connection = previewLayer.connection;
    AVCaptureVideoOrientation targetOrientation =
        [self currentPreviewVideoOrientation];
    if (connection && connection.isVideoOrientationSupported &&
        connection.videoOrientation != targetOrientation) {
      connection.videoOrientation = targetOrientation;
    }
    BOOL frameChanged = !CGRectEqualToRect(previewLayer.frame, newFrame);
    if (frameChanged) {
      previewLayer.frame = newFrame;
    }
    [CATransaction commit];

    CGRect videoRect =
        [self.businessController activePreviewRectInViewSize:newFrame.size];
    [self.controlsView updatePreviewVideoRect:videoRect];

    if (frameChanged) {
      NSLog(@"📐 预览层frame已更新: %@", NSStringFromCGRect(newFrame));
    }
  }
}

- (AVCaptureVideoOrientation)currentPreviewVideoOrientation {
  UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationUnknown;
  if (@available(iOS 13.0, *)) {
    interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
  }

  switch (interfaceOrientation) {
  case UIInterfaceOrientationLandscapeLeft:
    return AVCaptureVideoOrientationLandscapeLeft;
  case UIInterfaceOrientationLandscapeRight:
    return AVCaptureVideoOrientationLandscapeRight;
  case UIInterfaceOrientationPortraitUpsideDown:
    return AVCaptureVideoOrientationPortraitUpsideDown;
  case UIInterfaceOrientationPortrait:
    return AVCaptureVideoOrientationPortrait;
  default:
    return self.businessController.previewLayer.connection.videoOrientation;
  }
}

- (void)didCapturePhoto:(UIImage *)image withMetadata:(NSDictionary *)metadata {
  NSLog(@"拍照成功，图片尺寸: %.0fx%.0f", image.size.width, image.size.height);
  self.hasCapturedPhotoInSession = YES;
  self.shouldShowCapturePreview = YES;
  self.latestCaptureMetadata = metadata;
  [self.controlsView setCaptureButtonLoading:NO];
  [self.controlsView updateGalleryButtonWithImage:image];
}

- (void)didFailWithError:(NSError *)error {
  [self.controlsView setCaptureButtonLoading:NO];
  [self showErrorAlert:error.localizedDescription];
}

- (void)shouldUpdateCaptureButtonEnabled:(BOOL)enabled {
  [self.controlsView setCaptureButtonEnabled:enabled];
}

- (void)shouldShowCaptureFlashEffect {
  [self showCaptureFlashEffect];
}

#pragma mark - 视图控制器辅助方法

- (void)showErrorAlert:(NSString *)message {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"错误"
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *okAction =
      [UIAlertAction actionWithTitle:@"确定"
                               style:UIAlertActionStyleDefault
                             handler:nil];
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
  [closeButton setTitleColor:[UIColor whiteColor]
                    forState:UIControlStateNormal];
  closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
  closeButton.layer.cornerRadius = 8;
  [closeButton addTarget:self
                  action:@selector(dismissImagePreview)
        forControlEvents:UIControlEventTouchUpInside];
  closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  [previewVC.view addSubview:closeButton];

  [NSLayoutConstraint activateConstraints:@[
    [imageView.topAnchor
        constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide.topAnchor],
    [imageView.leadingAnchor
        constraintEqualToAnchor:previewVC.view.leadingAnchor],
    [imageView.trailingAnchor
        constraintEqualToAnchor:previewVC.view.trailingAnchor],
    [imageView.bottomAnchor
        constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide
                                    .bottomAnchor],

    [closeButton.topAnchor
        constraintEqualToAnchor:previewVC.view.safeAreaLayoutGuide.topAnchor
                       constant:20],
    [closeButton.trailingAnchor
        constraintEqualToAnchor:previewVC.view.trailingAnchor
                       constant:-20],
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
    [[UIApplication sharedApplication] openURL:photosURL
                                       options:@{}
                             completionHandler:nil];
  }
}

#pragma mark - 自定义相册

- (void)presentPreviewForCapturedImage {
  if (self.isProcessingImportedImage) {
    return;
  }

  UIImage *latestImage = self.businessController.latestCapturedImage;
  if (!latestImage) {
    [self presentCustomGallery];
    return;
  }

  if (self.presentedViewController) {
    return;
  }

  GalleryPreviewViewController *previewVC =
      [[GalleryPreviewViewController alloc]
          initWithImage:latestImage
               metadata:self.latestCaptureMetadata];
  previewVC.delegate = self;
  previewVC.modalPresentationStyle = UIModalPresentationFullScreen;
  [self presentViewController:previewVC animated:YES completion:nil];
}

- (void)presentCustomGallery {
  if (self.isProcessingImportedImage) {
    return;
  }

  if (self.presentedViewController) {
    return;
  }

  // 使用CMPermissionManager简化权限处理
  CMPermissionManager *pm = [CMPermissionManager sharedManager];

  if ([pm isPhotoLibraryAccessGranted]) {
    // 已授权,直接显示相册
    [self showGalleryController];
  } else if ([pm photoLibraryAuthorizationStatus] == CMPermissionStatusNotDetermined) {
    // 未决定,请求权限
    __weak typeof(self) weakSelf = self;
    [pm requestPhotoLibraryPermission:^(CMPermissionStatus status) {
      dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
          return;
        }
        if (status == CMPermissionStatusAuthorized ||
            status == CMPermissionStatusLimited) {
          [strongSelf showGalleryController];
        } else {
          [pm showPermissionDeniedAlertForType:@"相册" fromViewController:strongSelf];
        }
      });
    }];
  } else {
    // 已拒绝或受限,显示设置提示
    [pm showPermissionDeniedAlertForType:@"相册" fromViewController:self];
  }
}

- (void)showGalleryController {
  if ([self.presentedViewController isKindOfClass:[GalleryViewController class]]) {
    return;
  }
  GalleryViewController *galleryVC = [[GalleryViewController alloc] init];
  galleryVC.delegate = self;
  galleryVC.modalPresentationStyle = UIModalPresentationFullScreen;
  [self presentViewController:galleryVC animated:YES completion:nil];
}

// showGalleryAuthorizationAlert 已由 CMPermissionManager 替代

#pragma mark - Photo Picker

- (void)presentPhotoPicker {
  if (@available(iOS 14.0, *)) {
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = [PHPickerFilter imagesFilter];
    configuration.selectionLimit = 1;
    configuration.preferredAssetRepresentationMode =
        PHPickerConfigurationAssetRepresentationModeCurrent;

    PHPickerViewController *picker =
        [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
  } else {
    [self openSystemPhotosApp];
  }
}

- (void)picker:(PHPickerViewController *)picker
    didFinishPicking:(NSArray<PHPickerResult *> *)results
    API_AVAILABLE(ios(14.0)) {
  [picker dismissViewControllerAnimated:YES completion:nil];

  PHPickerResult *result = results.firstObject;
  if (!result) {
    return;
  }

  NSItemProvider *provider = result.itemProvider;
  if (![provider canLoadObjectOfClass:[UIImage class]]) {
    [self showErrorAlert:@"不支持所选的资源类型"];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [provider
      loadObjectOfClass:[UIImage class]
      completionHandler:^(UIImage *_Nullable object, NSError *_Nullable error) {
        if (error || !object) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) {
            return;
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            NSString *message =
                error.localizedDescription ?: @"无法加载选中的图片";
            [strongSelf showErrorAlert:message];
          });
          return;
        }

        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
          return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          [strongSelf handleImportedImage:object];
        });
      }];
}

- (void)handleImportedImage:(UIImage *)image {
  [self handleImportedImage:image metadata:nil];
}

- (void)handleImportedImage:(UIImage *)image
                    metadata:(NSDictionary *_Nullable)metadata {
  if (!image || self.isProcessingImportedImage) {
    return;
  }

  self.isProcessingImportedImage = YES;
  self.pendingImportedImage = image;
  self.pendingImportMetadata = metadata;

  CMWatermarkConfiguration *baseConfiguration =
      [self.businessController.watermarkConfiguration copy];
  if (!baseConfiguration) {
    baseConfiguration = [CMWatermarkConfiguration defaultConfiguration];
  }
  self.pendingImportConfiguration = [baseConfiguration copy];

  [self presentImportCustomizationWithConfiguration:baseConfiguration];
}

- (UIButton *)importActionButtonWithTitle:(NSString *)title
                                  primary:(BOOL)isPrimary {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:16.0
                                             weight:UIFontWeightSemibold];
  button.layer.cornerRadius = 12.0f;
  button.layer.masksToBounds = YES;
  UIColor *background = isPrimary ? [UIColor systemOrangeColor]
                                  : [UIColor colorWithWhite:1.0 alpha:0.12];
  UIColor *titleColor = isPrimary ? [UIColor blackColor] : [UIColor whiteColor];
  button.backgroundColor = background;
  [button setTitleColor:titleColor forState:UIControlStateNormal];
  button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 0.0, 12.0, 0.0);
  return button;
}

- (void)presentImportCustomizationWithConfiguration:
    (CMWatermarkConfiguration *)configuration {
  if (!configuration) {
    configuration = [CMWatermarkConfiguration defaultConfiguration];
  }

  if (self.importCustomizationOverlay.superview) {
    [self.importWatermarkPanel applyConfiguration:configuration animated:NO];
    [self.importWatermarkPanel updatePreviewWithImage:self.pendingImportedImage
                                            metadata:self.pendingImportMetadata];
    self.pendingImportConfiguration = [configuration copy];
    return;
  }

  UIView *overlay = [[UIView alloc] init];
  overlay.translatesAutoresizingMaskIntoConstraints = NO;
  overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
  overlay.alpha = 0.0f;
  overlay.accessibilityViewIsModal = YES;

  UIView *container = [[UIView alloc] init];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
  container.layer.cornerRadius = 24.0f;
  container.layer.maskedCorners =
      kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
  container.layer.masksToBounds = YES;

  WatermarkPanelView *panel = [[WatermarkPanelView alloc] init];
  panel.translatesAutoresizingMaskIntoConstraints = NO;
  panel.delegate = self;
  [panel applyConfiguration:configuration animated:NO];
  [panel updatePreviewWithImage:self.pendingImportedImage
                       metadata:self.pendingImportMetadata];

  UIStackView *buttons = [[UIStackView alloc] init];
  buttons.translatesAutoresizingMaskIntoConstraints = NO;
  buttons.axis = UILayoutConstraintAxisHorizontal;
  buttons.alignment = UIStackViewAlignmentFill;
  buttons.spacing = 16.0f;
  buttons.distribution = UIStackViewDistributionFillEqually;

  UIButton *cancelButton = [self importActionButtonWithTitle:@"取消"
                                                     primary:NO];
  [cancelButton addTarget:self
                   action:@selector(handleImportCancelTap)
         forControlEvents:UIControlEventTouchUpInside];
  UIButton *applyButton = [self importActionButtonWithTitle:@"应用"
                                                    primary:YES];
  [applyButton addTarget:self
                  action:@selector(handleImportApplyTap)
        forControlEvents:UIControlEventTouchUpInside];

  [buttons addArrangedSubview:cancelButton];
  [buttons addArrangedSubview:applyButton];

  [self.view addSubview:overlay];
  [overlay addSubview:container];
  [container addSubview:panel];
  [container addSubview:buttons];

  [NSLayoutConstraint activateConstraints:@[
    [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];

  [NSLayoutConstraint activateConstraints:@[
    [container.topAnchor constraintEqualToAnchor:overlay.topAnchor],
    [container.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor],
    [container.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor],
    [container.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor]
  ]];

  UILayoutGuide *containerSafe = container.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [panel.topAnchor constraintEqualToAnchor:containerSafe.topAnchor
                                    constant:12.0f],
    [panel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
    [panel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

    [buttons.topAnchor constraintEqualToAnchor:panel.bottomAnchor
                                      constant:16.0f],
    [buttons.leadingAnchor constraintEqualToAnchor:container.leadingAnchor
                                          constant:24.0f],
    [buttons.trailingAnchor constraintEqualToAnchor:container.trailingAnchor
                                           constant:-24.0f],
    [buttons.bottomAnchor constraintEqualToAnchor:containerSafe.bottomAnchor
                                         constant:-20.0f]
  ]];

  [cancelButton.heightAnchor constraintEqualToConstant:48.0f].active = YES;
  [applyButton.heightAnchor constraintEqualToConstant:48.0f].active = YES;

  [self.view layoutIfNeeded];

  CGFloat translation = container.bounds.size.height > 0.0f
                             ? container.bounds.size.height
                             : self.view.bounds.size.height;
  container.transform = CGAffineTransformMakeTranslation(0.0f, translation);

  self.importCustomizationOverlay = overlay;
  self.importCustomizationContainer = container;
  self.importWatermarkPanel = panel;

  [UIView animateWithDuration:0.28
                        delay:0.0
       usingSpringWithDamping:0.9
        initialSpringVelocity:0.6
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     overlay.alpha = 1.0f;
                     container.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];
}

- (void)dismissImportCustomizationAnimated:(BOOL)animated
                                completion:(void (^)(void))completion {
  UIView *overlay = self.importCustomizationOverlay;
  UIView *container = self.importCustomizationContainer;
  if (!overlay) {
    if (completion) {
      completion();
    }
    return;
  }

  void (^cleanup)(void) = ^{
    [overlay removeFromSuperview];
    self.importCustomizationOverlay = nil;
    self.importCustomizationContainer = nil;
    self.importWatermarkPanel = nil;
  };

  if (!animated) {
    cleanup();
    if (completion) {
      completion();
    }
    return;
  }

  CGFloat translation =
      container.bounds.size.height > 0 ? container.bounds.size.height : 400.0f;
  [UIView animateWithDuration:0.2
      animations:^{
        overlay.alpha = 0.0f;
        container.transform =
            CGAffineTransformMakeTranslation(0.0f, translation);
      }
      completion:^(BOOL finished) {
        cleanup();
        if (completion) {
          completion();
        }
      }];
}

- (void)handleImportCancelTap {
  [self dismissImportCustomizationAnimated:YES
                                completion:^{
                                  self.isProcessingImportedImage = NO;
                                  self.pendingImportedImage = nil;
                                  self.pendingImportConfiguration = nil;
                                  self.pendingImportMetadata = nil;
                                }];
}

- (void)handleImportApplyTap {
  [self dismissImportCustomizationAnimated:YES
                                completion:^{
                                  [self beginProcessingPendingImportedImage];
                                }];
}

- (void)beginProcessingPendingImportedImage {
  UIImage *image = self.pendingImportedImage;
  if (!image) {
    self.isProcessingImportedImage = NO;
    return;
  }

  CMWatermarkConfiguration *configuration =
      self.pendingImportConfiguration
          ?: [self.businessController.watermarkConfiguration copy];

  [self showProcessingOverlay];

  __weak typeof(self) weakSelf = self;
  [self.businessController
      processImportedImage:image
                     metadata:self.pendingImportMetadata
            withConfiguration:configuration
                    completion:^(UIImage *_Nullable processedImage,
                                 NSError *_Nullable error) {
                  __strong typeof(weakSelf) strongSelf = weakSelf;
                  if (!strongSelf) {
                    return;
                  }

                  strongSelf.isProcessingImportedImage = NO;
                  strongSelf.pendingImportedImage = nil;
                  strongSelf.pendingImportConfiguration = nil;
                  strongSelf.pendingImportMetadata = nil;

                  [strongSelf hideProcessingOverlay];

                  if (processedImage) {
                    [strongSelf.controlsView
                        updateGalleryButtonWithImage:processedImage];
                    [strongSelf showImagePreview:processedImage];
                  }

                  if (error) {
                    NSString *message =
                        error.localizedDescription ?: @"处理图片失败";
                    [strongSelf showErrorAlert:message];
                  }
                }];
}

#pragma mark - GalleryViewControllerDelegate

- (void)galleryViewControllerDidCancel:(GalleryViewController *)controller {
  [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)galleryViewController:(GalleryViewController *)controller
                 didSelectImage:(UIImage *)image {
  __weak typeof(self) weakSelf = self;
  [controller dismissViewControllerAnimated:YES
                                   completion:^{
                                     __strong typeof(weakSelf) strongSelf =
                                         weakSelf;
                                     if (!strongSelf) {
                                       return;
                                     }
                                     GalleryPreviewViewController *previewVC =
                                         [[GalleryPreviewViewController alloc]
                                             initWithImage:image];
                                     previewVC.delegate = strongSelf;
                                     previewVC.modalPresentationStyle =
                                         UIModalPresentationFullScreen;
                                     [strongSelf presentViewController:previewVC
                                                           animated:YES
                                                         completion:nil];
                                   }];
}

#pragma mark - GalleryPreviewViewControllerDelegate

- (void)galleryPreviewViewControllerDidRequestContinue:
    (GalleryPreviewViewController *)controller {
  self.shouldShowCapturePreview = NO;
  self.hasCapturedPhotoInSession = NO;
  [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)galleryPreviewViewControllerDidRequestEdit:
    (GalleryPreviewViewController *)controller {
  UIImage *selectedImage = controller.image;
  if (!selectedImage) {
    [controller dismissViewControllerAnimated:YES completion:nil];
    return;
  }

  __weak typeof(self) weakSelf = self;
  [controller dismissViewControllerAnimated:YES
                                   completion:^{
                                     __strong typeof(weakSelf) strongSelf =
                                         weakSelf;
                                     if (!strongSelf) {
                                       return;
                                     }
                                     strongSelf.shouldShowCapturePreview = NO;
                                     strongSelf.hasCapturedPhotoInSession = NO;
                                     NSDictionary *metadata =
                                         controller.metadata;
                                     [strongSelf handleImportedImage:
                                                       selectedImage
                                                        metadata:metadata];
                                   }];
}

#pragma mark - WatermarkPanelViewDelegate

- (void)watermarkPanelDidRequestDismiss:(WatermarkPanelView *)panel {
  if (panel == self.importWatermarkPanel) {
    [self handleImportCancelTap];
  }
}

- (void)watermarkPanel:(WatermarkPanelView *)panel
    didUpdateConfiguration:(CMWatermarkConfiguration *)configuration {
  if (panel == self.importWatermarkPanel) {
    self.pendingImportConfiguration = [configuration copy];
  }
}

- (void)showProcessingOverlay {
  if (self.processingOverlay.superview) {
    [self.processingIndicator startAnimating];
    return;
  }

  UIView *overlay = [[UIView alloc] init];
  overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
  overlay.translatesAutoresizingMaskIntoConstraints = NO;

  UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  indicator.translatesAutoresizingMaskIntoConstraints = NO;
  indicator.color = [UIColor whiteColor];
  [indicator startAnimating];

  [overlay addSubview:indicator];
  [self.view addSubview:overlay];

  [NSLayoutConstraint activateConstraints:@[
    [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [indicator.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
    [indicator.centerYAnchor constraintEqualToAnchor:overlay.centerYAnchor]
  ]];

  self.processingOverlay = overlay;
  self.processingIndicator = indicator;
}

- (void)hideProcessingOverlay {
  [self.processingIndicator stopAnimating];
  [self.processingOverlay removeFromSuperview];
  self.processingIndicator = nil;
  self.processingOverlay = nil;
}

- (void)showCaptureFlashEffect {
  UIView *flashView = [[UIView alloc] initWithFrame:self.view.bounds];
  flashView.backgroundColor = [UIColor whiteColor];
  flashView.alpha = 0.0;
  [self.view addSubview:flashView];

  [UIView animateWithDuration:0.1
      animations:^{
        flashView.alpha = 0.8;
      }
      completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2
            animations:^{
              flashView.alpha = 0.0;
            }
            completion:^(BOOL finished) {
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
