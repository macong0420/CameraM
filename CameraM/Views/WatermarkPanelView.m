//
//  WatermarkPanelView.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "WatermarkPanelView.h"
#import "CMWatermarkCatalog.h"
#import "CMWatermarkRenderer.h"
#import <math.h>

typedef struct {
    BOOL supportsLogoSelection;
    BOOL supportsCustomText;
    BOOL supportsShootingDataMasterSwitch;
    BOOL supportsAnchorPlacement;
    BOOL supportsCustomFont;
    BOOL supportsDetailMetadata;
    BOOL supportsPlacement;
} CMWatermarkUIAvailability;

static inline CMWatermarkUIAvailability CMWatermarkUIAvailabilityMake(BOOL enabled) {
    CMWatermarkUIAvailability availability;
    availability.supportsLogoSelection = enabled;
    availability.supportsCustomText = enabled;
    availability.supportsShootingDataMasterSwitch = enabled;
    availability.supportsAnchorPlacement = enabled;
    availability.supportsCustomFont = enabled;
    availability.supportsDetailMetadata = enabled;
    availability.supportsPlacement = enabled;
    return availability;
}

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
        self.contentView.layer.cornerRadius = 10.0;
        self.contentView.layer.borderWidth = 1.0;
        self.contentView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.12] CGColor];
        self.contentView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        self.imageView = [[UIImageView alloc] init];
        self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.imageView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightSemibold];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.textColor = [UIColor colorWithWhite:0.92 alpha:0.9];
        [self.contentView addSubview:self.titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8.0],
            [self.imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8.0],
            [self.imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8.0],
            [self.imageView.heightAnchor constraintEqualToAnchor:self.contentView.heightAnchor multiplier:0.66],

            [self.titleLabel.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:4.0],
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:6.0],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6.0],
            [self.titleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-4.0]
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
    self.contentView.layer.borderColor = selected ? [UIColor colorWithWhite:0.95 alpha:1.0].CGColor : [[UIColor colorWithWhite:1.0 alpha:0.2] CGColor];
    self.contentView.layer.borderWidth = selected ? 2.0 : 1.0;
    self.contentView.backgroundColor = selected ? [UIColor colorWithWhite:1.0 alpha:0.16] : [UIColor colorWithWhite:1.0 alpha:0.06];
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

@property (nonatomic, strong) UIView *logosSectionContainer;
@property (nonatomic, strong) UIView *preferencesSectionContainer;
@property (nonatomic, strong) UIView *placementSectionContainer;
@property (nonatomic, strong) UIView *displayParamsSectionContainer;
@property (nonatomic, strong) UISwitch *displayParamsSwitch;
@property (nonatomic, strong) UIButton *detailSettingsButton;
@property (nonatomic, strong) UIView *textSectionContainer;
@property (nonatomic, strong) UIView *textRowContainer;
@property (nonatomic, strong) UIView *subtitleRowContainer;
@property (nonatomic, strong) UITextField *subtitleField;
@property (nonatomic, strong) UISwitch *subtitleSwitch;
@property (nonatomic, strong) UILabel *textPresetHintLabel;

@property (nonatomic, strong) UIView *detailBackdropView;
@property (nonatomic, strong) UIView *detailCardView;
@property (nonatomic, strong) UISegmentedControl *detailAnchorControl;
@property (nonatomic, strong) UILabel *detailFontValueLabel;
@property (nonatomic, strong) UILabel *detailAnchorSectionLabel;
@property (nonatomic, strong) UILabel *detailFontSectionLabel;
@property (nonatomic, strong) UILabel *detailMetadataSectionLabel;
@property (nonatomic, strong) UIView *detailFontRow;
@property (nonatomic, strong) NSArray<UIView *> *detailMetadataRows;
@property (nonatomic, strong) UISwitch *detailLensSwitch;
@property (nonatomic, strong) UISwitch *detailShutterSwitch;
@property (nonatomic, strong) UISwitch *detailApertureSwitch;
@property (nonatomic, strong) UISwitch *detailISOSwitch;
@property (nonatomic, strong) UISwitch *detailDateSwitch;
@property (nonatomic, strong) UISwitch *detailLocationSwitch;
@property (nonatomic, strong) UIStackView *detailFrameButtonsStack;


@property (nonatomic, strong) UIView *controlsContainer;
@property (nonatomic, strong) NSLayoutConstraint *controlsMinHeightConstraint;

@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *previewPlaceholderLabel;
@property (nonatomic, strong) UIActivityIndicatorView *previewActivityIndicator;
@property (nonatomic, strong) NSLayoutConstraint *previewAspectConstraint;
@property (nonatomic, strong) NSLayoutConstraint *previewMaxHeightConstraint;
@property (nonatomic, assign) CGFloat previewAspectRatio;

@property (nonatomic, strong) UIImage *userPreviewImage;
@property (nonatomic, copy) NSDictionary *userPreviewMetadata;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *previewImageCache;
@property (nonatomic, strong) dispatch_queue_t previewRenderQueue;
@property (nonatomic, strong) CMWatermarkRenderer *previewRenderer;
@property (nonatomic, strong) NSUUID *previewRenderToken;
@property (nonatomic, assign) BOOL previewNeedsRender;

@property (nonatomic, copy) NSArray<CMWatermarkFrameDescriptor *> *frameDescriptors;
@property (nonatomic, copy) NSArray<CMWatermarkLogoDescriptor *> *logoDescriptors;
@property (nonatomic, weak) UITextField *activeTextField;
@property (nonatomic, assign) UIEdgeInsets scrollViewBaseContentInset;
@property (nonatomic, assign) UIEdgeInsets scrollViewBaseIndicatorInsets;

