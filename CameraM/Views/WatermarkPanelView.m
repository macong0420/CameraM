//
//  WatermarkPanelView.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "WatermarkPanelView.h"
#import "CMWatermarkCatalog.h"
#import "CMWatermarkRenderer.h"

typedef NS_ENUM(NSUInteger, WatermarkPanelSection) {
    WatermarkPanelSectionFrames = 0,
    WatermarkPanelSectionLogos,
    WatermarkPanelSectionText,
    WatermarkPanelSectionPreferences,
    WatermarkPanelSectionPlacement
};

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
        self.contentView.layer.cornerRadius = 14.0;
        self.contentView.layer.borderWidth = 1.0;
        self.contentView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.15] CGColor];
        self.contentView.backgroundColor = [[UIColor colorWithWhite:1.0 alpha:0.05] colorWithAlphaComponent:0.08];
        self.imageView = [[UIImageView alloc] init];
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.imageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.textColor = [UIColor colorWithWhite:0.92 alpha:0.9];
        [self.contentView addSubview:self.titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10.0],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10.0],
            [self.imageView.heightAnchor constraintEqualToAnchor:self.contentView.heightAnchor multiplier:0.68],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:8.0],
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
@property (nonatomic, strong) UIView *toolbarView;
@property (nonatomic, strong) UIStackView *toolbarStack;
@property (nonatomic, strong) NSArray<UIButton *> *toolbarButtons;
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

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIView *> *sectionContentViews;
@property (nonatomic, assign) WatermarkPanelSection activeSection;

@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *previewPlaceholderLabel;
@property (nonatomic, strong) UIActivityIndicatorView *previewActivityIndicator;
@property (nonatomic, strong) NSLayoutConstraint *previewHeightConstraint;

@property (nonatomic, strong) UIImage *userPreviewImage;
@property (nonatomic, copy) NSDictionary *userPreviewMetadata;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *previewImageCache;
@property (nonatomic, strong) dispatch_queue_t previewRenderQueue;
@property (nonatomic, strong) CMWatermarkRenderer *previewRenderer;
@property (nonatomic, strong) NSUUID *previewRenderToken;
@property (nonatomic, assign) BOOL previewNeedsRender;

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
        _previewImageCache = [[NSCache alloc] init];
        _previewImageCache.countLimit = 12;
        _previewRenderQueue = dispatch_queue_create("com.cameram.watermark.preview", DISPATCH_QUEUE_SERIAL);
        _previewRenderer = [[CMWatermarkRenderer alloc] init];
        _previewNeedsRender = YES;

        [self setupHeader];
        [self setupPreviewSection];
        [self setupToolbar];
        [self setupContentStack];
        [self buildSectionContentViews];
        self.activeSection = (WatermarkPanelSection)NSNotFound;
        [self activateSection:WatermarkPanelSectionFrames animated:NO];
        (void)[self updateUIFromConfigurationAnimated:NO];
        [self schedulePreviewRenderIfNeeded];
    }
    return self;
}

#pragma mark - Setup

