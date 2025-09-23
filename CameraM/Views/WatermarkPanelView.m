//
//  WatermarkPanelView.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "WatermarkPanelView.h"
#import "CMWatermarkCatalog.h"

@interface WatermarkOptionCell : UICollectionViewCell

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;

- (void)configureWithImage:(UIImage * _Nullable)image
                     title:(NSString *)title
                showsTitle:(BOOL)showsTitle
           prefersTemplate:(BOOL)prefersTemplate;

@end

@implementation WatermarkOptionCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.layer.cornerRadius = 12.0;
        self.contentView.layer.borderWidth = 1.0;
        self.contentView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.15] CGColor];
        self.contentView.backgroundColor = [[UIColor colorWithWhite:1.0 alpha:0.05] colorWithAlphaComponent:0.08];
        self.imageView = [[UIImageView alloc] init];
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.imageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.textColor = [UIColor colorWithWhite:0.92 alpha:0.9];
        [self.contentView addSubview:self.titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10.0],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10.0],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10.0],
            [self.imageView.heightAnchor constraintEqualToAnchor:self.contentView.heightAnchor multiplier:0.6],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:6.0],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:6.0],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6.0],
            [self.titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-6.0]
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = nil;
    self.imageView.tintColor = [UIColor whiteColor];
    self.titleLabel.text = @"";
}

- (void)configureWithImage:(UIImage * _Nullable)image
                     title:(NSString *)title
                showsTitle:(BOOL)showsTitle
           prefersTemplate:(BOOL)prefersTemplate {
    if (image) {
        UIImage *renderable = prefersTemplate ? [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : image;
        self.imageView.image = renderable;
        self.imageView.tintColor = prefersTemplate ? [UIColor whiteColor] : nil;
    } else {
        self.imageView.image = nil;
    }
    self.titleLabel.text = title;
    self.titleLabel.hidden = !showsTitle || title.length == 0;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    self.contentView.layer.borderColor = selected ? [UIColor systemOrangeColor].CGColor : [[UIColor colorWithWhite:1.0 alpha:0.2] CGColor];
    self.contentView.layer.borderWidth = selected ? 2.0 : 1.0;
    self.contentView.backgroundColor = selected ? [[UIColor colorWithRed:1.0 green:0.35 blue:0.1 alpha:1.0] colorWithAlphaComponent:0.18] : [[UIColor colorWithWhite:1.0 alpha:0.05] colorWithAlphaComponent:0.08];
}

@end

@interface WatermarkPanelView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITextFieldDelegate>

@property (nonatomic, strong) CMWatermarkConfiguration *internalConfiguration;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *enableLabel;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UICollectionView *frameCollectionView;
@property (nonatomic, strong) UICollectionView *logoCollectionView;
@property (nonatomic, strong) UITextField *captionField;
@property (nonatomic, strong) UISwitch *captionSwitch;
@property (nonatomic, strong) UISwitch *signatureSwitch;
@property (nonatomic, strong) UITextField *signatureField;
@property (nonatomic, strong) UISegmentedControl *preferenceControl;
@property (nonatomic, strong) UISegmentedControl *placementControl;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) UILabel *logoSectionLabel;
@property (nonatomic, strong) UILabel *frameSectionLabel;
@property (nonatomic, strong) UIView *preferenceRow;
@property (nonatomic, strong) UIView *signatureRow;
@property (nonatomic, strong) UIView *placementRow;

@property (nonatomic, copy) NSArray<CMWatermarkFrameDescriptor *> *frameDescriptors;
@property (nonatomic, copy) NSArray<CMWatermarkLogoDescriptor *> *logoDescriptors;

@end

@implementation WatermarkPanelView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.92];
        self.layer.cornerRadius = 24.0;
        if (@available(iOS 11.0, *)) {
            self.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        }
        self.clipsToBounds = YES;

        _frameDescriptors = [CMWatermarkCatalog frameDescriptors];
        _logoDescriptors = [CMWatermarkCatalog logoDescriptors];
        _internalConfiguration = [CMWatermarkConfiguration defaultConfiguration];

        [self setupHeader];
        [self setupContentStack];
        [self setupFrameSection];
        [self setupLogoSection];
        [self setupTextSection];
        // [self setupSignatureSection]; // 署名功能已删除
        [self setupPreferenceSection];
        [self setupPlacementSection];
        (void)[self updateUIFromConfigurationAnimated:NO];
    }
    return self;
}

