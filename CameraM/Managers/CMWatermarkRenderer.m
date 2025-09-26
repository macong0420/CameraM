//
//  CMWatermarkRenderer.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "CMWatermarkRenderer.h"
#import "CMWatermarkConfiguration.h"
#import "CMWatermarkCatalog.h"
#import <ImageIO/ImageIO.h>
#import <sys/utsname.h>
#import <math.h>

static const CGFloat CMWatermarkUIScaleFactor = 1.5f;

@interface CMWatermarkRenderer ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation CMWatermarkRenderer

- (instancetype)init {
    self = [super init];
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
        _dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.timeZone = [NSTimeZone localTimeZone];
    }
    return self;
}

- (UIImage *)renderImage:(UIImage *)image
     withConfiguration:(CMWatermarkConfiguration *)configuration
              metadata:(NSDictionary *)metadata {
    if (!configuration.isEnabled) {
        return image;
    }
    if (!image) {
        return nil;
    }
    @autoreleasepool {
        CMWatermarkFrameDescriptor *frameDescriptor = [CMWatermarkCatalog frameDescriptorForIdentifier:configuration.frameIdentifier ?: CMWatermarkFrameIdentifierNone];
        CMWatermarkConfiguration *effectiveConfiguration = [configuration copy];
        if (frameDescriptor) {
            if (!frameDescriptor.allowsLogoEditing) {
                effectiveConfiguration.logoEnabled = NO;
                effectiveConfiguration.logoIdentifier = CMWatermarkLogoIdentifierNone;
            }
            if (!frameDescriptor.allowsSignatureEditing) {
                effectiveConfiguration.signatureEnabled = NO;
                effectiveConfiguration.signatureText = @"";
            }
            // 对于Info相框，始终应用强制的preference设置以确保参数显示
            if (frameDescriptor.enforcedPreferenceRawValue != NSNotFound) {
                effectiveConfiguration.preference = (CMWatermarkPreference)frameDescriptor.enforcedPreferenceRawValue;
            }
        }

        CMWatermarkLogoDescriptor *logoDescriptor = nil;
        if (effectiveConfiguration.logoEnabled) {
            logoDescriptor = [CMWatermarkCatalog logoDescriptorForIdentifier:effectiveConfiguration.logoIdentifier ?: CMWatermarkLogoIdentifierNone];
        }
        const CGFloat baseWidth = image.size.width;
        const CGFloat baseHeight = image.size.height;
        const CGFloat baseShortSide = MIN(baseWidth, baseHeight);
        const CGFloat bottomPadding = MAX(0.0, frameDescriptor.bottomExpansionRatio * baseShortSide);
        const CGSize canvasSize = CGSizeMake(baseWidth, baseHeight + bottomPadding);
        
        NSLog(@"📏 相框渲染 - 模式: %@, 原始图像: %.0fx%.0f, 画布: %.0fx%.0f", 
              frameDescriptor.identifier ?: @"none", baseWidth, baseHeight, canvasSize.width, canvasSize.height);

        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.scale = image.scale > 0 ? image.scale : [UIScreen mainScreen].scale;
        format.opaque = YES;
        format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;

        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize format:format];
        UIImage *composited = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
            CGContextRef ctx = context.CGContext;
            CGContextSaveGState(ctx);
            
            // 对于Studio模式、Polaroid模式和Info模式，使用白色背景，否则使用黑色
            if ([frameDescriptor.identifier isEqualToString:@"frame.studio"] || 
                [frameDescriptor.identifier isEqualToString:@"frame.polaroid"] ||
                [frameDescriptor.identifier isEqualToString:@"frame.info"]) {
                CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
            } else {
                CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
            }
            CGContextFillRect(ctx, CGRectMake(0, 0, canvasSize.width, canvasSize.height));
            CGContextRestoreGState(ctx);

            UIImage *overlay = nil;
            void (^drawOverlay)(CGRect photoMaskRect, BOOL usesMask) = nil;
            BOOL overlayShouldDrawAbovePhoto = YES;
            if (frameDescriptor.overlayAssetName.length > 0) {
                overlay = [UIImage imageNamed:frameDescriptor.overlayAssetName];
                if (overlay) {
                    overlayShouldDrawAbovePhoto = frameDescriptor.overlayDrawsAbovePhoto;
                    drawOverlay = ^(CGRect photoMaskRect, BOOL usesMask) {
                        CGFloat overlayHeight = baseHeight + bottomPadding;
                        CGRect overlayRect = CGRectMake(0.0, 0.0, canvasSize.width, overlayHeight);
                        if (frameDescriptor.overlayInsetsRatio > 0.0) {
                            CGFloat insetX = frameDescriptor.overlayInsetsRatio * canvasSize.width;
                            CGFloat insetY = frameDescriptor.overlayInsetsRatio * overlayHeight;
                            overlayRect = CGRectInset(overlayRect, insetX, insetY);
                        }
                        if (usesMask && !CGRectIsEmpty(photoMaskRect)) {
                            UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:overlayRect];
                            CGFloat radius = frameDescriptor.photoCornerRadiusRatio * MIN(canvasSize.width, canvasSize.height);
                            UIBezierPath *holePath = radius > 0.0 ? [UIBezierPath bezierPathWithRoundedRect:photoMaskRect cornerRadius:radius] : [UIBezierPath bezierPathWithRect:photoMaskRect];
                            [clipPath appendPath:holePath];
                            clipPath.usesEvenOddFillRule = YES;

                            CGContextSaveGState(ctx);
                            CGContextAddPath(ctx, clipPath.CGPath);
                            CGContextEOClip(ctx);
                            [overlay drawInRect:overlayRect blendMode:kCGBlendModeNormal alpha:1.0];
                            CGContextRestoreGState(ctx);
                        } else {
                            [overlay drawInRect:overlayRect blendMode:kCGBlendModeNormal alpha:1.0];
                        }
                    };
                } else {
                    overlayShouldDrawAbovePhoto = YES;
                }
            }

            UIEdgeInsets scaledContentInsets = UIEdgeInsetsZero;
            if (frameDescriptor) {
                scaledContentInsets.top = frameDescriptor.contentInsetsRatio.top * canvasSize.height;
                scaledContentInsets.bottom = frameDescriptor.contentInsetsRatio.bottom * canvasSize.height;
                scaledContentInsets.left = frameDescriptor.contentInsetsRatio.left * canvasSize.width;
                scaledContentInsets.right = frameDescriptor.contentInsetsRatio.right * canvasSize.width;
                // 确保底部预留空间至少等于扩展高度，避免照片覆盖文字区域
                scaledContentInsets.bottom = MAX(scaledContentInsets.bottom, bottomPadding);
            } else if (bottomPadding > 0.0) {
                scaledContentInsets.bottom = bottomPadding;
            }

            CGRect contentRect = UIEdgeInsetsInsetRect((CGRect){CGPointZero, canvasSize}, scaledContentInsets);
            if (CGRectIsEmpty(contentRect)) {
                contentRect = CGRectMake(0, 0, baseWidth, baseHeight);
            }

            BOOL hasCustomPhotoMask = frameDescriptor.photoContentScale.width > 0.0 && frameDescriptor.photoContentScale.height > 0.0;
            CGRect photoMaskRect = CGRectZero;
            if (hasCustomPhotoMask) {
                photoMaskRect = CGRectMake(frameDescriptor.photoContentOffset.x * canvasSize.width,
                                           frameDescriptor.photoContentOffset.y * canvasSize.height,
                                           frameDescriptor.photoContentScale.width * canvasSize.width,
                                           frameDescriptor.photoContentScale.height * canvasSize.height);
                if (!CGRectIsEmpty(photoMaskRect)) {
                    contentRect = photoMaskRect;
                }
            }

            if (drawOverlay && !overlayShouldDrawAbovePhoto) {
                drawOverlay(photoMaskRect, hasCustomPhotoMask);
            }

            CGRect photoRect = [self aspectFillRectForImageSize:image.size inBoundingRect:contentRect];
            CGContextSaveGState(ctx);
            CGContextAddRect(ctx, contentRect);
            CGContextClip(ctx);
            [image drawInRect:photoRect];
            CGContextRestoreGState(ctx);

            // Studio模式使用白色背景
            if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"] && bottomPadding > 0.0) {
                CGRect whiteBackgroundRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                [[UIColor whiteColor] setFill];
                UIRectFillUsingBlendMode(whiteBackgroundRect, kCGBlendModeNormal);

            } else if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.polaroid"] && bottomPadding > 0.0) {
                // Polaroid模式使用白色背景
                CGRect whiteBackgroundRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                [[UIColor whiteColor] setFill];
                UIRectFillUsingBlendMode(whiteBackgroundRect, kCGBlendModeNormal);

            } else if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.info"] && bottomPadding > 0.0) {
                // Info模式使用白色背景
                CGRect whiteBackgroundRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                [[UIColor whiteColor] setFill];
                UIRectFillUsingBlendMode(whiteBackgroundRect, kCGBlendModeNormal);

            } else if (frameDescriptor.backgroundAssetName.length > 0 && bottomPadding > 0.0) {
                // 其他相框模式的原有逻辑
                UIImage *background = [UIImage imageNamed:frameDescriptor.backgroundAssetName];
                if (background) {
                    CGRect backgroundRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                    [background drawInRect:backgroundRect blendMode:kCGBlendModeNormal alpha:1.0];
                } else {
                    CGRect fallbackRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                    [[UIColor colorWithWhite:0.08 alpha:0.75] setFill];
                    UIRectFillUsingBlendMode(fallbackRect, kCGBlendModeNormal);
                }
            } else if (bottomPadding > 0.0) {
                CGRect fallbackRect = CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
                [[UIColor colorWithWhite:0.05 alpha:0.75] setFill];
                UIRectFillUsingBlendMode(fallbackRect, kCGBlendModeNormal);
            }

            if (drawOverlay && overlayShouldDrawAbovePhoto) {
                drawOverlay(photoMaskRect, hasCustomPhotoMask);
            }

            CGRect footerOverrideRect = CGRectNull;
            if (frameDescriptor && !CGRectIsEmpty(frameDescriptor.footerContentRect)) {
                CGRect normalized = frameDescriptor.footerContentRect;
                footerOverrideRect = CGRectMake(normalized.origin.x * canvasSize.width,
                                                normalized.origin.y * canvasSize.height,
                                                normalized.size.width * canvasSize.width,
                                                normalized.size.height * canvasSize.height);
            }

            [self drawWatermarkContentInContext:context
                                        canvasSize:canvasSize
                                        imageHeight:baseHeight
                                      bottomPadding:bottomPadding
                                   footerOverrideRect:footerOverrideRect
                                   configuration:effectiveConfiguration
                                    logoDescriptor:logoDescriptor
                                  frameDescriptor:frameDescriptor
                                         metadata:metadata];
        }];
        return composited;
    }
}