- (void)setupPreviewSection {
    self.previewContainer = [[UIView alloc] init];
    self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewContainer.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.previewContainer.layer.cornerRadius = 18.0;
    self.previewContainer.layer.masksToBounds = YES;
    [self addSubview:self.previewContainer];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.backgroundColor = [UIColor blackColor];
    [self.previewContainer addSubview:self.previewImageView];

    self.previewPlaceholderLabel = [[UILabel alloc] init];
    self.previewPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewPlaceholderLabel.text = @"选择照片后可实时预览效果";
    self.previewPlaceholderLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.previewPlaceholderLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.previewPlaceholderLabel.numberOfLines = 2;
    self.previewPlaceholderLabel.textAlignment = NSTextAlignmentCenter;
    [self.previewContainer addSubview:self.previewPlaceholderLabel];

    UIActivityIndicatorViewStyle indicatorStyle;
#if defined(__IPHONE_13_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0)
    if (@available(iOS 13.0, *)) {
        indicatorStyle = UIActivityIndicatorViewStyleMedium;
    } else {
        indicatorStyle = UIActivityIndicatorViewStyleWhite;
    }
#else
    indicatorStyle = UIActivityIndicatorViewStyleWhite;
#endif
    self.previewActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:indicatorStyle];
    self.previewActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewActivityIndicator.hidesWhenStopped = YES;
    self.previewActivityIndicator.color = [UIColor whiteColor];
    [self.previewContainer addSubview:self.previewActivityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.previewContainer.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:12.0],
        [self.previewContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0]
    ]];

    self.previewHeightConstraint = [self.previewContainer.heightAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:4.0/5.0];
    self.previewHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    self.previewHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.previewImageView.topAnchor constraintEqualToAnchor:self.previewContainer.topAnchor],
        [self.previewImageView.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor],
        [self.previewImageView.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor],
        [self.previewImageView.bottomAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor],

        [self.previewPlaceholderLabel.centerXAnchor constraintEqualToAnchor:self.previewContainer.centerXAnchor],
        [self.previewPlaceholderLabel.centerYAnchor constraintEqualToAnchor:self.previewContainer.centerYAnchor],
        [self.previewPlaceholderLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.previewContainer.leadingAnchor constant:24.0],
        [self.previewPlaceholderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.previewContainer.trailingAnchor constant:-24.0],

        [self.previewActivityIndicator.centerXAnchor constraintEqualToAnchor:self.previewContainer.centerXAnchor],
        [self.previewActivityIndicator.centerYAnchor constraintEqualToAnchor:self.previewContainer.centerYAnchor]
    ]];
}

- (UIButton *)toolbarButtonWithTitle:(NSString *)title iconName:(NSString *)iconName section:(WatermarkPanelSection)section {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = section;
    button.layer.cornerRadius = 14.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 0.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    button.tintColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    button.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    button.adjustsImageWhenHighlighted = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [button setTitleColor:[UIColor colorWithWhite:0.82 alpha:1.0] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];

    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium];
    UIImage *iconImage = iconName.length > 0 ? [UIImage systemImageNamed:iconName withConfiguration:symbolConfig] : nil;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.image = iconImage;
        configuration.title = title;
        configuration.imagePlacement = NSDirectionalRectEdgeTop;
        configuration.imagePadding = 6.0;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(10.0, 6.0, 10.0, 6.0);
        configuration.baseForegroundColor = [UIColor colorWithWhite:0.82 alpha:1.0];
        button.configuration = configuration;
    } else {
        [button setImage:iconImage forState:UIControlStateNormal];
        [button setTitle:title forState:UIControlStateNormal];
        button.contentEdgeInsets = UIEdgeInsetsMake(14.0, 6.0, 10.0, 6.0);
        CGFloat imageWidth = iconImage.size.width;
        button.titleEdgeInsets = UIEdgeInsetsMake(36.0, -imageWidth, 0.0, 0.0);
        button.imageEdgeInsets = UIEdgeInsetsMake(-6.0, 0.0, 0.0, 0.0);
    }

    [button addTarget:self action:@selector(handleToolbarButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)setupToolbar {
    self.toolbarView = [[UIView alloc] init];
    self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbarView.backgroundColor = [[UIColor colorWithWhite:1.0 alpha:0.06] colorWithAlphaComponent:0.4];
    self.toolbarView.layer.cornerRadius = 18.0;
    self.toolbarView.layer.masksToBounds = YES;
    [self addSubview:self.toolbarView];

    [NSLayoutConstraint activateConstraints:@[
        [self.toolbarView.topAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:12.0],
        [self.toolbarView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
        [self.toolbarView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0]
    ]];

    self.toolbarStack = [[UIStackView alloc] init];
    self.toolbarStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.toolbarStack.axis = UILayoutConstraintAxisHorizontal;
    self.toolbarStack.distribution = UIStackViewDistributionFillEqually;
    self.toolbarStack.spacing = 8.0;
    [self.toolbarView addSubview:self.toolbarStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.toolbarStack.topAnchor constraintEqualToAnchor:self.toolbarView.topAnchor constant:12.0],
        [self.toolbarStack.bottomAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor constant:-12.0],
        [self.toolbarStack.leadingAnchor constraintEqualToAnchor:self.toolbarView.leadingAnchor constant:12.0],
        [self.toolbarStack.trailingAnchor constraintEqualToAnchor:self.toolbarView.trailingAnchor constant:-12.0]
    ]];

    NSArray<NSDictionary *> *items = @[
        @{ @"title": @"模板", @"icon": @"square.grid.2x2", @"section": @(WatermarkPanelSectionFrames) },
        @{ @"title": @"Logo", @"icon": @"seal", @"section": @(WatermarkPanelSectionLogos) },
        @{ @"title": @"文字", @"icon": @"textformat", @"section": @(WatermarkPanelSectionText) },
        @{ @"title": @"参数", @"icon": @"slider.horizontal.3", @"section": @(WatermarkPanelSectionPreferences) },
        @{ @"title": @"位置", @"icon": @"square.split.2x2", @"section": @(WatermarkPanelSectionPlacement) }
    ];

    NSMutableArray<UIButton *> *buttons = [NSMutableArray arrayWithCapacity:items.count];
    for (NSDictionary *item in items) {
        NSString *title = item[@"title"];
        NSString *icon = item[@"icon"];
        WatermarkPanelSection section = [item[@"section"] unsignedIntegerValue];
        UIButton *button = [self toolbarButtonWithTitle:title iconName:icon section:section];
        [self.toolbarStack addArrangedSubview:button];
        [buttons addObject:button];
    }
    self.toolbarButtons = buttons;
}

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
        [self.scrollView.topAnchor constraintEqualToAnchor:self.toolbarView.bottomAnchor constant:16.0],
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