- (CMWatermarkUIAvailability)availabilityForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor;
- (void)applyEnabledState:(BOOL)enabled toView:(UIView * _Nullable)view;
- (BOOL)applyRestrictionsForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor;

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

        [self registerForKeyboardNotifications];

        [self setupHeader];
        [self setupControlsContainer];
        [self setupPreviewSection];
        [self setupContentStack];
        [self buildSectionContentViews];
        [self setupDetailSettingsCard];
        (void)[self updateUIFromConfigurationAnimated:NO];
        [self schedulePreviewRenderIfNeeded];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updatePreviewMaxHeightForCurrentLayout];
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self setNeedsLayout];
}

- (void)setupControlsContainer {
    if (self.controlsContainer) {
        return;
    }

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor colorWithWhite:0.03 alpha:0.96];
    container.layer.cornerRadius = 20.0;
    if (@available(iOS 11.0, *)) {
        container.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }
    container.layer.masksToBounds = YES;
    [self addSubview:container];

    UILayoutGuide *safeGuide = self.safeAreaLayoutGuide;
    self.controlsMinHeightConstraint = [container.heightAnchor constraintGreaterThanOrEqualToConstant:220.0];
    self.controlsMinHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    self.controlsMinHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [container.bottomAnchor constraintEqualToAnchor:safeGuide.bottomAnchor]
    ]];

    [container setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [container setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];

    self.controlsContainer = container;
}

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
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        [self.previewContainer.bottomAnchor constraintEqualToAnchor:self.controlsContainer.topAnchor constant:-16.0]
    ]];

    self.previewAspectRatio = 4.0 / 3.0;
    self.previewAspectConstraint = [self.previewContainer.heightAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:self.previewAspectRatio];
    self.previewAspectConstraint.priority = UILayoutPriorityDefaultHigh;
    self.previewAspectConstraint.active = YES;

    self.previewMaxHeightConstraint = [self.previewContainer.heightAnchor constraintLessThanOrEqualToConstant:0.0];
    self.previewMaxHeightConstraint.priority = UILayoutPriorityRequired;
    self.previewMaxHeightConstraint.active = YES;

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

    [self.previewContainer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [self.previewContainer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
}

- (void)updatePreviewAspectConstraintForImage:(UIImage *)image {
    CGFloat aspect = 4.0f / 3.0f;
    if (image.size.width > 0.0f) {
        aspect = image.size.height / image.size.width;
    }
    aspect = MIN(MAX(aspect, 0.6f), 2.6f);

    BOOL hasExistingConstraint = (self.previewAspectConstraint != nil);
    CGFloat delta = fabs(aspect - self.previewAspectRatio);
    if (hasExistingConstraint && delta < 0.01f) {
        return;
    }

    if (self.previewAspectConstraint) {
        self.previewAspectConstraint.active = NO;
    }

    self.previewAspectConstraint = [self.previewContainer.heightAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:aspect];
    self.previewAspectConstraint.priority = UILayoutPriorityDefaultHigh;
    self.previewAspectConstraint.active = YES;
    self.previewAspectRatio = aspect;

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)updatePreviewMaxHeightForCurrentLayout {
    CGFloat totalHeight = CGRectGetHeight(self.bounds);
    CGFloat totalWidth = CGRectGetWidth(self.bounds);
    if (totalHeight <= 0.0f || totalWidth <= 0.0f) {
        return;
    }

    CGFloat headerReserved = 12.0f + 44.0f + 12.0f; // top inset + header height + spacing
    CGFloat bottomSpacing = 16.0f + self.safeAreaInsets.bottom;
    CGFloat currentControlsHeight = CGRectGetHeight(self.controlsContainer.bounds);
    CGFloat minimumControls = self.controlsMinHeightConstraint.constant + 12.0f; // include bottom padding inside controls container
    if (currentControlsHeight > 0.0f) {
        minimumControls = MAX(minimumControls, currentControlsHeight + 12.0f);
    }

    CGFloat maxHeight = totalHeight - headerReserved - bottomSpacing - minimumControls;
    maxHeight = MAX(maxHeight, 160.0f);

    if (fabs(maxHeight - self.previewMaxHeightConstraint.constant) > 1.0f) {
        self.previewMaxHeightConstraint.constant = maxHeight;
    }
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
    self.backButton.hidden = YES;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"CAPTURE PERSONALIZATION";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];

    self.enableLabel = [[UILabel alloc] init];
    self.enableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableLabel.text = @"Enable Watermark";
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

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.enableLabel.leadingAnchor constant:-10.0],
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
    [self.controlsContainer addSubview:self.scrollView];

    UILayoutGuide *frameGuide = self.scrollView.frameLayoutGuide;
    UILayoutGuide *contentGuide = self.scrollView.contentLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.controlsContainer.topAnchor constant:12.0],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.controlsContainer.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.controlsContainer.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.controlsContainer.bottomAnchor constant:-12.0]
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

    self.scrollViewBaseContentInset = self.scrollView.contentInset;
    self.scrollViewBaseIndicatorInsets = self.scrollView.scrollIndicatorInsets;
}

- (void)buildSectionContentViews {
    UIView *framesSection = [self buildFrameSectionView];
    self.logosSectionContainer = [self buildLogoSectionView];
    UIView *textSection = [self buildTextSectionView];
    self.displayParamsSectionContainer = [self buildDisplayParamsSectionView];
    UIView *detailEntrySection = [self buildDetailEntrySectionView];

    NSArray<UIView *> *sections = @[ framesSection,
                                     self.logosSectionContainer,
                                     textSection,
                                     self.displayParamsSectionContainer,
                                     detailEntrySection ];

    for (UIView *sectionView in sections) {
        if (sectionView) {
            sectionView.hidden = NO;
            sectionView.alpha = 1.0;
            [self.contentStack addArrangedSubview:sectionView];
        }
    }
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

    self.frameSectionLabel = [self sectionLabelWithText:@"Frame Style"];
    [stack addArrangedSubview:self.frameSectionLabel];
    [stack addArrangedSubview:self.frameCollectionView];
    [self.frameCollectionView.heightAnchor constraintEqualToConstant:92.0].active = YES;

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

    self.logoSectionLabel = [self sectionLabelWithText:@"Logo Selection"];
    [stack addArrangedSubview:self.logoSectionLabel];
    [stack addArrangedSubview:self.logoCollectionView];
    [self.logoCollectionView.heightAnchor constraintEqualToConstant:74.0].active = YES;

    return [self containerWrappingStack:stack];

}