- (void)drawWatermarkContentInContext:(UIGraphicsImageRendererContext *)context
                             canvasSize:(CGSize)canvasSize
                             imageHeight:(CGFloat)imageHeight
                           bottomPadding:(CGFloat)bottomPadding
                    footerOverrideRect:(CGRect)footerOverrideRect
                          configuration:(CMWatermarkConfiguration *)configuration
                           logoDescriptor:(CMWatermarkLogoDescriptor * _Nullable)logoDescriptor
                          frameDescriptor:(CMWatermarkFrameDescriptor * _Nullable)frameDescriptor
                                metadata:(NSDictionary * _Nullable)metadata {
    NSString *detailString = [self supplementaryStringForConfiguration:configuration metadata:metadata];
    BOOL shouldRenderInline = (!frameDescriptor || [frameDescriptor.identifier isEqualToString:CMWatermarkFrameIdentifierNone]);

    if (shouldRenderInline) {
        [self drawInlineWatermarkOnPhotoInContext:context
                                        canvasSize:canvasSize
                                     configuration:configuration
                                      logoDescriptor:logoDescriptor
                                       detailString:detailString];
        return;
    }

    const CGFloat horizontalPadding = MAX(24.0, canvasSize.width * 0.04);
    const CGFloat footerHeight = bottomPadding > 0.0 ? bottomPadding : MAX(120.0, canvasSize.height * 0.12);
    CGRect defaultFooterRect = CGRectMake(0.0, imageHeight, canvasSize.width, footerHeight);

    CGRect contentRect;
    if (!CGRectIsEmpty(footerOverrideRect)) {
        contentRect = footerOverrideRect;
    } else if (configuration.placement == CMWatermarkPlacementMiddle) {
        CGFloat contentHeight = MIN(footerHeight, imageHeight * 0.28);
        CGFloat originY = MAX(0.0, (imageHeight - contentHeight) / 2.0);
        contentRect = CGRectMake(0.0, originY, canvasSize.width, contentHeight);
        [[UIColor colorWithWhite:0.02 alpha:0.55] setFill];
        UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(contentRect, horizontalPadding * 0.5, contentRect.size.height * 0.1)
                                                            cornerRadius:contentRect.size.height * 0.25];
        [rounded fill];
    } else {
        contentRect = defaultFooterRect;
    }

    CGFloat cursorX = contentRect.origin.x + horizontalPadding;
    CGFloat contentCenterY = CGRectGetMidY(contentRect);

    // Studio模式、Polaroid模式和Info模式不在此处显示logo
    if (logoDescriptor && logoDescriptor.assetName.length > 0 && 
        !(frameDescriptor && ([frameDescriptor.identifier isEqualToString:@"frame.studio"] || 
                             [frameDescriptor.identifier isEqualToString:@"frame.polaroid"] ||
                             [frameDescriptor.identifier isEqualToString:@"frame.info"]))) {
        UIImage *logoImage = [UIImage imageNamed:logoDescriptor.assetName];
        if (logoImage) {
            CGFloat maxLogoHeight = MIN(contentRect.size.height * 0.6, 140.0) * CMWatermarkUIScaleFactor;
            maxLogoHeight = MIN(maxLogoHeight, contentRect.size.height);
            CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
            CGFloat logoHeight = maxLogoHeight;
            CGFloat logoWidth = logoHeight * aspect;
            CGRect logoRect = CGRectMake(cursorX, contentCenterY - logoHeight / 2.0, logoWidth, logoHeight);
            UIImage *renderableLogo = logoDescriptor.prefersTemplateRendering ? [logoImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : logoImage;
            if (logoDescriptor.prefersTemplateRendering) {
                [[UIColor whiteColor] setFill];
                [[UIColor whiteColor] setStroke];
            }
            [renderableLogo drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.95];
            cursorX = CGRectGetMaxX(logoRect) + horizontalPadding * 0.6;
        }
    }

    CGFloat availableWidth = CGRectGetMaxX(contentRect) - horizontalPadding - cursorX;
    if (availableWidth <= 0) {
        return;
    }

    CGFloat baseFontSize = MAX(18.0, MIN(42.0, canvasSize.width * 0.035)) * CMWatermarkUIScaleFactor;
    UIFont *captionFont = [UIFont systemFontOfSize:baseFontSize weight:UIFontWeightSemibold];
    NSMutableParagraphStyle *captionParagraph = [[NSMutableParagraphStyle alloc] init];
    captionParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

    // 根据相框类型选择文本颜色
    UIColor *textColor = [UIColor whiteColor];
    if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
        textColor = [UIColor blackColor]; // Studio模式使用黑色文字
    }

    NSDictionary *captionAttributes = @{
        NSFontAttributeName: captionFont,
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: captionParagraph
    };

    // Studio模式和Polaroid模式不在此处显示caption文字
    NSString *captionText = @"";
    CGRect captionRect = CGRectZero;
    if (frameDescriptor && ![frameDescriptor.identifier isEqualToString:@"frame.studio"] && 
        ![frameDescriptor.identifier isEqualToString:@"frame.polaroid"]) {
        captionText = (configuration.isCaptionEnabled && configuration.captionText.length) ? configuration.captionText : @"";
        captionRect = CGRectMake(cursorX, contentCenterY - captionFont.lineHeight * 0.6, availableWidth, captionFont.lineHeight);
        if (captionText.length > 0) {
            [captionText drawInRect:captionRect withAttributes:captionAttributes];
        }
    }

    // 宝丽来模式始终显示布局，不依赖detailString
    if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.polaroid"]) {
        // Polaroid模式使用3行布局：logo, 文字, 参数
        [self drawPolaroidLayoutInRect:contentRect
                        configuration:configuration
                         logoDescriptor:logoDescriptor
                           detailString:detailString ?: @""
                             canvasSize:canvasSize
                    horizontalPadding:horizontalPadding];
    } else if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.info"]) {
        // Info模式使用专门的布局：设备机型、时间、logo、参数、GPS坐标
        [self drawInfoLayoutInRect:contentRect
                     configuration:configuration
                      logoDescriptor:logoDescriptor
                        detailString:detailString ?: @""
                          canvasSize:canvasSize
                   horizontalPadding:horizontalPadding
                            metadata:metadata];
    } else if (detailString.length > 0) {
        // 对于Studio模式，使用Info样式布局
        if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
            [self drawInfoLayoutInRect:contentRect
                       configuration:configuration
                        logoDescriptor:logoDescriptor
                          detailString:detailString ?: @""
                            canvasSize:canvasSize
                     horizontalPadding:horizontalPadding
                              metadata:metadata];
        } else {
            // 其他相框模式使用原有样式
            UIFont *detailFont = [UIFont systemFontOfSize:baseFontSize * 0.55 weight:UIFontWeightMedium];
            NSMutableParagraphStyle *detailParagraph = [[NSMutableParagraphStyle alloc] init];
            detailParagraph.lineBreakMode = NSLineBreakByTruncatingTail;
            UIColor *detailTextColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
            
            NSDictionary *detailAttributes = @{
                NSFontAttributeName: detailFont,
                NSForegroundColorAttributeName: detailTextColor,
                NSParagraphStyleAttributeName: detailParagraph
            };
            CGFloat detailBaselineY = captionText.length > 0 ? CGRectGetMaxY(captionRect) + (6.0 * CMWatermarkUIScaleFactor) : (contentCenterY - detailFont.lineHeight * 0.5);
            CGRect detailRect = CGRectMake(cursorX, detailBaselineY, availableWidth, detailFont.lineHeight);
            [detailString drawInRect:detailRect withAttributes:detailAttributes];
        }
    }

    // 署名功能已完全删除
    // if (configuration.isSignatureEnabled && configuration.signatureText.length > 0 &&
    //     !(frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"])) {
    //     UIFont *signatureFont = [UIFont italicSystemFontOfSize:baseFontSize * 0.6];
    //     UIColor *signatureColor = [UIColor whiteColor];
    //     if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
    //         signatureColor = [UIColor blackColor];
    //     }
    //     NSDictionary *signatureAttributes = @{
    //         NSFontAttributeName: signatureFont,
    //         NSForegroundColorAttributeName: [signatureColor colorWithAlphaComponent:0.9]
    //     };
    //     CGSize signatureSize = [configuration.signatureText sizeWithAttributes:signatureAttributes];
    //     CGFloat signatureX = CGRectGetMaxX(contentRect) - horizontalPadding - signatureSize.width;
    //     CGFloat signatureY = contentCenterY - signatureSize.height / 2.0;
    //     CGRect signatureRect = CGRectMake(MAX(signatureX, cursorX + 20.0), signatureY, signatureSize.width, signatureSize.height);
    //     [configuration.signatureText drawInRect:signatureRect withAttributes:signatureAttributes];
    // }
}