- (void)buildSectionContentViews {
    self.sectionContentViews = [NSMutableDictionary dictionary];

    UIView *frameSection = [self buildFrameSectionView];
    UIView *logoSection = [self buildLogoSectionView];
    UIView *textSection = [self buildTextSectionView];
    UIView *preferenceSection = [self buildPreferenceSectionView];
    UIView *placementSection = [self buildPlacementSectionView];

    if (frameSection) {
        self.sectionContentViews[@(WatermarkPanelSectionFrames)] = frameSection;
    }
    if (logoSection) {
        self.sectionContentViews[@(WatermarkPanelSectionLogos)] = logoSection;
    }
    if (textSection) {
        self.sectionContentViews[@(WatermarkPanelSectionText)] = textSection;
    }
    if (preferenceSection) {
        self.sectionContentViews[@(WatermarkPanelSectionPreferences)] = preferenceSection;
    }
    if (placementSection) {
        self.sectionContentViews[@(WatermarkPanelSectionPlacement)] = placementSection;
    }
}

- (void)applySelectionState:(BOOL)isSelected toToolbarButton:(UIButton *)button {
    UIColor *activeBackground = [[UIColor colorWithRed:1.0 green:0.35 blue:0.1 alpha:1.0] colorWithAlphaComponent:0.25];
    UIColor *inactiveBackground = [UIColor colorWithWhite:1.0 alpha:0.05];
    UIColor *inactiveForeground = [UIColor colorWithWhite:0.82 alpha:1.0];

    button.backgroundColor = isSelected ? activeBackground : inactiveBackground;
    button.layer.borderColor = isSelected ? [UIColor colorWithRed:1.0 green:0.45 blue:0.2 alpha:0.9].CGColor : [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    button.layer.borderWidth = isSelected ? 1.0 : 0.0;

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = button.configuration;
        configuration.baseForegroundColor = isSelected ? [UIColor whiteColor] : inactiveForeground;
        button.configuration = configuration;
    } else {
        UIColor *foreground = isSelected ? [UIColor whiteColor] : inactiveForeground;
        [button setTitleColor:foreground forState:UIControlStateNormal];
        button.tintColor = foreground;
    }
}