- (UIView *)buildTextSectionView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    UILabel *sectionLabel = [self sectionLabelWithText:@"Custom Text"];
    [stack addArrangedSubview:sectionLabel];

    UIView *row = [self formRowWithTitle:@"Custom Text" content:^(UIStackView *container) {
        self.captionField = [[UITextField alloc] init];
        self.captionField.translatesAutoresizingMaskIntoConstraints = NO;
        self.captionField.placeholder = @"Mr.C | PHOTOGRAPHY 2026";
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
    self.textRowContainer = row;
    [stack addArrangedSubview:row];

    UIView *subtitleRow = [self formRowWithTitle:@"Sub Text" content:^(UIStackView *container) {
        self.subtitleField = [[UITextField alloc] init];
        self.subtitleField.translatesAutoresizingMaskIntoConstraints = NO;
        self.subtitleField.placeholder = @"XCD 3,5 / 120 MACRO";
        self.subtitleField.textColor = [UIColor whiteColor];
        self.subtitleField.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
        self.subtitleField.delegate = self;
        self.subtitleField.borderStyle = UITextBorderStyleRoundedRect;
        self.subtitleField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.subtitleField.layer.cornerRadius = 10.0;
        self.subtitleField.layer.masksToBounds = YES;
        self.subtitleField.returnKeyType = UIReturnKeyDone;
        [self.subtitleField addTarget:self action:@selector(handleSubtitleEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        [container addArrangedSubview:self.subtitleField];

        self.subtitleSwitch = [[UISwitch alloc] init];
        self.subtitleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.subtitleSwitch.onTintColor = [UIColor systemOrangeColor];
        [self.subtitleSwitch addTarget:self action:@selector(handleSubtitleSwitch:) forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.subtitleSwitch];
    }];
    self.subtitleRowContainer = subtitleRow;
    [stack addArrangedSubview:subtitleRow];

    UILabel *presetHint = [[UILabel alloc] init];
    presetHint.text = @"Preset | Custom | Fast Gr. | Garamond Premier Pro / Helvetica Neue";
    presetHint.textColor = [UIColor colorWithWhite:1.0 alpha:0.45];
    presetHint.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightRegular];
    self.textPresetHintLabel = presetHint;
    [stack addArrangedSubview:presetHint];

    self.textSectionContainer = [self containerWrappingStack:stack];
    return self.textSectionContainer;
}

- (UIView *)buildDisplayParamsSectionView {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;

    UILabel *sectionLabel = [self sectionLabelWithText:@"Shooting Data"];
    [stack addArrangedSubview:sectionLabel];

    UIView *row = [self formRowWithTitle:@"Display Parameters" content:^(UIStackView *container) {
        self.displayParamsSwitch = [[UISwitch alloc] init];
        self.displayParamsSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.displayParamsSwitch.onTintColor = [UIColor systemOrangeColor];
        [self.displayParamsSwitch addTarget:self
                                     action:@selector(handleDisplayParamsSwitch:)
                           forControlEvents:UIControlEventValueChanged];
        [container addArrangedSubview:self.displayParamsSwitch];
    }];
    [stack addArrangedSubview:row];
    return [self containerWrappingStack:stack];
}

- (UIView *)buildDetailEntrySectionView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    self.detailSettingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.detailSettingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailSettingsButton.layer.cornerRadius = 12.0;
    self.detailSettingsButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
    [self.detailSettingsButton setTitle:@"Frame & Watermark Library" forState:UIControlStateNormal];
    [self.detailSettingsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.detailSettingsButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [self.detailSettingsButton addTarget:self
                                  action:@selector(handleDetailSettingsTap)
                        forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.detailSettingsButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.detailSettingsButton.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.detailSettingsButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.detailSettingsButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.detailSettingsButton.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [self.detailSettingsButton.heightAnchor constraintEqualToConstant:44.0]
    ]];
    return container;
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
    label.textColor = [UIColor colorWithWhite:0.92 alpha:0.95];
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
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

- (void)setupDetailSettingsCard {
    self.detailBackdropView = [[UIView alloc] init];
    self.detailBackdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailBackdropView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    self.detailBackdropView.hidden = YES;
    self.detailBackdropView.alpha = 0.0;
    [self addSubview:self.detailBackdropView];

    UITapGestureRecognizer *backdropTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(dismissDetailSettingsCard)];
    [self.detailBackdropView addGestureRecognizer:backdropTap];

    self.detailCardView = [[UIView alloc] init];
    self.detailCardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailCardView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.98];
    self.detailCardView.layer.cornerRadius = 18.0;
    self.detailCardView.layer.masksToBounds = YES;
    self.detailCardView.hidden = YES;
    [self addSubview:self.detailCardView];

    [NSLayoutConstraint activateConstraints:@[
        [self.detailBackdropView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.detailBackdropView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.detailBackdropView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.detailBackdropView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.detailCardView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12.0],
        [self.detailCardView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        [self.detailCardView.topAnchor constraintEqualToAnchor:self.topAnchor constant:60.0],
        [self.detailCardView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-16.0]
    ]];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"FRAME & WATERMARK LIBRARY";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [self.detailCardView addSubview:title];

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [backButton setTitle:@"Back" forState:UIControlStateNormal];
    [backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [backButton addTarget:self
                   action:@selector(dismissDetailSettingsCard)
         forControlEvents:UIControlEventTouchUpInside];
    [self.detailCardView addSubview:backButton];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.detailCardView addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [backButton.leadingAnchor constraintEqualToAnchor:self.detailCardView.leadingAnchor constant:12.0],
        [backButton.topAnchor constraintEqualToAnchor:self.detailCardView.topAnchor constant:10.0],

        [title.leadingAnchor constraintEqualToAnchor:self.detailCardView.leadingAnchor constant:16.0],
        [title.topAnchor constraintEqualToAnchor:backButton.bottomAnchor constant:10.0],
        [title.trailingAnchor constraintEqualToAnchor:self.detailCardView.trailingAnchor constant:-16.0],

        [scroll.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [scroll.leadingAnchor constraintEqualToAnchor:self.detailCardView.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.detailCardView.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.detailCardView.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20.0]
    ]];

    UILabel *frameLabel = [self sectionLabelWithText:@"1. FRAME LIBRARY"];
    [stack addArrangedSubview:frameLabel];
    self.detailFrameButtonsStack = [[UIStackView alloc] init];
    self.detailFrameButtonsStack.axis = UILayoutConstraintAxisHorizontal;
    self.detailFrameButtonsStack.spacing = 8.0;
    self.detailFrameButtonsStack.distribution = UIStackViewDistributionFillEqually;
    [stack addArrangedSubview:self.detailFrameButtonsStack];

    UILabel *anchorLabel = [self sectionLabelWithText:@"2. WATERMARK PLACEMENT"];
    self.detailAnchorSectionLabel = anchorLabel;
    [stack addArrangedSubview:anchorLabel];
    self.detailAnchorControl = [[UISegmentedControl alloc] initWithItems:@[@"TL", @"TR", @"BL", @"BR", @"C", @"BC"]];
    self.detailAnchorControl.selectedSegmentTintColor = [UIColor systemOrangeColor];
    self.detailAnchorControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [self.detailAnchorControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
    [self.detailAnchorControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor]} forState:UIControlStateSelected];
    [self.detailAnchorControl addTarget:self action:@selector(handleDetailAnchorChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.detailAnchorControl];

    UILabel *fontLabel = [self sectionLabelWithText:@"3. CUSTOM TEXT FONTS"];
    self.detailFontSectionLabel = fontLabel;
    [stack addArrangedSubview:fontLabel];
    UIView *fontRow = [[UIView alloc] init];
    fontRow.translatesAutoresizingMaskIntoConstraints = NO;
    fontRow.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    fontRow.layer.cornerRadius = 10.0;
    [fontRow.heightAnchor constraintEqualToConstant:44.0].active = YES;
    self.detailFontValueLabel = [[UILabel alloc] init];
    self.detailFontValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailFontValueLabel.textColor = [UIColor whiteColor];
    self.detailFontValueLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [fontRow addSubview:self.detailFontValueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.detailFontValueLabel.leadingAnchor constraintEqualToAnchor:fontRow.leadingAnchor constant:12.0],
        [self.detailFontValueLabel.centerYAnchor constraintEqualToAnchor:fontRow.centerYAnchor]
    ]];
    self.detailFontRow = fontRow;
    [stack addArrangedSubview:fontRow];

    UILabel *metaLabel = [self sectionLabelWithText:@"4. METADATA INTEGRATION"];
    self.detailMetadataSectionLabel = metaLabel;
    [stack addArrangedSubview:metaLabel];
    UIView *apertureRow = [self detailToggleRowWithTitle:@"Aperture" switchOut:&_detailApertureSwitch action:@selector(handleDetailMetadataChanged:)];
    UIView *shutterRow = [self detailToggleRowWithTitle:@"Shutter" switchOut:&_detailShutterSwitch action:@selector(handleDetailMetadataChanged:)];
    UIView *isoRow = [self detailToggleRowWithTitle:@"ISO" switchOut:&_detailISOSwitch action:@selector(handleDetailMetadataChanged:)];
    UIView *lensRow = [self detailToggleRowWithTitle:@"Lens" switchOut:&_detailLensSwitch action:@selector(handleDetailMetadataChanged:)];
    UIView *dateRow = [self detailToggleRowWithTitle:@"Date" switchOut:&_detailDateSwitch action:@selector(handleDetailMetadataChanged:)];
    UIView *locationRow = [self detailToggleRowWithTitle:@"Location" switchOut:&_detailLocationSwitch action:@selector(handleDetailMetadataChanged:)];
    self.detailMetadataRows = @[apertureRow, shutterRow, isoRow, lensRow, dateRow, locationRow];
    [stack addArrangedSubview:apertureRow];
    [stack addArrangedSubview:shutterRow];
    [stack addArrangedSubview:isoRow];
    [stack addArrangedSubview:dateRow];
    [stack addArrangedSubview:locationRow];

    [self rebuildDetailFrameButtons];
}