- (void)drawInlineWatermarkOnPhotoInContext:(UIGraphicsImageRendererContext *)context
                                 canvasSize:(CGSize)canvasSize
                               configuration:(CMWatermarkConfiguration *)configuration
                                logoDescriptor:(CMWatermarkLogoDescriptor * _Nullable)logoDescriptor
                                 detailString:(NSString *)detailString {
    BOOL hasCaption = configuration.isCaptionEnabled && configuration.captionText.length > 0;
    BOOL hasDetail = detailString.length > 0;
    BOOL hasLogoAsset = (configuration.logoEnabled && logoDescriptor && logoDescriptor.assetName.length > 0);

    if (!hasCaption && !hasDetail && !hasLogoAsset) {
        return;
    }

    const CGFloat horizontalMargin = MAX(canvasSize.width * 0.05f, 40.0f);
    const CGFloat bottomInset = MAX(canvasSize.height * 0.06f, 80.0f);
    CGFloat baseFontSize = MAX(22.0f, MIN(52.0f, canvasSize.width * 0.045f)) * CMWatermarkUIScaleFactor;
    UIFont *captionFont = [UIFont systemFontOfSize:baseFontSize weight:UIFontWeightSemibold];
    UIFont *detailFont = [UIFont systemFontOfSize:baseFontSize * 0.58f weight:UIFontWeightMedium];
    const CGFloat lineSpacing = baseFontSize * 0.35f;

    NSMutableParagraphStyle *centerParagraph = [[NSMutableParagraphStyle alloc] init];
    centerParagraph.alignment = NSTextAlignmentCenter;
    centerParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

    CGFloat rendererScale = 1.0f;
    if ([context.format isKindOfClass:[UIGraphicsImageRendererFormat class]]) {
        rendererScale = MAX(((UIGraphicsImageRendererFormat *)context.format).scale, 1.0f);
    } else {
        rendererScale = MAX([UIScreen mainScreen].scale, 1.0f);
    }

    const CGFloat strokeWidth = -1.0f / rendererScale;
    UIColor *strokeColor = [UIColor colorWithWhite:0.0f alpha:0.35f];

    NSDictionary *(^attributesForFont)(UIFont *) = ^NSDictionary *(UIFont *font) {
        return @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSStrokeColorAttributeName: strokeColor,
            NSStrokeWidthAttributeName: @(strokeWidth),
            NSParagraphStyleAttributeName: centerParagraph
        };
    };

    NSMutableArray<NSDictionary<NSString *, id> *> *lines = [NSMutableArray array];
    if (hasCaption) {
        [lines addObject:@{ @"text": configuration.captionText, @"font": captionFont }];
    }
    if (hasDetail) {
        [lines addObject:@{ @"text": detailString, @"font": detailFont }];
    }

    UIImage *logoImage = nil;
    CGFloat logoHeight = 0.0f;
    CGFloat logoWidth = 0.0f;
    if (hasLogoAsset) {
        logoImage = [UIImage imageNamed:logoDescriptor.assetName];
        if (!logoImage) {
            hasLogoAsset = NO;
        } else {
            CGFloat maxLogoHeight = captionFont.lineHeight * 1.2f * CMWatermarkUIScaleFactor;
            maxLogoHeight = MIN(maxLogoHeight, canvasSize.height * 0.3f);
            CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
            logoHeight = maxLogoHeight;
            logoWidth = logoHeight * aspect;
            CGFloat maxContentWidth = canvasSize.width - horizontalMargin * 2.0f;
            if (logoWidth > maxContentWidth && maxContentWidth > 0.0f) {
                logoWidth = maxContentWidth;
                logoHeight = logoWidth / MAX(aspect, 0.1f);
            }
        }
    }

    CGFloat blockHeight = 0.0f;
    if (hasLogoAsset) {
        blockHeight += logoHeight;
        if (lines.count > 0) {
            blockHeight += lineSpacing;
        }
    }
    for (NSUInteger index = 0; index < lines.count; index++) {
        UIFont *font = lines[index][@"font"];
        blockHeight += font.lineHeight;
        if (index < lines.count - 1) {
            blockHeight += lineSpacing;
        }
    }

    if (blockHeight <= 0.0f) {
        return;
    }

    CGFloat startY = canvasSize.height - bottomInset - blockHeight;
    CGFloat minimumTop = MAX(horizontalMargin, canvasSize.height * 0.08f);
    if (startY < minimumTop) {
        startY = minimumTop;
    }

    CGFloat currentY = startY;
    if (hasLogoAsset) {
        CGFloat logoX = (canvasSize.width - logoWidth) / 2.0f;
        CGRect logoRect = CGRectMake(logoX, currentY, logoWidth, logoHeight);
        UIImage *renderableLogo = logoDescriptor.prefersTemplateRendering ? [logoImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : logoImage;
        if (logoDescriptor.prefersTemplateRendering) {
            [[UIColor whiteColor] setFill];
            [[UIColor whiteColor] setStroke];
        }
        [renderableLogo drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.95f];
        currentY = CGRectGetMaxY(logoRect);
        if (lines.count > 0) {
            currentY += lineSpacing;
        }
    }

    CGFloat textWidth = canvasSize.width - horizontalMargin * 2.0f;
    if (textWidth <= 0.0f) {
        textWidth = canvasSize.width;
    }

    for (NSUInteger index = 0; index < lines.count; index++) {
        NSString *text = lines[index][@"text"];
        UIFont *font = lines[index][@"font"];
        if (text.length == 0 || !font) {
            continue;
        }
        NSDictionary *attributes = attributesForFont(font);
        CGRect lineRect = CGRectMake(horizontalMargin, currentY, textWidth, font.lineHeight);
        [text drawInRect:lineRect withAttributes:attributes];
        currentY = CGRectGetMaxY(lineRect);
        if (index < lines.count - 1) {
            currentY += lineSpacing;
        }
    }
}