- (void)updateToolbarSelectionForSection:(WatermarkPanelSection)section {
    for (UIButton *button in self.toolbarButtons) {
        BOOL selected = (button.tag == section);
        button.selected = selected;
        [self applySelectionState:selected toToolbarButton:button];
    }
}

- (UIButton *)toolbarButtonForSection:(WatermarkPanelSection)section {
    for (UIButton *button in self.toolbarButtons) {
        if (button.tag == section) {
            return button;
        }
    }
    return nil;
}

- (void)activateSection:(WatermarkPanelSection)section animated:(BOOL)animated {
    if (self.activeSection == section) {
        return;
    }

    UIView *targetView = self.sectionContentViews[@(section)];
    if (!targetView) {
        return;
    }

    UIView *previousView = nil;
    if (self.activeSection != (WatermarkPanelSection)NSNotFound) {
        previousView = self.sectionContentViews[@(self.activeSection)];
    }

    if (previousView && previousView.superview == self.contentStack) {
        [self.contentStack removeArrangedSubview:previousView];
        [previousView removeFromSuperview];
    }

    if (targetView.superview) {
        [targetView removeFromSuperview];
    }

    targetView.alpha = animated ? 0.0 : 1.0;
    [self.contentStack addArrangedSubview:targetView];
    [self.contentStack layoutIfNeeded];

    if (animated) {
        [UIView animateWithDuration:0.22 animations:^{
            targetView.alpha = 1.0;
        }];
    }

    if (animated) {
        [self.scrollView setContentOffset:CGPointZero animated:YES];
    } else {
        self.scrollView.contentOffset = CGPointZero;
    }

    self.activeSection = section;
    [self updateToolbarSelectionForSection:section];
}

- (void)handleToolbarButtonTap:(UIButton *)sender {
    WatermarkPanelSection section = (WatermarkPanelSection)sender.tag;
    [self activateSection:section animated:YES];
}

- (UIView *)buildFrameSectionView {
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

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;

    self.frameSectionLabel = [self sectionLabelWithText:@"模板"];
    [stack addArrangedSubview:self.frameSectionLabel];
    [stack addArrangedSubview:self.frameCollectionView];
    [self.frameCollectionView.heightAnchor constraintEqualToConstant:128.0].active = YES;

    return [self containerWrappingStack:stack];
}

- (UIView *)buildLogoSectionView {
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

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;

    self.logoSectionLabel = [self sectionLabelWithText:@"Logo"];
    [stack addArrangedSubview:self.logoSectionLabel];
    [stack addArrangedSubview:self.logoCollectionView];
    [self.logoCollectionView.heightAnchor constraintEqualToConstant:104.0].active = YES;

    return [self containerWrappingStack:stack];
}

- (UIView *)buildTextSectionView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    UILabel *sectionLabel = [self sectionLabelWithText:@"文字"];
    [stack addArrangedSubview:sectionLabel];

    UIView *row = [self formRowWithTitle:@"内容" content:^(UIStackView *container) {
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
    [stack addArrangedSubview:row];

    return [self containerWrappingStack:stack];
}

- (UIView *)buildPreferenceSectionView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    UILabel *sectionLabel = [self sectionLabelWithText:@"参数"];
    [stack addArrangedSubview:sectionLabel];

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
    [stack addArrangedSubview:row];

    return [self containerWrappingStack:stack];
}

- (UIView *)buildPlacementSectionView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    UILabel *sectionLabel = [self sectionLabelWithText:@"位置"];
    [stack addArrangedSubview:sectionLabel];

    UIView *row = [self formRowWithTitle:@"布局" content:^(UIStackView *container) {
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
    [stack addArrangedSubview:row];

    return [self containerWrappingStack:stack];
}

- (UILabel *)sectionLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    return label;
}