- (UIView *)detailToggleRowWithTitle:(NSString *)title
                           switchOut:(UISwitch * __strong *)switchOut
                              action:(SEL)action {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row.heightAnchor constraintEqualToConstant:40.0].active = YES;
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    [row addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = [UIColor systemOrangeColor];
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:toggle];
    if (switchOut) {
        *switchOut = toggle;
    }

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    return row;
}

- (void)rebuildDetailFrameButtons {
    for (UIView *view in self.detailFrameButtonsStack.arrangedSubviews) {
        [self.detailFrameButtonsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSInteger maxButtons = MIN((NSInteger)self.frameDescriptors.count, 5);
    for (NSInteger index = 0; index < maxButtons; index++) {
        CMWatermarkFrameDescriptor *descriptor = self.frameDescriptors[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        button.layer.cornerRadius = 8.0;
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        [button setTitle:descriptor.displayName forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        [button addTarget:self action:@selector(handleDetailFrameTapped:) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintEqualToConstant:56.0].active = YES;
        [self.detailFrameButtonsStack addArrangedSubview:button];
    }
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
    return nil;
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
    [self updatePreviewAspectConstraintForImage:sourceImage];

    if (!sourceImage) {
        self.previewContainer.hidden = YES;
        self.previewMaxHeightConstraint.constant = 0.0f;
        self.previewPlaceholderLabel.hidden = NO;
        self.previewImageView.image = nil;
        [self updatePreviewLoadingState:NO];
        self.previewRenderToken = nil;
        return;
    }
    self.previewContainer.hidden = NO;

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
    if (self.internalConfiguration.textFontName.length == 0) {
        self.internalConfiguration.textFontName = @"Garamond Premier Pro";
    }
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
        if (self.controlsContainer) {
            self.controlsContainer.alpha = enabled ? 1.0 : 0.6;
        }
        if (self.scrollView) {
            self.scrollView.userInteractionEnabled = YES;
        }

    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:updates];
    } else {
        updates();
    }
    self.enableSwitch.on = enabled;
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    (void)[self applyRestrictionsForFrameDescriptor:descriptor];
    [self markPreviewNeedsRender];
}

- (void)updatePreviewWithImage:(UIImage *)image metadata:(NSDictionary *)metadata {
    self.userPreviewImage = [self preparedPreviewImageFromImage:image];
    self.userPreviewMetadata = metadata;
    [self updatePreviewAspectConstraintForImage:self.userPreviewImage];
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

    self.subtitleSwitch.on = self.internalConfiguration.isAuxiliaryTextEnabled;
    self.subtitleField.text = self.internalConfiguration.auxiliaryText;
    self.subtitleField.enabled = self.internalConfiguration.isAuxiliaryTextEnabled && enabled;

    // 署名功能已删除
    // self.signatureSwitch.on = self.internalConfiguration.isSignatureEnabled;
    // self.signatureField.text = self.internalConfiguration.signatureText;
    // self.signatureField.enabled = self.internalConfiguration.isSignatureEnabled && enabled;

    self.preferenceControl.selectedSegmentIndex = self.internalConfiguration.preference;
    self.preferenceControl.enabled = enabled && self.preferenceControl.userInteractionEnabled;
    if (self.displayParamsSwitch) {
        self.displayParamsSwitch.on = (self.internalConfiguration.metadataOptions != CMWatermarkMetadataOptionsNone);
        self.displayParamsSwitch.enabled = enabled;
    }
    
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
    [self updateDetailSettingsCardUI];

    return didMutateConfiguration;
}

- (CMWatermarkUIAvailability)availabilityForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor {
    CMWatermarkUIAvailability availability = CMWatermarkUIAvailabilityMake(YES);
    NSString *identifier = descriptor.identifier ?: CMWatermarkFrameIdentifierNone;

    if ([identifier isEqualToString:CMWatermarkFrameIdentifierNone]) {
        return availability;
    }

    if ([identifier isEqualToString:CMWatermarkFrameIdentifierPolaroid]) {
        availability.supportsAnchorPlacement = NO;
        availability.supportsCustomFont = NO;
        availability.supportsPlacement = NO;
        return availability;
    }

    if ([identifier isEqualToString:CMWatermarkFrameIdentifierInfo]) {
        availability.supportsCustomText = NO;
        availability.supportsShootingDataMasterSwitch = NO;
        availability.supportsAnchorPlacement = NO;
        availability.supportsCustomFont = NO;
        availability.supportsPlacement = NO;
        return availability;
    }

    if ([identifier isEqualToString:CMWatermarkFrameIdentifierStudio]) {
        availability.supportsLogoSelection = NO;
        availability.supportsCustomText = NO;
        availability.supportsShootingDataMasterSwitch = NO;
        availability.supportsAnchorPlacement = NO;
        availability.supportsCustomFont = NO;
        availability.supportsPlacement = NO;
        return availability;
    }

    if ([identifier isEqualToString:CMWatermarkFrameIdentifierHasuBorder]) {
        availability.supportsShootingDataMasterSwitch = NO;
        availability.supportsAnchorPlacement = NO;
        availability.supportsCustomFont = NO;
        availability.supportsPlacement = NO;
        return availability;
    }

    return availability;
}

- (void)applyEnabledState:(BOOL)enabled toView:(UIView * _Nullable)view {
    if (!view) {
        return;
    }
    view.userInteractionEnabled = enabled;
    view.alpha = enabled ? 1.0 : 0.35;
}

- (void)updateDetailSettingsCardUI {
    if (!self.detailCardView) {
        return;
    }
    self.detailFontValueLabel.text = self.internalConfiguration.textFontName.length > 0
        ? self.internalConfiguration.textFontName
        : @"Garamond Premier Pro";

    switch (self.internalConfiguration.watermarkAnchor) {
        case CMWatermarkAnchorTopLeft:
            self.detailAnchorControl.selectedSegmentIndex = 0;
            break;
        case CMWatermarkAnchorTopRight:
            self.detailAnchorControl.selectedSegmentIndex = 1;
            break;
        case CMWatermarkAnchorBottomLeft:
            self.detailAnchorControl.selectedSegmentIndex = 2;
            break;
        case CMWatermarkAnchorBottomRight:
            self.detailAnchorControl.selectedSegmentIndex = 3;
            break;
        case CMWatermarkAnchorCenter:
            self.detailAnchorControl.selectedSegmentIndex = 4;
            break;
        case CMWatermarkAnchorBottomCenter:
            self.detailAnchorControl.selectedSegmentIndex = 5;
            break;
        default:
            self.detailAnchorControl.selectedSegmentIndex = 2;
            break;
    }

    CMWatermarkMetadataOptions options = self.internalConfiguration.metadataOptions;
    self.detailApertureSwitch.on = (options & CMWatermarkMetadataOptionsAperture) != 0;
    self.detailShutterSwitch.on = (options & CMWatermarkMetadataOptionsShutter) != 0;
    self.detailISOSwitch.on = (options & CMWatermarkMetadataOptionsISO) != 0;
    self.detailLensSwitch.on = (options & CMWatermarkMetadataOptionsLens) != 0;
    self.detailDateSwitch.on = (options & CMWatermarkMetadataOptionsDate) != 0;
    self.detailLocationSwitch.on = (options & CMWatermarkMetadataOptionsLocation) != 0;

    NSString *activeFrameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    for (UIButton *button in self.detailFrameButtonsStack.arrangedSubviews) {
        if (![button isKindOfClass:[UIButton class]]) {
            continue;
        }
        NSInteger index = button.tag;
        BOOL selected = NO;
        if (index >= 0 && index < self.frameDescriptors.count) {
            CMWatermarkFrameDescriptor *descriptor = self.frameDescriptors[index];
            selected = [descriptor.identifier isEqualToString:activeFrameId];
        }
        button.backgroundColor = selected
            ? [[UIColor systemOrangeColor] colorWithAlphaComponent:0.9]
            : [UIColor colorWithWhite:1.0 alpha:0.1];
        [button setTitleColor:(selected ? [UIColor blackColor] : [UIColor whiteColor])
                     forState:UIControlStateNormal];
    }
}

- (BOOL)applyRestrictionsForFrameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)descriptor {
    BOOL configurationChanged = NO;

    BOOL panelEnabled = self.internalConfiguration.isEnabled;
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];

    BOOL allowsLogo = availability.supportsLogoSelection;
    [self applyEnabledState:(allowsLogo && panelEnabled) toView:self.logosSectionContainer];
    [self applyEnabledState:(allowsLogo && panelEnabled) toView:self.logoCollectionView];
    if (!allowsLogo) {
        BOOL needsReset = self.internalConfiguration.logoEnabled || ![self.internalConfiguration.logoIdentifier isEqualToString:CMWatermarkLogoIdentifierNone];
        if (needsReset) {
            self.internalConfiguration.logoEnabled = NO;
            self.internalConfiguration.logoIdentifier = CMWatermarkLogoIdentifierNone;
            configurationChanged = YES;
            [self.logoCollectionView reloadData];
        }
    }

    BOOL allowsParameters = availability.supportsShootingDataMasterSwitch;
    [self applyEnabledState:(allowsParameters && panelEnabled) toView:self.displayParamsSectionContainer];
    [self applyEnabledState:(allowsParameters && panelEnabled) toView:self.displayParamsSwitch];
    [self applyEnabledState:(allowsParameters && panelEnabled) toView:self.preferencesSectionContainer];
    [self applyEnabledState:(allowsParameters && panelEnabled) toView:self.preferenceRow];
    if (self.preferenceControl) {
        self.preferenceControl.userInteractionEnabled = allowsParameters && panelEnabled;
        self.preferenceControl.enabled = allowsParameters && panelEnabled;
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
    
    BOOL allowsPlacement = availability.supportsPlacement;
    [self applyEnabledState:(allowsPlacement && panelEnabled) toView:self.placementSectionContainer];
    [self applyEnabledState:(allowsPlacement && panelEnabled) toView:self.placementRow];
    if (self.placementControl) {
        self.placementControl.userInteractionEnabled = allowsPlacement && panelEnabled;
        self.placementControl.enabled = allowsPlacement && panelEnabled;
    }

    BOOL allowsCustomText = availability.supportsCustomText;
    [self applyEnabledState:(allowsCustomText && panelEnabled) toView:self.textSectionContainer];
    [self applyEnabledState:(allowsCustomText && panelEnabled) toView:self.textRowContainer];
    [self applyEnabledState:(allowsCustomText && panelEnabled) toView:self.subtitleRowContainer];
    [self applyEnabledState:(allowsCustomText && panelEnabled) toView:self.textPresetHintLabel];
    if (self.captionSwitch) {
        self.captionSwitch.enabled = allowsCustomText && panelEnabled;
        self.captionSwitch.userInteractionEnabled = allowsCustomText && panelEnabled;
    }
    if (self.captionField) {
        BOOL textFieldEnabled = allowsCustomText && panelEnabled && self.internalConfiguration.isCaptionEnabled;
        self.captionField.enabled = textFieldEnabled;
        self.captionField.userInteractionEnabled = textFieldEnabled;
    }
    if (self.subtitleSwitch) {
        self.subtitleSwitch.enabled = allowsCustomText && panelEnabled;
        self.subtitleSwitch.userInteractionEnabled = allowsCustomText && panelEnabled;
    }
    if (self.subtitleField) {
        BOOL subtitleFieldEnabled = allowsCustomText && panelEnabled && self.internalConfiguration.isAuxiliaryTextEnabled;
        self.subtitleField.enabled = subtitleFieldEnabled;
        self.subtitleField.userInteractionEnabled = subtitleFieldEnabled;
    }

    BOOL allowsDetailAnchor = availability.supportsAnchorPlacement;
    [self applyEnabledState:(allowsDetailAnchor && panelEnabled) toView:self.detailAnchorSectionLabel];
    [self applyEnabledState:(allowsDetailAnchor && panelEnabled) toView:self.detailAnchorControl];
    self.detailAnchorControl.enabled = allowsDetailAnchor && panelEnabled;

    BOOL allowsDetailFont = availability.supportsCustomFont;
    [self applyEnabledState:(allowsDetailFont && panelEnabled) toView:self.detailFontSectionLabel];
    [self applyEnabledState:(allowsDetailFont && panelEnabled) toView:self.detailFontRow];

    BOOL allowsDetailMetadata = availability.supportsDetailMetadata;
    [self applyEnabledState:(allowsDetailMetadata && panelEnabled) toView:self.detailMetadataSectionLabel];
    for (UIView *row in self.detailMetadataRows) {
        [self applyEnabledState:(allowsDetailMetadata && panelEnabled) toView:row];
    }
    self.detailApertureSwitch.enabled = allowsDetailMetadata && panelEnabled;
    self.detailShutterSwitch.enabled = allowsDetailMetadata && panelEnabled;
    self.detailISOSwitch.enabled = allowsDetailMetadata && panelEnabled;
    self.detailLensSwitch.enabled = allowsDetailMetadata && panelEnabled;
    self.detailDateSwitch.enabled = allowsDetailMetadata && panelEnabled;
    self.detailLocationSwitch.enabled = allowsDetailMetadata && panelEnabled;

    [self setNeedsLayout];

    return configurationChanged;
}

#pragma mark - Actions

- (void)handleDismissTap {
    [self dismissDetailSettingsCard];
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

- (void)handleDisplayParamsSwitch:(UISwitch *)sender {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsShootingDataMasterSwitch)) {
        sender.on = (self.internalConfiguration.metadataOptions != CMWatermarkMetadataOptionsNone);
        return;
    }

    if (sender.isOn) {
        if (self.internalConfiguration.metadataOptions == CMWatermarkMetadataOptionsNone) {
            self.internalConfiguration.metadataOptions =
                (CMWatermarkMetadataOptionsAperture |
                 CMWatermarkMetadataOptionsShutter |
                 CMWatermarkMetadataOptionsISO);
        }
    } else {
        self.internalConfiguration.metadataOptions = CMWatermarkMetadataOptionsNone;
    }
    [self notifyUpdate];
}