- (NSString *)supplementaryStringForConfiguration:(CMWatermarkConfiguration *)configuration
                                         metadata:(NSDictionary * _Nullable)metadata {
    NSLog(@"🔍 参数生成调试 - preference: %ld, preferenceOptions: %ld", (long)configuration.preference, (long)configuration.preferenceOptions);
    
    // 对于宝丽来模式，支持多选参数显示
    if (configuration.preferenceOptions != CMWatermarkPreferenceOptionsNone) {
        NSMutableArray *components = [NSMutableArray array];
        
        if (configuration.preferenceOptions & CMWatermarkPreferenceOptionsExposure) {
            NSString *exposure = [self exposureStringFromMetadata:metadata];
            if (exposure.length > 0) {
                [components addObject:exposure];
            }
        }
        
        if (configuration.preferenceOptions & CMWatermarkPreferenceOptionsCoordinates) {
            NSString *coordinates = [self coordinateStringFromMetadata:metadata];
            if (coordinates.length > 0) {
                [components addObject:coordinates];
            }
        }
        
        if (configuration.preferenceOptions & CMWatermarkPreferenceOptionsDate) {
            NSString *date = [self dateStringFromMetadata:metadata];
            if (date.length > 0) {
                [components addObject:date];
            }
        }
        
        return [components componentsJoinedByString:@"    "];
    }
    
    // 兼容旧的单选模式
    switch (configuration.preference) {
        case CMWatermarkPreferenceOff:
            return configuration.auxiliaryText;
        case CMWatermarkPreferenceExposure:
            return [self exposureStringFromMetadata:metadata];
        case CMWatermarkPreferenceCoordinates:
            return [self coordinateStringFromMetadata:metadata];
        case CMWatermarkPreferenceDate:
            return [self dateStringFromMetadata:metadata];
    }
}