- (UIView *)containerWrappingStack:(UIStackView *)stack {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
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

#pragma mark - Preview Rendering

- (UIImage *)normalizedPreviewImageFromImage:(UIImage *)image {
    if (!image) {
        return nil;
    }
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

- (UIImage *)scaledPreviewImageFromImage:(UIImage *)image {
    if (!image) {
        return nil;
    }
    CGFloat maxDimension = 1080.0;
    CGFloat longestSide = MAX(image.size.width, image.size.height);
    if (longestSide <= maxDimension) {
        return image;
    }
    CGFloat scale = maxDimension / longestSide;
    CGSize targetSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 1.0);
    [image drawInRect:CGRectMake(0.0, 0.0, targetSize.width, targetSize.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ?: image;
}

- (UIImage *)preparedPreviewImageFromImage:(UIImage *)image {
    if (!image) {
        return nil;
    }
    UIImage *normalized = [self normalizedPreviewImageFromImage:image];
    return [self scaledPreviewImageFromImage:normalized];
}

- (UIImage *)fallbackPreviewImageForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor {
    if (!descriptor.previewAssetName.length) {
        return nil;
    }
    UIImage *cached = [self.previewImageCache objectForKey:descriptor.previewAssetName];
    if (cached) {
        return cached;
    }
    UIImage *assetImage = [UIImage imageNamed:descriptor.previewAssetName];
    UIImage *prepared = [self preparedPreviewImageFromImage:assetImage];
    if (prepared) {
        [self.previewImageCache setObject:prepared forKey:descriptor.previewAssetName];
    }
    return prepared;
}

- (UIImage *)effectivePreviewSourceImageForConfiguration:(CMWatermarkConfiguration *)configuration descriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor {
    if (self.userPreviewImage) {
        return self.userPreviewImage;
    }
    return [self fallbackPreviewImageForFrameDescriptor:descriptor];
}

- (void)markPreviewNeedsRender {
    self.previewNeedsRender = YES;
    [self schedulePreviewRenderIfNeeded];
}

- (void)updatePreviewLoadingState:(BOOL)isLoading {
    if (isLoading) {
        if (!self.previewActivityIndicator.isAnimating) {
            [self.previewActivityIndicator startAnimating];
        }
    } else {
        [self.previewActivityIndicator stopAnimating];
    }
}

- (void)schedulePreviewRenderIfNeeded {
    if (!self.previewNeedsRender) {
        return;
    }
    self.previewNeedsRender = NO;

    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    UIImage *sourceImage = [self effectivePreviewSourceImageForConfiguration:self.internalConfiguration descriptor:descriptor];

    if (!sourceImage) {
        self.previewPlaceholderLabel.hidden = NO;
        self.previewImageView.image = nil;
        [self updatePreviewLoadingState:NO];
        self.previewRenderToken = nil;
        return;
    }

    self.previewPlaceholderLabel.hidden = YES;
    self.previewImageView.image = sourceImage;

    CMWatermarkConfiguration *configurationSnapshot = [self.internalConfiguration copy];
    NSDictionary *metadataSnapshot = self.userPreviewMetadata ? [self.userPreviewMetadata copy] : nil;

    if (!configurationSnapshot.isEnabled) {
        [self updatePreviewLoadingState:NO];
        self.previewRenderToken = nil;
        return;
    }

    [self updatePreviewLoadingState:YES];

    NSUUID *token = [NSUUID UUID];
    self.previewRenderToken = token;

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.previewRenderQueue, ^{
        @autoreleasepool {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            UIImage *rendered = [strongSelf.previewRenderer renderImage:sourceImage withConfiguration:configurationSnapshot metadata:metadataSnapshot];
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) innerStrongSelf = weakSelf;
                if (!innerStrongSelf) {
                    return;
                }
                if (![innerStrongSelf.previewRenderToken isEqual:token]) {
                    return;
                }
                [innerStrongSelf updatePreviewLoadingState:NO];
                innerStrongSelf.previewImageView.image = rendered ?: sourceImage;
            });
        }
    });
}

#pragma mark - Public API

- (CMWatermarkConfiguration *)configuration {
    return [self.internalConfiguration copy];
}

- (void)applyConfiguration:(CMWatermarkConfiguration *)configuration animated:(BOOL)animated {
    if (!configuration) { return; }
    self.internalConfiguration = [configuration copy];
    (void)[self updateUIFromConfigurationAnimated:animated];
    [self markPreviewNeedsRender];
}