- (void)handleDetailSettingsTap {
    [self updateDetailSettingsCardUI];
    self.detailBackdropView.hidden = NO;
    self.detailCardView.hidden = NO;
    self.detailBackdropView.alpha = 0.0;
    self.detailCardView.alpha = 0.0;
    self.detailCardView.transform = CGAffineTransformMakeTranslation(0.0, 24.0);
    [UIView animateWithDuration:0.22 animations:^{
        self.detailBackdropView.alpha = 1.0;
        self.detailCardView.alpha = 1.0;
        self.detailCardView.transform = CGAffineTransformIdentity;
    }];
    if ([self.delegate respondsToSelector:@selector(watermarkPanel:didChangeDetailVisibility:)]) {
        [self.delegate watermarkPanel:self didChangeDetailVisibility:YES];
    }
}

- (void)dismissDetailSettingsCard {
    if (self.detailCardView.hidden) {
        return;
    }
    [UIView animateWithDuration:0.18 animations:^{
        self.detailBackdropView.alpha = 0.0;
        self.detailCardView.alpha = 0.0;
        self.detailCardView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
    } completion:^(BOOL finished) {
        self.detailBackdropView.hidden = YES;
        self.detailCardView.hidden = YES;
        self.detailCardView.transform = CGAffineTransformIdentity;
    }];
    if ([self.delegate respondsToSelector:@selector(watermarkPanel:didChangeDetailVisibility:)]) {
        [self.delegate watermarkPanel:self didChangeDetailVisibility:NO];
    }
}