- (NSString *)exposureStringFromMetadata:(NSDictionary *)metadata {
    NSLog(@"📊 曝光参数调试 - metadata存在: %@", metadata ? @"YES" : @"NO");
    if (!metadata) {
        // 测试数据：如果没有metadata，返回示例拍摄参数
        NSString *testParams = @"800 ISO    2.8 F    24 mm    1/60 S";
        NSLog(@"📊 返回测试参数: %@", testParams);
        return testParams;
    }
    NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
    if (!exif) {
        // 测试数据：如果没有EXIF信息，返回示例参数
        return @"1600 ISO    1.8 F    50 mm    1/125 S";
    }

    double fNumber = [exif[(NSString *)kCGImagePropertyExifFNumber] doubleValue];
    if (fNumber <= 0.0) {
        double apertureValue = [exif[(NSString *)kCGImagePropertyExifApertureValue] doubleValue];
        if (apertureValue > 0.0) {
            fNumber = pow(2.0, apertureValue / 2.0);
        }
    }

    double focalLength = [exif[(NSString *)kCGImagePropertyExifFocalLength] doubleValue];
    if (focalLength <= 0.0) {
        double focalLength35 = [exif[(NSString *)kCGImagePropertyExifFocalLenIn35mmFilm] doubleValue];
        if (focalLength35 > 0.0) {
            focalLength = focalLength35;
        }
    }

    double exposureTime = [exif[(NSString *)kCGImagePropertyExifExposureTime] doubleValue];
    if (exposureTime <= 0.0) {
        double shutterSpeedValue = [exif[(NSString *)kCGImagePropertyExifShutterSpeedValue] doubleValue];
        if (shutterSpeedValue != 0.0) {
            exposureTime = 1.0 / pow(2.0, shutterSpeedValue);
        }
    }

    NSArray *isoArray = exif[(NSString *)kCGImagePropertyExifISOSpeedRatings];
    NSInteger isoValue = [[isoArray firstObject] integerValue];
    if (isoValue <= 0) {
        isoValue = [exif[(NSString *)kCGImagePropertyExifExposureIndex] integerValue];
    }

    NSString *isoString = isoValue > 0 ? [NSString stringWithFormat:@"%ld ISO", (long)isoValue] : @"-- ISO";
    NSString *fString = fNumber > 0.0 ? [NSString stringWithFormat:@"%.1f F", fNumber] : @"-- F";
    NSString *focalString = focalLength > 0.0 ? [NSString stringWithFormat:@"%.0f mm", focalLength] : @"-- mm";

    NSString *shutterString;
    if (exposureTime > 0.0) {
        if (exposureTime >= 1.0) {
            shutterString = [NSString stringWithFormat:@"%.1f S", exposureTime];
        } else {
            double denominator = round(1.0 / exposureTime);
            shutterString = [NSString stringWithFormat:@"1/%.0f S", denominator];
        }
    } else {
        shutterString = @"-- S";
    }

    return [@[isoString, fString, focalString, shutterString] componentsJoinedByString:@"    "];
}

- (NSString *)coordinateStringFromMetadata:(NSDictionary *)metadata {
    if (!metadata) {
        // 测试数据：如果没有metadata，返回示例GPS坐标用于测试
        return @"N 39.9042°, E 116.4074°"; // 北京坐标示例
    }
    NSDictionary *gps = metadata[(NSString *)kCGImagePropertyGPSDictionary];
    if (!gps) {
        // 测试数据：如果没有GPS信息，返回示例坐标
        return @"N 31.2304°, E 121.4737°"; // 上海坐标示例
    }
    double latitude = [gps[(NSString *)kCGImagePropertyGPSLatitude] doubleValue];
    double longitude = [gps[(NSString *)kCGImagePropertyGPSLongitude] doubleValue];
    if (latitude == 0.0 && longitude == 0.0) {
        // 测试数据：如果GPS坐标为0，返回示例坐标
        return @"N 22.3964°, E 114.1095°"; // 香港坐标示例
    }
    NSString *latRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef] ?: (latitude >= 0.0 ? @"N" : @"S");
    NSString *lonRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef] ?: (longitude >= 0.0 ? @"E" : @"W");
    return [NSString stringWithFormat:@"%@ %.4f°, %@ %.4f°", latRef, fabs(latitude), lonRef, fabs(longitude)];
}

- (NSString *)dateStringFromMetadata:(NSDictionary *)metadata {
    if (!metadata) {
        return [self.dateFormatter stringFromDate:[NSDate date]];
    }
    NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
    NSString *timestampString = exif[(NSString *)kCGImagePropertyExifDateTimeOriginal];
    if (!timestampString) {
        timestampString = exif[(NSString *)kCGImagePropertyExifDateTimeDigitized];
    }
    if (timestampString.length > 0) {
        NSDateFormatter *parser = [[NSDateFormatter alloc] init];
        parser.dateFormat = @"yyyy:MM:dd HH:mm:ss";
        parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        parser.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        NSDate *timestamp = [parser dateFromString:timestampString];
        if (timestamp) {
            return [self.dateFormatter stringFromDate:timestamp];
        }
    }
    return [self.dateFormatter stringFromDate:[NSDate date]];
}