- (void)setPanelEnabled:(BOOL)enabled animated:(BOOL)animated {
    void (^updates)(void) = ^{
        for (UIView *subview in self.contentStack.arrangedSubviews) {
            subview.alpha = enabled ? 1.0 : 0.35;
            subview.userInteractionEnabled = enabled;
        }
        if (self.previewContainer) {
            self.previewContainer.alpha = enabled ? 1.0 : 0.55;
        }
        if (self.toolbarView) {
            self.toolbarView.alpha = enabled ? 1.0 : 0.55;
        }
        for (UIButton *button in self.toolbarButtons) {
            button.userInteractionEnabled = enabled;
            button.alpha = enabled ? 1.0 : 0.35;
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:updates];
    } else {
        updates();
    }
    self.enableSwitch.on = enabled;
    [self markPreviewNeedsRender];
}

- (void)updatePreviewWithImage:(UIImage *)image metadata:(NSDictionary *)metadata {
    self.userPreviewImage = [self preparedPreviewImageFromImage:image];
    self.userPreviewMetadata = metadata;
    [self markPreviewNeedsRender];
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
    UIButton *logoButton = [self toolbarButtonForSection:WatermarkPanelSectionLogos];
    if (logoButton) {
        logoButton.enabled = allowsLogo && panelEnabled;
        logoButton.alpha = allowsLogo ? (panelEnabled ? 1.0 : 0.35) : 0.35;
    }
    if (!allowsLogo) {
        BOOL needsReset = self.internalConfiguration.logoEnabled || ![self.internalConfiguration.logoIdentifier isEqualToString:CMWatermarkLogoIdentifierNone];
        if (needsReset) {
            self.internalConfiguration.logoEnabled = NO;
            self.internalConfiguration.logoIdentifier = CMWatermarkLogoIdentifierNone;
            configurationChanged = YES;
            [self.logoCollectionView reloadData];
        }
        if (self.activeSection == WatermarkPanelSectionLogos) {
            [self activateSection:WatermarkPanelSectionFrames animated:NO];
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
    UIButton *preferenceButton = [self toolbarButtonForSection:WatermarkPanelSectionPreferences];
    if (preferenceButton) {
        preferenceButton.enabled = allowsParameters && panelEnabled;
        preferenceButton.alpha = allowsParameters ? (panelEnabled ? 1.0 : 0.35) : 0.35;
    }
    NSInteger enforcedPreference = descriptor ? descriptor.enforcedPreferenceRawValue : NSNotFound;
    if (!allowsParameters && enforcedPreference != NSNotFound && self.preferenceControl.selectedSegmentIndex != enforcedPreference) {
        self.internalConfiguration.preference = (CMWatermarkPreference)enforcedPreference;
        configurationChanged = YES;
    }
    if (!allowsParameters && enforcedPreference != NSNotFound) {
        self.preferenceControl.selectedSegmentIndex = enforcedPreference;
    }
    if (!allowsParameters && self.activeSection == WatermarkPanelSectionPreferences) {
        [self activateSection:WatermarkPanelSectionFrames animated:NO];
    }

    [self updateToolbarSelectionForSection:self.activeSection];

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
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    NSUInteger frameIndex = [[self.frameDescriptors valueForKey:@"identifier"] indexOfObject:frameId];
    CMWatermarkFrameDescriptor *descriptor = nil;
    if (frameIndex != NSNotFound) {
        descriptor = self.frameDescriptors[frameIndex];
    }
    (void)[self applyRestrictionsForFrameDescriptor:descriptor];
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
        return CGSizeMake(132.0, 112.0);
    }
    return CGSizeMake(96.0, 84.0);
}

#pragma mark - Helpers

- (void)notifyUpdate {
    [self markPreviewNeedsRender];
    if ([self.delegate respondsToSelector:@selector(watermarkPanel:didUpdateConfiguration:)]) {
        [self.delegate watermarkPanel:self didUpdateConfiguration:[self configuration]];
    }
}

@end