- (void)handleDetailAnchorChanged:(UISegmentedControl *)sender {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsAnchorPlacement)) {
        [self updateDetailSettingsCardUI];
        return;
    }

    switch (sender.selectedSegmentIndex) {
        case 0:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorTopLeft;
            break;
        case 1:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorTopRight;
            break;
        case 2:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorBottomLeft;
            break;
        case 3:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorBottomRight;
            break;
        case 4:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorCenter;
            break;
        case 5:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorBottomCenter;
            break;
        default:
            self.internalConfiguration.watermarkAnchor = CMWatermarkAnchorBottomLeft;
            break;
    }
    [self notifyUpdate];
}

- (void)handleDetailMetadataChanged:(UISwitch *)sender {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsDetailMetadata)) {
        [self updateDetailSettingsCardUI];
        return;
    }

    CMWatermarkMetadataOptions options = CMWatermarkMetadataOptionsNone;
    if (self.detailApertureSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsAperture;
    }
    if (self.detailShutterSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsShutter;
    }
    if (self.detailISOSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsISO;
    }
    if (self.detailLensSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsLens;
    }
    if (self.detailDateSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsDate;
    }
    if (self.detailLocationSwitch.isOn) {
        options |= CMWatermarkMetadataOptionsLocation;
    }
    self.internalConfiguration.metadataOptions = options;
    [self notifyUpdate];
}