#pragma mark - Setup

- (void)setupHeader {
    self.headerView = [[UIView alloc] init];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.headerView];

    self.backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backButton setImage:[UIImage systemImageNamed:@"chevron.backward"] forState:UIControlStateNormal];
    self.backButton.tintColor = [UIColor whiteColor];
    [self.backButton addTarget:self action:@selector(handleDismissTap) forControlEvents:UIControlEventTouchUpInside];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"水印";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];

    self.enableLabel = [[UILabel alloc] init];
    self.enableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableLabel.text = @"启用";
    self.enableLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.enableLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];

    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableSwitch.onTintColor = [UIColor systemOrangeColor];
    [self.enableSwitch addTarget:self action:@selector(handleEnableSwitch:) forControlEvents:UIControlEventValueChanged];

    [self.headerView addSubview:self.backButton];
    [self.headerView addSubview:self.titleLabel];
    [self.headerView addSubview:self.enableLabel];
    [self.headerView addSubview:self.enableSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.topAnchor constant:12.0],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [self.headerView.heightAnchor constraintEqualToConstant:44.0],

        [self.backButton.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.backButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.backButton.widthAnchor constraintEqualToConstant:36.0],
        [self.backButton.heightAnchor constraintEqualToConstant:36.0],

        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],

        [self.enableSwitch.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.enableSwitch.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],

        [self.enableLabel.trailingAnchor constraintEqualToAnchor:self.enableSwitch.leadingAnchor constant:-8.0],
        [self.enableLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor]
    ]];
}

- (void)setupContentStack {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:self.scrollView];

    UILayoutGuide *frameGuide = self.scrollView.frameLayoutGuide;
    UILayoutGuide *contentGuide = self.scrollView.contentLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:12.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18.0;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:frameGuide.leadingAnchor constant:16.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:frameGuide.trailingAnchor constant:-16.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor constant:-24.0]
    ]];
}

- (void)setupFrameSection {
    self.frameSectionLabel = [self sectionLabelWithText:@"模板"];
    [self.contentStack addArrangedSubview:self.frameSectionLabel];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;

    self.frameCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.frameCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.frameCollectionView.backgroundColor = [UIColor clearColor];
    self.frameCollectionView.showsHorizontalScrollIndicator = NO;
    self.frameCollectionView.dataSource = self;
    self.frameCollectionView.delegate = self;
    [self.frameCollectionView registerClass:[WatermarkOptionCell class] forCellWithReuseIdentifier:@"frame.cell"];
    [self.contentStack addArrangedSubview:self.frameCollectionView];
    [self.frameCollectionView.heightAnchor constraintEqualToConstant:110.0].active = YES;
}

- (void)setupLogoSection {
    self.logoSectionLabel = [self sectionLabelWithText:@"Logo"];
    [self.contentStack addArrangedSubview:self.logoSectionLabel];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12.0;
    layout.minimumInteritemSpacing = 12.0;

    self.logoCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.logoCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoCollectionView.backgroundColor = [UIColor clearColor];
    self.logoCollectionView.showsHorizontalScrollIndicator = NO;
    self.logoCollectionView.dataSource = self;
    self.logoCollectionView.delegate = self;
    [self.logoCollectionView registerClass:[WatermarkOptionCell class] forCellWithReuseIdentifier:@"logo.cell"];
    [self.contentStack addArrangedSubview:self.logoCollectionView];
    [self.logoCollectionView.heightAnchor constraintEqualToConstant:92.0].active = YES;
}