- (void)drawStudioParametersInRect:(CGRect)contentRect 
                      detailString:(NSString *)detailString 
                        canvasSize:(CGSize)canvasSize {
    CGFloat parameterFontSize = MAX(48.0, MIN(96.0, canvasSize.width * 0.075)) * CMWatermarkUIScaleFactor;
    parameterFontSize = MIN(parameterFontSize, contentRect.size.height * 0.85f);
    UIFont *parameterValueFont = [UIFont systemFontOfSize:parameterFontSize weight:UIFontWeightSemibold];
    UIFont *parameterLabelFont = [UIFont systemFontOfSize:parameterFontSize * 0.65 weight:UIFontWeightMedium];
    
    // 文字颜色 - 黑色
    UIColor *valueColor = [UIColor blackColor];
    UIColor *labelColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    
    // 解析参数字符串: "3200 ISO    2.0 F    23 mm    1/63 S"
    NSArray *components = [detailString componentsSeparatedByString:@"    "];
    if (components.count == 4) {
        CGFloat contentWidth = contentRect.size.width;
        CGFloat horizontalPadding = contentWidth * 0.05; // 5%的左右边距
        CGFloat availableWidth = contentWidth - (horizontalPadding * 2);
        CGFloat spacing = availableWidth / 4.0; // 四个参数平均分布在可用宽度内
        CGFloat startX = contentRect.origin.x + horizontalPadding;
        
        for (NSInteger i = 0; i < components.count; i++) {
            NSString *component = components[i];
            NSArray *parts = [component componentsSeparatedByString:@" "];
            if (parts.count >= 2) {
                NSString *value = parts[0];
                NSString *unit = parts[1];
                
                // 计算每个参数的中心位置
                CGFloat centerX = startX + (spacing * i) + (spacing * 0.5);
                CGFloat valueY = contentRect.origin.y + contentRect.size.height * 0.15;
                CGFloat labelY = valueY + parameterValueFont.lineHeight + (4.0 * CMWatermarkUIScaleFactor);
                
                // 绘制数值 - 居中对齐
                NSDictionary *valueAttributes = @{
                    NSFontAttributeName: parameterValueFont,
                    NSForegroundColorAttributeName: valueColor,
                    NSParagraphStyleAttributeName: [[NSParagraphStyle alloc] init]
                };
                CGSize valueSize = [value sizeWithAttributes:valueAttributes];
                CGFloat valueX = centerX - (valueSize.width * 0.5);
                CGRect valueRect = CGRectMake(valueX, valueY, valueSize.width, valueSize.height);
                [value drawInRect:valueRect withAttributes:valueAttributes];
                
                // 绘制单位 - 居中对齐
                NSDictionary *labelAttributes = @{
                    NSFontAttributeName: parameterLabelFont,
                    NSForegroundColorAttributeName: labelColor,
                    NSParagraphStyleAttributeName: [[NSParagraphStyle alloc] init]
                };
                CGSize labelSize = [unit sizeWithAttributes:labelAttributes];
                CGFloat labelX = centerX - (labelSize.width * 0.5);
                CGRect labelRect = CGRectMake(labelX, labelY, labelSize.width, labelSize.height);
                [unit drawInRect:labelRect withAttributes:labelAttributes];
            }
        }
    }
}

- (CGRect)aspectFillRectForImageSize:(CGSize)imageSize inBoundingRect:(CGRect)boundingRect {
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || CGRectIsEmpty(boundingRect)) {
        return boundingRect;
    }
    CGFloat widthScale = boundingRect.size.width / imageSize.width;
    CGFloat heightScale = boundingRect.size.height / imageSize.height;
    CGFloat scale = MAX(widthScale, heightScale);
    CGSize scaledSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    CGFloat originX = CGRectGetMidX(boundingRect) - scaledSize.width / 2.0;
    CGFloat originY = CGRectGetMidY(boundingRect) - scaledSize.height / 2.0;
    return CGRectMake(originX, originY, scaledSize.width, scaledSize.height);
}