- (void)handleDetailFrameTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= self.frameDescriptors.count) {
        return;
    }
    CMWatermarkFrameDescriptor *descriptor = self.frameDescriptors[index];
    self.internalConfiguration.frameIdentifier = descriptor.identifier;
    [self applyDefaultSettingsIfNeededForFrameIdentifier:descriptor.identifier];
    [self updateUIFromConfigurationAnimated:YES];
    [self notifyUpdate];
}

- (void)handleCaptionSwitch:(UISwitch *)sender {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsCustomText)) {
        sender.on = self.internalConfiguration.isCaptionEnabled;
        return;
    }

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
    
    if (self.internalConfiguration.preference == CMWatermarkPreferenceOff) {
        self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsNone;
    }
    
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
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsPlacement)) {
        self.placementControl.selectedSegmentIndex = self.internalConfiguration.placement;
        return;
    }

    self.internalConfiguration.placement = (CMWatermarkPlacement)sender.selectedSegmentIndex;
    [self notifyUpdate];
}

- (void)handleCaptionEditingChanged:(UITextField *)textField {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsCustomText)) {
        textField.text = self.internalConfiguration.captionText ?: @"";
        return;
    }

    self.internalConfiguration.captionText = textField.text ?: @"";
    [self notifyUpdate];
}