- (void)setupTextSection {
    UIView *row = [self formRowWithTitle:@"文字" content:^(UIStackView *container) {
        self.captionField = [[UITextField alloc] init];
        self.captionField.translatesAutoresizingMaskIntoConstraints = NO;
        self.captionField.placeholder = @"输入水印文字";
        self.captionField.textColor = [UIColor whiteColor];
        self.captionField.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        self.captionField.delegate = self;
        self.captionField.borderStyle = UITextBorderStyleRoundedRect;
        self.captionField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.captionField.layer.cornerRadius = 10.0;
        self.captionField.layer.masksToBounds = YES;
        self.captionField.returnKeyType = UIReturnKeyDone;
        [self.captionField addTarget:self action:@selector(handleCaptionEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        [container addArrangedSubview:self.captionField];

        self.captionSwitch = [[UISwitch alloc] init];
        self.captionSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.captionSwitch.onTintColor = [UIColor systemOrangeColor];
        [self.captionSwitch addTarget:self action:@selector(handleCaptionSwitch:) forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.captionSwitch];
    }];
    [self.contentStack addArrangedSubview:row];
}

- (void)setupSignatureSection {
    UIView *row = [self formRowWithTitle:@"署名" content:^(UIStackView *container) {
        self.signatureField = [[UITextField alloc] init];
        self.signatureField.translatesAutoresizingMaskIntoConstraints = NO;
        self.signatureField.placeholder = @"输入署名";
        self.signatureField.textColor = [UIColor whiteColor];
        self.signatureField.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
        self.signatureField.borderStyle = UITextBorderStyleRoundedRect;
        self.signatureField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.signatureField.layer.cornerRadius = 10.0;
        self.signatureField.layer.masksToBounds = YES;
        self.signatureField.delegate = self;
        self.signatureField.returnKeyType = UIReturnKeyDone;
        [self.signatureField addTarget:self action:@selector(handleSignatureEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        [container addArrangedSubview:self.signatureField];

        self.signatureSwitch = [[UISwitch alloc] init];
        self.signatureSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.signatureSwitch.onTintColor = [UIColor systemOrangeColor];
        [self.signatureSwitch addTarget:self action:@selector(handleSignatureSwitch:) forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.signatureSwitch];
    }];
    self.signatureRow = row;
    [self.contentStack addArrangedSubview:row];
}

- (void)setupPreferenceSection {
    UIView *row = [self formRowWithTitle:@"偏好" content:^(UIStackView *container) {
        self.preferenceControl = [[UISegmentedControl alloc] initWithItems:@[@"OFF", @"参数", @"经纬度", @"日期"]];
        self.preferenceControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.preferenceControl.selectedSegmentIndex = CMWatermarkPreferenceExposure;
        self.preferenceControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.preferenceControl.selectedSegmentTintColor = [UIColor systemOrangeColor];
        [self.preferenceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [self.preferenceControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
        [self.preferenceControl addTarget:self action:@selector(handlePreferenceChanged:) forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.preferenceControl];
    }];
    self.preferenceRow = row;
    [self.contentStack addArrangedSubview:row];
}

- (void)setupPlacementSection {
    UIView *row = [self formRowWithTitle:@"位置" content:^(UIStackView *container) {
        self.placementControl = [[UISegmentedControl alloc] initWithItems:@[@"中", @"下"]];
        self.placementControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.placementControl.selectedSegmentIndex = CMWatermarkPlacementBottom;
        self.placementControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.placementControl.selectedSegmentTintColor = [UIColor systemOrangeColor];
        [self.placementControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [self.placementControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
        [self.placementControl addTarget:self action:@selector(handlePlacementChanged:) forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.placementControl];
    }];
    self.placementRow = row;
    [self.contentStack addArrangedSubview:row];
}

- (UILabel *)sectionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    return label;
}

- (UIView *)formRowWithTitle:(NSString *)title content:(void(^)(UIStackView *container))contentFactory {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];

    UIStackView *container = [[UIStackView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.axis = UILayoutConstraintAxisHorizontal;
    container.spacing = 12.0;
    container.alignment = UIStackViewAlignmentCenter;

    if (contentFactory) {
        contentFactory(container);
    }

    [row addSubview:titleLabel];
    [row addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor],
        [titleLabel.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [titleLabel.widthAnchor constraintEqualToConstant:48.0],

        [container.leadingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor constant:12.0],
        [container.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [container.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:36.0]
    ]];

    return row;
}

#pragma mark - Public API

- (CMWatermarkConfiguration *)configuration {
    return [self.internalConfiguration copy];
}

- (void)applyConfiguration:(CMWatermarkConfiguration *)configuration animated:(BOOL)animated {
    if (!configuration) { return; }
    self.internalConfiguration = [configuration copy];
    (void)[self updateUIFromConfigurationAnimated:animated];
}

- (void)setPanelEnabled:(BOOL)enabled animated:(BOOL)animated {
    void (^updates)(void) = ^{
        for (UIView *subview in self.contentStack.arrangedSubviews) {
            subview.alpha = enabled ? 1.0 : 0.35;
            subview.userInteractionEnabled = enabled;
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:updates];
    } else {
        updates();
    }
    self.enableSwitch.on = enabled;
}

#pragma mark - UI Refresh

- (BOOL)updateUIFromConfigurationAnimated:(BOOL)animated {
    BOOL enabled = self.internalConfiguration.isEnabled;
    self.enableSwitch.on = enabled;
    [self setPanelEnabled:enabled animated:NO];

    // Frames
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    NSUInteger frameIndex = [[self.frameDescriptors valueForKey:@"identifier"] indexOfObject:frameId];
    CMWatermarkFrameDescriptor *activeFrame = nil;
    if (frameIndex != NSNotFound) {
        activeFrame = self.frameDescriptors[frameIndex];
    }

    BOOL didMutateConfiguration = [self applyRestrictionsForFrameDescriptor:activeFrame];

    if (frameIndex != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:frameIndex inSection:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.frameCollectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
        });
    }

    // Logos
    NSString *logoId = self.internalConfiguration.logoIdentifier ?: CMWatermarkLogoIdentifierNone;
    NSUInteger logoIndex = [[self.logoDescriptors valueForKey:@"identifier"] indexOfObject:logoId];
    if (logoIndex != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:logoIndex inSection:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.logoCollectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
        });
    }

    self.captionSwitch.on = self.internalConfiguration.isCaptionEnabled;
    self.captionField.text = self.internalConfiguration.captionText;
    self.captionField.enabled = self.internalConfiguration.isCaptionEnabled && enabled;

    // 署名功能已删除
    // self.signatureSwitch.on = self.internalConfiguration.isSignatureEnabled;
    // self.signatureField.text = self.internalConfiguration.signatureText;
    // self.signatureField.enabled = self.internalConfiguration.isSignatureEnabled && enabled;

    self.preferenceControl.selectedSegmentIndex = self.internalConfiguration.preference;
    self.preferenceControl.enabled = enabled && self.preferenceControl.userInteractionEnabled;
    
    // 确保宝丽来模式下preferenceOptions与preference同步
    NSString *currentFrameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    if ([currentFrameId isEqualToString:@"frame.polaroid"]) {
        switch (self.internalConfiguration.preference) {
            case CMWatermarkPreferenceOff:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsNone;
                break;
            case CMWatermarkPreferenceExposure:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsExposure;
                break;
            case CMWatermarkPreferenceCoordinates:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsCoordinates;
                break;
            case CMWatermarkPreferenceDate:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsDate;
                break;
        }
    }

    self.placementControl.selectedSegmentIndex = self.internalConfiguration.placement;
    self.placementControl.enabled = enabled;

    return didMutateConfiguration;
}

- (BOOL)applyRestrictionsForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor {
    BOOL configurationChanged = NO;

    BOOL panelEnabled = self.internalConfiguration.isEnabled;

    BOOL allowsLogo = descriptor ? descriptor.allowsLogoEditing : YES;
    if (self.logoSectionLabel) {
        self.logoSectionLabel.hidden = !allowsLogo;
        self.logoSectionLabel.alpha = allowsLogo ? (panelEnabled ? 1.0 : 0.35) : 0.0;
    }
    if (self.logoCollectionView) {
        self.logoCollectionView.hidden = !allowsLogo;
        self.logoCollectionView.alpha = allowsLogo ? (panelEnabled ? 1.0 : 0.35) : 0.0;
        self.logoCollectionView.userInteractionEnabled = allowsLogo && panelEnabled;
    }
    if (!allowsLogo) {
        BOOL needsReset = self.internalConfiguration.logoEnabled || ![self.internalConfiguration.logoIdentifier isEqualToString:CMWatermarkLogoIdentifierNone];
        if (needsReset) {
            self.internalConfiguration.logoEnabled = NO;
            self.internalConfiguration.logoIdentifier = CMWatermarkLogoIdentifierNone;
            configurationChanged = YES;
            [self.logoCollectionView reloadData];
        }
    }

    BOOL allowsParameters = descriptor ? descriptor.allowsParameterEditing : YES;
    if (self.preferenceRow) {
        self.preferenceRow.hidden = !allowsParameters;
        self.preferenceRow.alpha = allowsParameters ? (panelEnabled ? 1.0 : 0.35) : 0.0;
    }
    if (self.preferenceControl) {
        self.preferenceControl.userInteractionEnabled = allowsParameters && panelEnabled;
    }
    NSInteger enforcedPreference = descriptor ? descriptor.enforcedPreferenceRawValue : NSNotFound;
    if (!allowsParameters && enforcedPreference != NSNotFound && self.preferenceControl.selectedSegmentIndex != enforcedPreference) {
        self.internalConfiguration.preference = (CMWatermarkPreference)enforcedPreference;
        configurationChanged = YES;
    }
    if (!allowsParameters && enforcedPreference != NSNotFound) {
        self.preferenceControl.selectedSegmentIndex = enforcedPreference;
    }

    // 署名功能已删除
    // BOOL allowsSignature = descriptor ? descriptor.allowsSignatureEditing : YES;
    // if (self.signatureRow) {
    //     self.signatureRow.hidden = !allowsSignature;
    //     self.signatureRow.alpha = allowsSignature ? (panelEnabled ? 1.0 : 0.35) : 0.0;
    // }
    // if (self.signatureSwitch) {
    //     self.signatureSwitch.userInteractionEnabled = allowsSignature && panelEnabled;
    //     self.signatureSwitch.enabled = allowsSignature && panelEnabled;
    // }
    // if (self.signatureField) {
    //     self.signatureField.userInteractionEnabled = allowsSignature && panelEnabled;
    // }
    // if (!allowsSignature) {
    //     BOOL hadSignature = self.internalConfiguration.isSignatureEnabled || self.internalConfiguration.signatureText.length > 0;
    //     if (hadSignature) {
    //         self.internalConfiguration.signatureEnabled = NO;
    //         self.internalConfiguration.signatureText = @"";
    //         configurationChanged = YES;
    //     }
    // }
    
    // 宝丽来模式不允许位置设置
    BOOL allowsPlacement = !(descriptor && [descriptor.identifier isEqualToString:@"frame.polaroid"]);
    if (self.placementRow) {
        self.placementRow.hidden = !allowsPlacement;
        self.placementRow.alpha = allowsPlacement ? (panelEnabled ? 1.0 : 0.35) : 0.0;
    }
    if (self.placementControl) {
        self.placementControl.userInteractionEnabled = allowsPlacement && panelEnabled;
        self.placementControl.enabled = allowsPlacement && panelEnabled;
    }

    return configurationChanged;
}

#pragma mark - Actions

- (void)handleDismissTap {
    if ([self.delegate respondsToSelector:@selector(watermarkPanelDidRequestDismiss:)]) {
        [self.delegate watermarkPanelDidRequestDismiss:self];
    }
}

- (void)handleEnableSwitch:(UISwitch *)sender {
    self.internalConfiguration.enabled = sender.isOn;
    [self setPanelEnabled:sender.isOn animated:YES];
    [self notifyUpdate];
}

- (void)handleCaptionSwitch:(UISwitch *)sender {
    self.internalConfiguration.captionEnabled = sender.isOn;
    self.captionField.enabled = sender.isOn && self.internalConfiguration.isEnabled;
    [self notifyUpdate];
}

- (void)handleSignatureSwitch:(UISwitch *)sender {
    self.internalConfiguration.signatureEnabled = sender.isOn;
    self.signatureField.enabled = sender.isOn && self.internalConfiguration.isEnabled;
    [self notifyUpdate];
}

- (void)handlePreferenceChanged:(UISegmentedControl *)sender {
    self.internalConfiguration.preference = (CMWatermarkPreference)sender.selectedSegmentIndex;
    
    // 对于宝丽来模式，同时更新preferenceOptions来支持多选显示
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    if ([frameId isEqualToString:@"frame.polaroid"]) {
        // 宝丽来模式：将单选preference转换为对应的preferenceOptions
        switch (self.internalConfiguration.preference) {
            case CMWatermarkPreferenceOff:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsNone;
                break;
            case CMWatermarkPreferenceExposure:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsExposure;
                break;
            case CMWatermarkPreferenceCoordinates:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsCoordinates;
                break;
            case CMWatermarkPreferenceDate:
                self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsDate;
                break;
        }
    }
    
    [self notifyUpdate];
}

- (void)handlePlacementChanged:(UISegmentedControl *)sender {
    self.internalConfiguration.placement = (CMWatermarkPlacement)sender.selectedSegmentIndex;
    [self notifyUpdate];
}

- (void)handleCaptionEditingChanged:(UITextField *)textField {
    self.internalConfiguration.captionText = textField.text ?: @"";
    [self notifyUpdate];
}

- (void)handleSignatureEditingChanged:(UITextField *)textField {
    self.internalConfiguration.signatureText = textField.text ?: @"";
    if (self.internalConfiguration.signatureText.length > 0) {
        self.internalConfiguration.signatureEnabled = YES;
        if (!self.signatureSwitch.on) {
            self.signatureSwitch.on = YES;
        }
    }
    [self notifyUpdate];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (collectionView == self.frameCollectionView) {
        return self.frameDescriptors.count;
    }
    return self.logoDescriptors.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    WatermarkOptionCell *cell;
    if (collectionView == self.frameCollectionView) {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"frame.cell" forIndexPath:indexPath];
        CMWatermarkFrameDescriptor *descriptor = self.frameDescriptors[indexPath.item];
        UIImage *preview = descriptor.previewAssetName.length ? [UIImage imageNamed:descriptor.previewAssetName] : nil;
        [cell configureWithImage:preview title:descriptor.displayName showsTitle:YES prefersTemplate:NO];
        BOOL isSelected = [descriptor.identifier isEqualToString:(self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone)];
        cell.selected = isSelected;
    } else {
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"logo.cell" forIndexPath:indexPath];
        CMWatermarkLogoDescriptor *descriptor = self.logoDescriptors[indexPath.item];
        UIImage *preview = descriptor.assetName.length ? [UIImage imageNamed:descriptor.assetName] : nil;
        NSString *display = descriptor.displayName ?: @"";
        BOOL showsTitle = (preview == nil);
        [cell configureWithImage:preview title:display showsTitle:showsTitle prefersTemplate:descriptor.prefersTemplateRendering];
        BOOL isSelected = [descriptor.identifier isEqualToString:(self.internalConfiguration.logoIdentifier ?: CMWatermarkLogoIdentifierNone)];
        cell.selected = isSelected;
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == self.frameCollectionView) {
        CMWatermarkFrameDescriptor *descriptor = self.frameDescriptors[indexPath.item];
        self.internalConfiguration.frameIdentifier = descriptor.identifier;
        [self updateUIFromConfigurationAnimated:YES];
        [self notifyUpdate];
    } else {
        if (!self.logoCollectionView.userInteractionEnabled) {
            return;
        }
        CMWatermarkLogoDescriptor *descriptor = self.logoDescriptors[indexPath.item];
        self.internalConfiguration.logoIdentifier = descriptor.identifier;
        self.internalConfiguration.logoEnabled = descriptor.assetName.length > 0;
        [self notifyUpdate];
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == self.frameCollectionView) {
        return CGSizeMake(120.0, 96.0);
    }
    return CGSizeMake(86.0, 72.0);
}

#pragma mark - Helpers

- (void)notifyUpdate {
    if ([self.delegate respondsToSelector:@selector(watermarkPanel:didUpdateConfiguration:)]) {
        [self.delegate watermarkPanel:self didUpdateConfiguration:[self configuration]];
    }
}

@end