- (void)drawPolaroidLayoutInRect:(CGRect)contentRect
                  configuration:(CMWatermarkConfiguration *)configuration
                   logoDescriptor:(CMWatermarkLogoDescriptor * _Nullable)logoDescriptor
                     detailString:(NSString *)detailString
                       canvasSize:(CGSize)canvasSize
                horizontalPadding:(CGFloat)horizontalPadding {
    
    // 3行布局：Logo(第1行), 文字(第2行), 参数(第3行) - 精确间距控制
    CGFloat logoToTextSpacing = 35.0 * CMWatermarkUIScaleFactor; // logo和文字间距
    CGFloat textToParamSpacing = 26.0 * CMWatermarkUIScaleFactor; // 文字和参数间距
    CGFloat currentY = contentRect.origin.y;
    
    // 第1行：Logo - 高度约占底部边框高度的20%
    CGFloat logoHeight = 0.0;
    if (logoDescriptor && logoDescriptor.assetName.length > 0) {
        UIImage *logoImage = [UIImage imageNamed:logoDescriptor.assetName];
        if (logoImage) {
            CGFloat bottomBorderHeight = contentRect.size.height;
            logoHeight = MIN(bottomBorderHeight * 0.20 * CMWatermarkUIScaleFactor, bottomBorderHeight);
            CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
            CGFloat logoWidth = logoHeight * aspect;
            
            CGFloat logoX = contentRect.origin.x + (contentRect.size.width - logoWidth) / 2.0;
            CGRect logoRect = CGRectMake(logoX, currentY, logoWidth, logoHeight);
            
            UIImage *renderableLogo = logoDescriptor.prefersTemplateRendering ? 
                [logoImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : logoImage;
            if (logoDescriptor.prefersTemplateRendering) {
                [[UIColor blackColor] setFill]; // 宝丽来模式使用黑色logo
                [[UIColor blackColor] setStroke];
            }
            [renderableLogo drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.95];
        }
    }
    currentY += logoHeight + logoToTextSpacing;
    
    // 第2行：文字 - 字号为Logo高度的35%-40%，无logo时使用底部区域高度计算
    CGFloat row2Y = currentY;
    CGFloat textFontSize;
    if (logoHeight > 0) {
        textFontSize = logoHeight * 0.5; // 有logo时基于logo高度
    } else {
        textFontSize = contentRect.size.height * 0.12 * CMWatermarkUIScaleFactor; // 无logo时基于底部区域高度
        textFontSize = MIN(textFontSize, contentRect.size.height * 0.9f);
    }
    textFontSize = MIN(textFontSize, contentRect.size.height);
    UIFont *textFont = [UIFont systemFontOfSize:textFontSize weight:UIFontWeightMedium];
    UIColor *textColor = [UIColor blackColor]; // 纯黑色 #000000
    
    NSMutableString *combinedText = [NSMutableString string];
    if (configuration.isCaptionEnabled && configuration.captionText.length > 0) {
        [combinedText appendString:configuration.captionText];
    }
    // 署名功能已删除
    // if (configuration.isSignatureEnabled && configuration.signatureText.length > 0) {
    //     if (combinedText.length > 0) {
    //         [combinedText appendString:@" | "];
    //     }
    //     [combinedText appendString:configuration.signatureText];
    // }
    
    if (combinedText.length > 0) {
        NSMutableParagraphStyle *textParagraph = [[NSMutableParagraphStyle alloc] init];
        textParagraph.alignment = NSTextAlignmentCenter;
        textParagraph.lineBreakMode = NSLineBreakByTruncatingTail;
        
        NSDictionary *textAttributes = @{
            NSFontAttributeName: textFont,
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: textParagraph
        };
        
        CGRect textRect = CGRectMake(contentRect.origin.x + horizontalPadding,
                                     row2Y,
                                     contentRect.size.width - 2 * horizontalPadding,
                                     textFont.lineHeight);
        [combinedText drawInRect:textRect withAttributes:textAttributes];
        currentY += textFont.lineHeight + textToParamSpacing;
    } else {
        // 即使没有文字内容，也要为参数留出合适的位置
        currentY = row2Y + textToParamSpacing;
    }
    
    // 第3行：参数 - 字号为文字部分的70%-80%
    if (detailString.length > 0) {
        CGFloat row3Y = currentY;
        CGFloat parameterFontSize = textFontSize * 0.75; // 文字字号的75% (70%-80%之间)
        CGFloat parameterHeight = MIN(contentRect.size.height * 0.3, 90.0 * CMWatermarkUIScaleFactor);
        [self drawPolaroidParametersInRect:CGRectMake(contentRect.origin.x, row3Y, contentRect.size.width, parameterHeight)
                              detailString:detailString
                                canvasSize:canvasSize
                            parameterFontSize:parameterFontSize];
    }
}

- (void)drawPolaroidParametersInRect:(CGRect)rect
                        detailString:(NSString *)detailString
                          canvasSize:(CGSize)canvasSize
                   parameterFontSize:(CGFloat)parameterFontSize {

    UIFont *parameterFont = [UIFont systemFontOfSize:parameterFontSize weight:UIFontWeightMedium];
    UIColor *parameterColor = [UIColor colorWithRed:102.0/255.0 green:102.0/255.0 blue:102.0/255.0 alpha:1.0]; // #666666

    NSMutableParagraphStyle *parameterParagraph = [[NSMutableParagraphStyle alloc] init];
    parameterParagraph.alignment = NSTextAlignmentCenter;
    parameterParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *parameterAttributes = @{
        NSFontAttributeName: parameterFont,
        NSForegroundColorAttributeName: parameterColor,
        NSParagraphStyleAttributeName: parameterParagraph
    };

    // 将参数字符串分解并水平排列
    NSArray *components = [detailString componentsSeparatedByString:@"    "];
    if (components.count > 0) {
        NSString *displayText = [components componentsJoinedByString:@"  •  "];

        CGFloat horizontalPadding = rect.size.width * 0.05;
        CGRect parameterRect = CGRectMake(rect.origin.x + horizontalPadding,
                                         rect.origin.y + (rect.size.height - parameterFont.lineHeight) / 2.0,
                                         rect.size.width - 2 * horizontalPadding,
                                         parameterFont.lineHeight);
        [displayText drawInRect:parameterRect withAttributes:parameterAttributes];
    }
}

- (void)drawInfoLayoutInRect:(CGRect)contentRect
               configuration:(CMWatermarkConfiguration *)configuration
                logoDescriptor:(CMWatermarkLogoDescriptor * _Nullable)logoDescriptor
                  detailString:(NSString *)detailString
                    canvasSize:(CGSize)canvasSize
             horizontalPadding:(CGFloat)horizontalPadding
                      metadata:(NSDictionary * _Nullable)metadata {

    NSLog(@"🔍 Info布局调试 - detailString: '%@', preference: %ld", detailString ?: @"(nil)", (long)configuration.preference);
    NSLog(@"📏 字体大小调试 - 画布尺寸: %.0fx%.0f, 底部区域: %.0fx%.0f", canvasSize.width, canvasSize.height, contentRect.size.width, contentRect.size.height);
    
    // 动态设计参数 - 增大字体大小
    const CGFloat textSpacing = 20.0; // 文字间距20px
    // 增大字体大小：从15%和2%调整为20%和3%
    CGFloat baseFontSize = MIN(contentRect.size.height * 0.20, canvasSize.width * 0.03); // 底部区域高度的20%或画布宽度的3%，取较小值
    CGFloat primaryFontSize = baseFontSize * CMWatermarkUIScaleFactor;
    CGFloat secondaryFontSize = primaryFontSize * 0.85;
    CGFloat logoHeight = contentRect.size.height * 0.6; // Logo高度为底部区域高度的60%
    
    NSLog(@"📏 字体大小调试 - baseFontSize: %.1f, primaryFontSize: %.1f, secondaryFontSize: %.1f, logoHeight: %.1f", baseFontSize, primaryFontSize, secondaryFontSize, logoHeight);
    
    UIFont *primaryFont = [UIFont systemFontOfSize:primaryFontSize weight:UIFontWeightSemibold];
    UIFont *secondaryFont = [UIFont systemFontOfSize:secondaryFontSize weight:UIFontWeightMedium];
    
    UIColor *blackColor = [UIColor blackColor];
    UIColor *grayColor = [UIColor colorWithRed:102.0/255.0 green:102.0/255.0 blue:102.0/255.0 alpha:1.0];
    
    // 重新计算所有内容的总高度 - 确保包含文字的实际高度
    CGFloat textContentHeight = primaryFont.lineHeight + textSpacing + secondaryFont.lineHeight;
    CGFloat totalContentHeight = MAX(textContentHeight, logoHeight);
    
    // 确保内容块在底部区域垂直居中 - 使用更精确的计算
    CGFloat availableHeight = contentRect.size.height;
    CGFloat contentStartY = contentRect.origin.y + (availableHeight - totalContentHeight) / 2.0;
    CGFloat contentCenterY = contentStartY + totalContentHeight / 2.0;
    
    NSLog(@"📏 垂直居中调试 - 文字内容高度: %.1f, 总内容高度: %.1f, 可用高度: %.1f, 开始Y: %.1f, 中心Y: %.1f", textContentHeight, totalContentHeight, availableHeight, contentStartY, contentCenterY);
    
    // 左侧区域：设备型号和时间
    NSString *deviceModel = [self deviceModelString];
    NSString *dateString = [self dateStringFromMetadata:metadata];
    
    // 计算左侧文字的实际宽度（自适应）
    NSDictionary *deviceAttributes = @{
        NSFontAttributeName: primaryFont,
        NSForegroundColorAttributeName: blackColor
    };
    NSDictionary *dateAttributes = @{
        NSFontAttributeName: secondaryFont,
        NSForegroundColorAttributeName: grayColor
    };
    
    CGSize deviceSize = [deviceModel sizeWithAttributes:deviceAttributes];
    CGSize dateSize = [dateString sizeWithAttributes:dateAttributes];
    CGFloat leftMaxWidth = MAX(deviceSize.width, dateSize.width);
    
    // 计算左侧内容的垂直居中位置 - 使用统一的contentStartY并向上调整
    CGFloat leftContentHeight = primaryFont.lineHeight + textSpacing + secondaryFont.lineHeight;
    // 向上调整偏移量，让内容更居中
    CGFloat verticalOffset = contentRect.size.height * 0.7; // 向上偏移10%
    CGFloat leftStartY = contentStartY - verticalOffset;
    
    // 绘制设备型号（上行）- 使用自适应宽度
    CGRect deviceRect = CGRectMake(contentRect.origin.x + horizontalPadding, leftStartY, leftMaxWidth, primaryFont.lineHeight);
    [deviceModel drawInRect:deviceRect withAttributes:deviceAttributes];
    
    // 绘制时间（下行）- 使用自适应宽度
    CGRect dateRect = CGRectMake(contentRect.origin.x + horizontalPadding, leftStartY + primaryFont.lineHeight + textSpacing, leftMaxWidth, secondaryFont.lineHeight);
    [dateString drawInRect:dateRect withAttributes:dateAttributes];
    
    // 右侧区域：参数和GPS坐标
    if (detailString.length > 0) {
        NSLog(@"📊 绘制参数信息: '%@'", detailString);
        
        NSString *gpsString = [self coordinateStringFromMetadata:metadata];
        
        // 计算右侧文字的实际宽度（自适应）
        NSDictionary *paramAttributes = @{
            NSFontAttributeName: primaryFont,
            NSForegroundColorAttributeName: blackColor,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
                style.alignment = NSTextAlignmentRight;
                style;
            })
        };
        NSDictionary *gpsAttributes = @{
            NSFontAttributeName: secondaryFont,
            NSForegroundColorAttributeName: grayColor,
            NSParagraphStyleAttributeName: ({
                NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
                style.alignment = NSTextAlignmentRight;
                style;
            })
        };
        
        CGSize paramSize = [detailString sizeWithAttributes:paramAttributes];
        CGSize gpsSize = [gpsString sizeWithAttributes:gpsAttributes];
        CGFloat rightMaxWidth = MAX(paramSize.width, gpsSize.width);
        
        // 计算右侧内容的垂直居中位置 - 使用统一的contentStartY并向上调整，与左侧保持一致
        CGFloat rightStartY = contentStartY - verticalOffset;
        
        NSLog(@"📏 垂直居中修复调试 - 左侧StartY: %.1f, 右侧StartY: %.1f, 向上偏移: %.1f, 可用高度: %.1f", leftStartY, rightStartY, verticalOffset, contentRect.size.height);
        
        // 计算右侧区域的位置（从右边开始布局）- 使用自适应宽度
        CGFloat rightX = contentRect.origin.x + contentRect.size.width - horizontalPadding - rightMaxWidth;
        
        // 绘制参数（上行）- 使用自适应宽度
        CGRect paramRect = CGRectMake(rightX, rightStartY, rightMaxWidth, primaryFont.lineHeight);
        NSLog(@"📊 参数绘制区域: %@", NSStringFromCGRect(paramRect));
        [detailString drawInRect:paramRect withAttributes:paramAttributes];
        
        // 绘制GPS坐标（下行）- 使用自适应宽度
        CGRect gpsRect = CGRectMake(rightX, rightStartY + primaryFont.lineHeight + textSpacing, rightMaxWidth, secondaryFont.lineHeight);
        [gpsString drawInRect:gpsRect withAttributes:gpsAttributes];
        
        // Logo绘制 - 紧靠右侧参数左边，垂直居中并向上调整
        if (logoDescriptor && logoDescriptor.assetName.length > 0) {
            UIImage *logoImage = [UIImage imageNamed:logoDescriptor.assetName];
            if (logoImage) {
                CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
                CGFloat logoWidth = logoHeight * aspect;
                
                // 灰色分隔线参数
                const CGFloat separatorWidth = 2.0;
                const CGFloat separatorHeight = logoHeight*2; // 分隔线高度与logo成比例
                const CGFloat separatorMargin = 88.0; // 分隔线与logo和参数的间距
                
                // Logo位置：考虑分隔线的位置，垂直居中并向上调整
                CGFloat logoX = rightX - logoWidth - separatorMargin - separatorWidth - separatorMargin;
                CGFloat logoY = contentRect.origin.y + (contentRect.size.height - logoHeight) / 2.0 - verticalOffset;
                
                CGRect logoRect = CGRectMake(logoX, logoY, logoWidth, logoHeight);
                
                UIImage *renderableLogo = logoDescriptor.prefersTemplateRendering ? 
                    [logoImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : logoImage;
                if (logoDescriptor.prefersTemplateRendering) {
                    [[UIColor blackColor] setFill];
                    [[UIColor blackColor] setStroke];
                }
                [renderableLogo drawInRect:logoRect blendMode:kCGBlendModeNormal alpha:0.95];
                
                // 绘制灰色分隔线 - 在logo和参数之间，垂直居中并向上调整
                CGFloat separatorX = logoX + logoWidth + separatorMargin;
                CGFloat separatorY = contentRect.origin.y + (contentRect.size.height - separatorHeight) / 2.0 - verticalOffset;
                CGRect separatorRect = CGRectMake(separatorX, separatorY, separatorWidth, separatorHeight);
                
                [[UIColor colorWithRed:180.0/255.0 green:180.0/255.0 blue:180.0/255.0 alpha:1.0] setFill];
                UIRectFill(separatorRect);
            }
        }
    } else {
        NSLog(@"⚠️ detailString为空，无法显示参数");
    }
}