- (void)handleSubtitleSwitch:(UISwitch *)sender {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsCustomText)) {
        sender.on = self.internalConfiguration.isAuxiliaryTextEnabled;
        return;
    }

    self.internalConfiguration.auxiliaryTextEnabled = sender.isOn;
    self.subtitleField.enabled = sender.isOn && self.internalConfiguration.isEnabled;
    [self notifyUpdate];
}

- (void)handleSubtitleEditingChanged:(UITextField *)textField {
    NSString *frameId = self.internalConfiguration.frameIdentifier ?: CMWatermarkFrameIdentifierNone;
    CMWatermarkFrameDescriptor *descriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:frameId];
    CMWatermarkUIAvailability availability = [self availabilityForFrameDescriptor:descriptor];
    if (!(self.internalConfiguration.isEnabled && availability.supportsCustomText)) {
        textField.text = self.internalConfiguration.auxiliaryText ?: @"";
        return;
    }

    self.internalConfiguration.auxiliaryText = textField.text ?: @"";
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

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.activeTextField = textField;
    [self ensureActiveFieldVisibleAnimated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (self.activeTextField == textField) {
        self.activeTextField = nil;
    }
}

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
        [self applyDefaultSettingsIfNeededForFrameIdentifier:descriptor.identifier];
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
        return CGSizeMake(74.0, 84.0);
    }
    return CGSizeMake(74.0, 62.0);
}

#pragma mark - Helpers

- (void)applyDefaultSettingsIfNeededForFrameIdentifier:(NSString *)frameIdentifier {
    if (![frameIdentifier isEqualToString:CMWatermarkFrameIdentifierHasuBorder]) {
        return;
    }
    if (!self.internalConfiguration.logoEnabled ||
        [self.internalConfiguration.logoIdentifier isEqualToString:CMWatermarkLogoIdentifierNone]) {
        self.internalConfiguration.logoEnabled = YES;
        self.internalConfiguration.logoIdentifier = @"logo.hasu.black";
    }
    if (self.internalConfiguration.captionText.length == 0 ||
        [self.internalConfiguration.captionText isEqualToString:@"Mr.C | PHOTOGRAPHY 2025"] ||
        [self.internalConfiguration.captionText isEqualToString:@"Mr.C | PHOTOGRAPHY 2026"]) {
        self.internalConfiguration.captionText = @"Hasselblad CFV2";
    }
    if (self.internalConfiguration.auxiliaryText.length == 0) {
        self.internalConfiguration.auxiliaryText = @"XCD 3,5 / 120 MACRO";
    }
    self.internalConfiguration.captionEnabled = YES;
    self.internalConfiguration.metadataOptions = CMWatermarkMetadataOptionsNone;
    self.internalConfiguration.preference = CMWatermarkPreferenceOff;
    self.internalConfiguration.preferenceOptions = CMWatermarkPreferenceOptionsNone;
}

- (void)registerForKeyboardNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(handleKeyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(handleKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification {
    if (!self.scrollView || !self.window) {
        return;
    }

    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardScreenFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIWindow *window = self.window;
    CGRect keyboardInWindow = [window convertRect:keyboardScreenFrame fromWindow:nil];
    CGRect keyboardInSelf = [self convertRect:keyboardInWindow fromView:window];
    CGRect intersection = CGRectIntersection(self.bounds, keyboardInSelf);
    CGFloat overlap = CGRectIsNull(intersection) ? 0.0f : CGRectGetHeight(intersection);
    CGFloat adjustedOverlap = MAX(0.0f, overlap - self.safeAreaInsets.bottom);

    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    NSUInteger curveRaw = [userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    UIViewAnimationOptions options = (UIViewAnimationOptions)curveRaw | UIViewAnimationOptionBeginFromCurrentState;

    [self applyKeyboardBottomInset:adjustedOverlap duration:duration options:options ensureVisibility:YES];
}

- (void)handleKeyboardWillHide:(NSNotification *)notification {
    if (!self.scrollView) {
        return;
    }

    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    NSUInteger curveRaw = [userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    UIViewAnimationOptions options = (UIViewAnimationOptions)curveRaw | UIViewAnimationOptionBeginFromCurrentState;

    [self applyKeyboardBottomInset:0.0f duration:duration options:options ensureVisibility:NO];
}

- (void)applyKeyboardBottomInset:(CGFloat)bottomInset
                        duration:(NSTimeInterval)duration
                         options:(UIViewAnimationOptions)options
               ensureVisibility:(BOOL)ensureVisibility {
    // Keep the editing field above the keyboard by mirroring UIKit's keyboard animation.
    UIEdgeInsets contentInset = self.scrollViewBaseContentInset;
    contentInset.bottom += bottomInset;

    UIEdgeInsets indicatorInset = self.scrollViewBaseIndicatorInsets;
    indicatorInset.bottom += bottomInset;

    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                         self.scrollView.scrollIndicatorInsets = indicatorInset;
                         if (ensureVisibility) {
                             [self ensureActiveFieldVisibleAnimated:NO];
                         }
                     }
                     completion:nil];
}

- (void)ensureActiveFieldVisibleAnimated:(BOOL)animated {
    if (!self.activeTextField || !self.scrollView) {
        return;
    }

    CGRect fieldRect = [self.activeTextField convertRect:self.activeTextField.bounds toView:self.scrollView];
    fieldRect = CGRectInset(fieldRect, 0.0, -12.0);
    [self.scrollView scrollRectToVisible:fieldRect animated:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)notifyUpdate {
    [self markPreviewNeedsRender];
    if ([self.delegate respondsToSelector:@selector(watermarkPanel:didUpdateConfiguration:)]) {
        [self.delegate watermarkPanel:self didUpdateConfiguration:[self configuration]];
    }
}

- (void)dismissDetailSettingsIfNeeded {
    [self dismissDetailSettingsCard];
}

- (BOOL)isDetailSettingsVisible {
    return !self.detailCardView.hidden;
}

@end