- (NSString *)deviceModelString {
    // 获取设备机型信息
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceIdentifier = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    // 将设备标识符转换为友好的机型名称
    NSDictionary *deviceNames = @{
        // iPhone 15 系列
        @"iPhone16,1": @"iPhone 15",
        @"iPhone16,2": @"iPhone 15 Plus",
        @"iPhone15,4": @"iPhone 15 Pro",
        @"iPhone15,5": @"iPhone 15 Pro Max",

        // iPhone 14 系列
        @"iPhone14,7": @"iPhone 14",
        @"iPhone14,8": @"iPhone 14 Plus",
        @"iPhone15,2": @"iPhone 14 Pro",
        @"iPhone15,3": @"iPhone 14 Pro Max",

        // iPhone 13 系列
        @"iPhone14,5": @"iPhone 13",
        @"iPhone14,2": @"iPhone 13 mini",
        @"iPhone14,3": @"iPhone 13 Pro",
        @"iPhone14,4": @"iPhone 13 Pro Max",

        // iPhone 12 系列
        @"iPhone13,2": @"iPhone 12",
        @"iPhone13,1": @"iPhone 12 mini",
        @"iPhone13,3": @"iPhone 12 Pro",
        @"iPhone13,4": @"iPhone 12 Pro Max",

        // 模拟器
        @"x86_64": @"iPhone Simulator",
        @"arm64": @"iPhone Simulator"
    };

    NSString *friendlyName = deviceNames[deviceIdentifier];
    return friendlyName ?: deviceIdentifier;
}

@end
