//
//  CMWatermarkRenderer.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "CMWatermarkRenderer.h"
#import "CMWatermarkCatalog.h"
#import "CMWatermarkConfiguration.h"
#import <ImageIO/ImageIO.h>
#import <math.h>
#import <sys/utsname.h>

static const CGFloat CMWatermarkUIScaleFactor = 1.5f;
static const CGFloat CMWatermarkReferenceShortSide = 3024.0f;
static const CGFloat CMWatermarkReferenceLongSide = 4032.0f;
// Keep 48MP capture output intact after frame expansion.
// 8064x6048 ~= 48.8MP; with footer/frame expansion it can exceed 55MP.
static const CGFloat CMWatermarkMaxRenderPixels = 90000000.0f; // ~90MP cap

static inline CGFloat CMWatermarkCanvasScaleForSize(CGSize canvasSize) {
  CGFloat shortSide = MIN(canvasSize.width, canvasSize.height);
  CGFloat longSide = MAX(canvasSize.width, canvasSize.height);
  if (shortSide <= 0.0f || longSide <= 0.0f) {
    return 1.0f;
  }

  CGFloat referenceDiagonal =
      hypot(CMWatermarkReferenceLongSide, CMWatermarkReferenceShortSide);
  CGFloat currentDiagonal = hypot(longSide, shortSide);
  CGFloat normalized = currentDiagonal / referenceDiagonal;

  // Soften the delta so imported assets with very different resolutions
  // keep similar perceived sizing compared to captured photos.
  CGFloat softened = pow(normalized, 0.5f);

  // Clamp to a narrow band to avoid giant or tiny glyphs on extreme inputs.
  return MIN(MAX(softened, 0.78f), 1.06f);
}

static inline CGFloat CMWatermarkScaledPointSize(CGSize canvasSize,
                                                 CGFloat minPointSize,
                                                 CGFloat maxPointSize) {
  CGFloat scale = CMWatermarkCanvasScaleForSize(canvasSize);
  if (scale <= 0.0f) {
    scale = 1.0f;
  }

  CGFloat target = maxPointSize * scale;
  if (target < minPointSize) {
    target = minPointSize;
  }

  return target * CMWatermarkUIScaleFactor;
}

// Inline(无相框)模式使用更宽的分辨率自适应区间，避免高分辨率下logo/参数显得过小。
static inline CGFloat CMWatermarkInlineAdaptiveScale(CGSize canvasSize) {
  CGFloat width = MAX(canvasSize.width, 1.0f);
  CGFloat height = MAX(canvasSize.height, 1.0f);
  CGFloat shortSide = MIN(width, height);
  CGFloat megaPixels = (width * height) / 1000000.0f;

  // 以 12MP(4032x3024) 为基准做自适应。
  CGFloat shortSideFactor = pow(shortSide / CMWatermarkReferenceShortSide, 0.60f);
  CGFloat megaPixelFactor = pow(MAX(megaPixels / 12.0f, 0.2f), 0.20f);
  CGFloat adaptive = shortSideFactor * megaPixelFactor;

  return MIN(MAX(adaptive, 0.95f), 1.60f);
}

static inline CGFloat CMWatermarkConsistentLogoHeight(CGFloat captionLineHeight,
                                                      CGSize canvasSize,
                                                      CGFloat maxContentHeight) {
  CGFloat scale = CMWatermarkCanvasScaleForSize(canvasSize);
  CGFloat targetHeight = captionLineHeight * 1.35f * scale;
  CGFloat maxAllowed = 0.0f;
  if (maxContentHeight > 0.0f) {
    maxAllowed = maxContentHeight;
  }

  CGFloat absoluteCap = captionLineHeight * 1.85f;
  if (maxAllowed > 0.0f) {
    targetHeight = MIN(targetHeight, maxAllowed);
  }
  targetHeight = MIN(targetHeight, absoluteCap);

  CGFloat minimum = captionLineHeight * 0.95f;
  if (targetHeight < minimum) {
    targetHeight = minimum;
  }

  return targetHeight;
}

static inline BOOL CMIsStudioLikeFrameIdentifier(NSString * _Nullable identifier) {
  if (identifier.length == 0) {
    return NO;
  }
  return [identifier isEqualToString:@"frame.studio"];
}

@interface CMWatermarkRenderer ()

@property(nonatomic, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, strong) NSCache<NSString *, UIImage *> *assetImageCache;
@property(nonatomic, strong) NSCache<NSString *, UIImage *> *renderableLogoCache;

- (UIImage *_Nullable)cachedAssetImageNamed:(NSString *)assetName;
- (UIImage *_Nullable)cachedRenderableLogoForDescriptor:
    (CMWatermarkLogoDescriptor *)logoDescriptor;

@end

@implementation CMWatermarkRenderer

- (instancetype)init {
  self = [super init];
  if (self) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
    _dateFormatter.locale =
        [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    _dateFormatter.timeZone = [NSTimeZone localTimeZone];
    _assetImageCache = [[NSCache alloc] init];
    _assetImageCache.name = @"com.cameram.watermark.assets";
    _assetImageCache.countLimit = 128;
    _renderableLogoCache = [[NSCache alloc] init];
    _renderableLogoCache.name = @"com.cameram.watermark.logos";
    _renderableLogoCache.countLimit = 64;
  }
  return self;
}

- (UIImage *)cachedAssetImageNamed:(NSString *)assetName {
  if (assetName.length == 0) {
    return nil;
  }
  UIImage *cached = [self.assetImageCache objectForKey:assetName];
  if (cached) {
    return cached;
  }
  UIImage *image = [UIImage imageNamed:assetName];
  if (image) {
    [self.assetImageCache setObject:image forKey:assetName];
  }
  return image;
}

- (UIImage *)cachedRenderableLogoForDescriptor:
    (CMWatermarkLogoDescriptor *)logoDescriptor {
  if (logoDescriptor.assetName.length == 0) {
    return nil;
  }
  NSString *cacheKey =
      [NSString stringWithFormat:@"%@#tpl=%d", logoDescriptor.assetName,
                                 logoDescriptor.prefersTemplateRendering ? 1 : 0];
  UIImage *cached = [self.renderableLogoCache objectForKey:cacheKey];
  if (cached) {
    return cached;
  }
  UIImage *baseLogo = [self cachedAssetImageNamed:logoDescriptor.assetName];
  if (!baseLogo) {
    return nil;
  }
  UIImage *renderable =
      logoDescriptor.prefersTemplateRendering
          ? [baseLogo imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
          : baseLogo;
  [self.renderableLogoCache setObject:renderable forKey:cacheKey];
  return renderable;
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
    CMWatermarkFrameDescriptor *frameDescriptor = [CMWatermarkCatalog
        frameDescriptorForIdentifier:configuration.frameIdentifier
                                         ?: CMWatermarkFrameIdentifierNone];
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
        effectiveConfiguration.preference =
            (CMWatermarkPreference)frameDescriptor.enforcedPreferenceRawValue;
      }
    }

    CMWatermarkLogoDescriptor *logoDescriptor = nil;
    if (effectiveConfiguration.logoEnabled) {
      logoDescriptor = [CMWatermarkCatalog
          logoDescriptorForIdentifier:effectiveConfiguration.logoIdentifier
                                          ?: CMWatermarkLogoIdentifierNone];
    }
    CGFloat baseWidth = image.size.width;
    CGFloat baseHeight = image.size.height;
    CGFloat baseShortSide = MIN(baseWidth, baseHeight);
    CGFloat bottomRatio = MAX(0.0f, frameDescriptor.bottomExpansionRatio);
    CGFloat estimatedCanvasPixels =
        baseWidth * (baseHeight + bottomRatio * baseShortSide);
    if (estimatedCanvasPixels > CMWatermarkMaxRenderPixels &&
        baseWidth > 0.0f && baseHeight > 0.0f) {
      CGFloat renderScale =
          sqrt(CMWatermarkMaxRenderPixels / estimatedCanvasPixels);
      renderScale = MAX(MIN(renderScale, 1.0f), 0.2f);
      baseWidth = MAX(1.0f, floor(baseWidth * renderScale));
      baseHeight = MAX(1.0f, floor(baseHeight * renderScale));
      baseShortSide = MIN(baseWidth, baseHeight);
      NSLog(@"⚠️ [CMWatermarkRenderer] 超大图渲染降采样: scale=%.3f, %.0fx%.0f",
            renderScale, baseWidth, baseHeight);
    }
    const CGFloat bottomPadding =
        MAX(0.0, frameDescriptor.bottomExpansionRatio * baseShortSide);
    const CGSize canvasSize = CGSizeMake(baseWidth, baseHeight + bottomPadding);

    UIGraphicsImageRendererFormat *format =
        [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0f;
    format.opaque = YES;
    format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize format:format];
    UIImage *composited = [renderer
        imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull context) {
          CGContextRef ctx = context.CGContext;
          CGContextSaveGState(ctx);

          // 对于Studio模式、Polaroid模式和Info模式，使用白色背景，否则使用黑色
          if (CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier) ||
              [frameDescriptor.identifier isEqualToString:@"frame.polaroid"] ||
              [frameDescriptor.identifier isEqualToString:@"frame.info"]) {
            CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
          } else {
            CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
          }
          CGContextFillRect(
              ctx, CGRectMake(0, 0, canvasSize.width, canvasSize.height));
          CGContextRestoreGState(ctx);

          UIImage *overlay = nil;
          void (^drawOverlay)(CGRect photoMaskRect, BOOL usesMask) = nil;
          BOOL overlayShouldDrawAbovePhoto = YES;
          if (frameDescriptor.overlayAssetName.length > 0) {
            overlay = [self cachedAssetImageNamed:frameDescriptor.overlayAssetName];
            if (overlay) {
              overlayShouldDrawAbovePhoto =
                  frameDescriptor.overlayDrawsAbovePhoto;
              drawOverlay = ^(CGRect photoMaskRect, BOOL usesMask) {
                CGFloat overlayHeight = baseHeight + bottomPadding;
                CGRect overlayRect =
                    CGRectMake(0.0, 0.0, canvasSize.width, overlayHeight);
                if (frameDescriptor.overlayInsetsRatio > 0.0) {
                  CGFloat insetX =
                      frameDescriptor.overlayInsetsRatio * canvasSize.width;
                  CGFloat insetY =
                      frameDescriptor.overlayInsetsRatio * overlayHeight;
                  overlayRect = CGRectInset(overlayRect, insetX, insetY);
                }
                if (usesMask && !CGRectIsEmpty(photoMaskRect)) {
                  UIBezierPath *clipPath =
                      [UIBezierPath bezierPathWithRect:overlayRect];
                  CGFloat radius = frameDescriptor.photoCornerRadiusRatio *
                                   MIN(canvasSize.width, canvasSize.height);
                  UIBezierPath *holePath =
                      radius > 0.0
                          ? [UIBezierPath
                                bezierPathWithRoundedRect:photoMaskRect
                                             cornerRadius:radius]
                          : [UIBezierPath bezierPathWithRect:photoMaskRect];
                  [clipPath appendPath:holePath];
                  clipPath.usesEvenOddFillRule = YES;

                  CGContextSaveGState(ctx);
                  CGContextAddPath(ctx, clipPath.CGPath);
                  CGContextEOClip(ctx);
                  [overlay drawInRect:overlayRect
                            blendMode:kCGBlendModeNormal
                                alpha:1.0];
                  CGContextRestoreGState(ctx);
                } else {
                  [overlay drawInRect:overlayRect
                            blendMode:kCGBlendModeNormal
                                alpha:1.0];
                }
              };
            } else {
              overlayShouldDrawAbovePhoto = YES;
            }
          }

          UIEdgeInsets scaledContentInsets = UIEdgeInsetsZero;
          if (frameDescriptor) {
            scaledContentInsets.top =
                frameDescriptor.contentInsetsRatio.top * canvasSize.height;
            scaledContentInsets.bottom =
                frameDescriptor.contentInsetsRatio.bottom * canvasSize.height;
            scaledContentInsets.left =
                frameDescriptor.contentInsetsRatio.left * canvasSize.width;
            scaledContentInsets.right =
                frameDescriptor.contentInsetsRatio.right * canvasSize.width;
            // 确保底部预留空间至少等于扩展高度，避免照片覆盖文字区域
            scaledContentInsets.bottom =
                MAX(scaledContentInsets.bottom, bottomPadding);
          } else if (bottomPadding > 0.0) {
            scaledContentInsets.bottom = bottomPadding;
          }

          CGRect contentRect = UIEdgeInsetsInsetRect(
              (CGRect){CGPointZero, canvasSize}, scaledContentInsets);
          if (CGRectIsEmpty(contentRect)) {
            contentRect = CGRectMake(0, 0, baseWidth, baseHeight);
          }

          BOOL hasCustomPhotoMask =
              frameDescriptor.photoContentScale.width > 0.0 &&
              frameDescriptor.photoContentScale.height > 0.0;
          CGRect photoMaskRect = CGRectZero;
          CGRect polaroidFooterRect = CGRectNull;
          if (hasCustomPhotoMask) {
            photoMaskRect = CGRectMake(
                frameDescriptor.photoContentOffset.x * canvasSize.width,
                frameDescriptor.photoContentOffset.y * canvasSize.height,
                frameDescriptor.photoContentScale.width * canvasSize.width,
                frameDescriptor.photoContentScale.height * canvasSize.height);
            if (frameDescriptor &&
                [frameDescriptor.identifier
                    isEqualToString:CMWatermarkFrameIdentifierPolaroid]) {
              // 保持宝丽来模式顶部边框与左右边框尺寸一致
              CGFloat sideInset =
                  frameDescriptor.photoContentOffset.x * canvasSize.width;
              CGFloat originalBottomInset =
                  canvasSize.height - CGRectGetMaxY(photoMaskRect);
              CGFloat desiredTopInset = sideInset;
              CGFloat adjustedHeight =
                  canvasSize.height - desiredTopInset - originalBottomInset;
              if (adjustedHeight > 0.0) {
                photoMaskRect.origin.y = desiredTopInset;
                photoMaskRect.size.height = adjustedHeight;
              }
              // 使用实际的照片底部位置计算底部内容区域，保证整体垂直居中
              CGFloat photoBottom = CGRectGetMaxY(photoMaskRect);
              CGFloat footerHeight = MAX(0.0, canvasSize.height - photoBottom);
              if (footerHeight > 0.0) {
                polaroidFooterRect = CGRectMake(0.0, photoBottom,
                                                canvasSize.width, footerHeight);
              }
            }
            if (!CGRectIsEmpty(photoMaskRect)) {
              contentRect = photoMaskRect;
            }
          }

          if (drawOverlay && !overlayShouldDrawAbovePhoto) {
            drawOverlay(photoMaskRect, hasCustomPhotoMask);
          }

          CGRect photoRect = [self aspectFillRectForImageSize:image.size
                                               inBoundingRect:contentRect];
          CGContextSaveGState(ctx);
          CGContextAddRect(ctx, contentRect);
          CGContextClip(ctx);
          [image drawInRect:photoRect];
          CGContextRestoreGState(ctx);

          // 对于Studio模式，使用sign_b保持比例显示在底部区域
          if (frameDescriptor &&
              CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier) &&
              bottomPadding > 0.0) {
            if (frameDescriptor.backgroundAssetName.length > 0) {
              UIImage *background = [self
                  cachedAssetImageNamed:frameDescriptor.backgroundAssetName];
              if (background) {
                // sign_b高度为底部区域的四分之一，保持原始比例
                CGFloat signBHeight = bottomPadding * 0.25;
                CGFloat originalAspectRatio =
                    background.size.width / background.size.height;
                CGFloat calculatedWidth = signBHeight * originalAspectRatio;

                // 如果计算出的宽度超过画布宽度，则以画布宽度为准并重新计算高度
                CGFloat finalWidth, finalHeight;
                if (calculatedWidth > canvasSize.width) {
                  finalWidth = canvasSize.width;
                  finalHeight = finalWidth / originalAspectRatio;
                } else {
                  finalWidth = calculatedWidth;
                  finalHeight = signBHeight;
                }

                // 居中显示在底部区域，向上移动100px
                CGFloat centerX = (canvasSize.width - finalWidth) / 2.0;
                CGFloat centerY =
                    baseHeight + (bottomPadding - finalHeight) / 2.0 - 150.0;
                CGRect backgroundRect =
                    CGRectMake(centerX, centerY, finalWidth, finalHeight);
                [background drawInRect:backgroundRect
                             blendMode:kCGBlendModeNormal
                                 alpha:1.0];
              }
            }

          } else if (frameDescriptor &&
                     [frameDescriptor.identifier
                         isEqualToString:@"frame.polaroid"] &&
                     bottomPadding > 0.0) {
            // Polaroid模式使用白色背景
            CGRect whiteBackgroundRect =
                CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
            [[UIColor whiteColor] setFill];
            UIRectFillUsingBlendMode(whiteBackgroundRect, kCGBlendModeNormal);

          } else if (frameDescriptor &&
                     [frameDescriptor.identifier
                         isEqualToString:@"frame.info"] &&
                     bottomPadding > 0.0) {
            // Info模式使用白色背景
            CGRect whiteBackgroundRect =
                CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
            [[UIColor whiteColor] setFill];
            UIRectFillUsingBlendMode(whiteBackgroundRect, kCGBlendModeNormal);

          } else if (frameDescriptor.backgroundAssetName.length > 0 &&
                     bottomPadding > 0.0) {
            // 其他相框模式的原有逻辑
            UIImage *background = [self
                cachedAssetImageNamed:frameDescriptor.backgroundAssetName];
            if (background) {
              CGRect backgroundRect =
                  CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
              [background drawInRect:backgroundRect
                           blendMode:kCGBlendModeNormal
                               alpha:1.0];
            } else {
              CGRect fallbackRect =
                  CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
              [[UIColor colorWithWhite:0.08 alpha:0.75] setFill];
              UIRectFillUsingBlendMode(fallbackRect, kCGBlendModeNormal);
            }
          } else if (bottomPadding > 0.0) {
            CGRect fallbackRect =
                CGRectMake(0.0, baseHeight, canvasSize.width, bottomPadding);
            [[UIColor colorWithWhite:0.05 alpha:0.75] setFill];
            UIRectFillUsingBlendMode(fallbackRect, kCGBlendModeNormal);
          }

          if (drawOverlay && overlayShouldDrawAbovePhoto) {
            drawOverlay(photoMaskRect, hasCustomPhotoMask);
          }

          CGRect footerOverrideRect = polaroidFooterRect;
          if (frameDescriptor &&
              !CGRectIsEmpty(frameDescriptor.footerContentRect)) {
            CGRect normalized = frameDescriptor.footerContentRect;
            footerOverrideRect =
                CGRectMake(normalized.origin.x * canvasSize.width,
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
                       logoDescriptor:
                           (CMWatermarkLogoDescriptor *_Nullable)logoDescriptor
                      frameDescriptor:
                          (CMWatermarkFrameDescriptor *_Nullable)frameDescriptor
                             metadata:(NSDictionary *_Nullable)metadata {
  BOOL shouldRenderInline =
      (!frameDescriptor || [frameDescriptor.identifier
                               isEqualToString:CMWatermarkFrameIdentifierNone]);
  NSString *detailString =
      [self supplementaryStringForConfiguration:configuration
                                       metadata:metadata
                                     inlineMode:shouldRenderInline];

  if (shouldRenderInline) {
    [self drawInlineWatermarkOnPhotoInContext:context
                                   canvasSize:canvasSize
                                configuration:configuration
                               logoDescriptor:logoDescriptor
                                 detailString:detailString];
    return;
  }

  const CGFloat horizontalPadding = MAX(24.0, canvasSize.width * 0.04);
  const CGFloat footerHeight = bottomPadding > 0.0
                                   ? bottomPadding
                                   : MAX(120.0, canvasSize.height * 0.12);
  CGRect defaultFooterRect =
      CGRectMake(0.0, imageHeight, canvasSize.width, footerHeight);

  CGRect contentRect;
  if (!CGRectIsEmpty(footerOverrideRect)) {
    contentRect = footerOverrideRect;
  } else if (configuration.placement == CMWatermarkPlacementMiddle ||
             configuration.watermarkAnchor == CMWatermarkAnchorCenter) {
    CGFloat contentHeight = MIN(footerHeight, imageHeight * 0.28);
    CGFloat originY = MAX(0.0, (imageHeight - contentHeight) / 2.0);
    contentRect = CGRectMake(0.0, originY, canvasSize.width, contentHeight);
    [[UIColor colorWithWhite:0.02 alpha:0.55] setFill];
    UIBezierPath *rounded = [UIBezierPath
        bezierPathWithRoundedRect:CGRectInset(contentRect,
                                              horizontalPadding * 0.5,
                                              contentRect.size.height * 0.1)
                     cornerRadius:contentRect.size.height * 0.25];
    [rounded fill];
  } else {
    contentRect = defaultFooterRect;
  }

  CGFloat cursorX = contentRect.origin.x + horizontalPadding;
  CGFloat contentCenterY = CGRectGetMidY(contentRect);

  // 使用统一的画布缩放策略保持文字大小一致
  CGFloat baseFontSize =
      CMWatermarkScaledPointSize(canvasSize, 18.0f, 42.0f);
  UIFont *captionFont = [UIFont systemFontOfSize:baseFontSize
                                          weight:UIFontWeightSemibold];

  // Studio模式、Polaroid模式和Info模式不在此处显示logo
  if (logoDescriptor && logoDescriptor.assetName.length > 0 &&
      !(frameDescriptor &&
        (CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier) ||
         [frameDescriptor.identifier isEqualToString:@"frame.polaroid"] ||
         [frameDescriptor.identifier isEqualToString:@"frame.info"]))) {
    UIImage *logoImage = [self cachedAssetImageNamed:logoDescriptor.assetName];
    if (logoImage) {
      CGFloat maxContentHeight = contentRect.size.height * 0.6f;
      CGFloat logoHeight = CMWatermarkConsistentLogoHeight(
          captionFont.lineHeight, canvasSize, maxContentHeight);
      CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
      CGFloat logoWidth = logoHeight * aspect;

      CGFloat availableLogoWidth =
          CGRectGetMaxX(contentRect) - horizontalPadding - cursorX;
      if (logoWidth > availableLogoWidth && availableLogoWidth > 0.0f) {
        logoWidth = availableLogoWidth;
        logoHeight = logoWidth / MAX(aspect, 0.1f);
      }

      CGRect logoRect = CGRectMake(cursorX, contentCenterY - logoHeight / 2.0,
                                   logoWidth, logoHeight);
      UIImage *renderableLogo =
          [self cachedRenderableLogoForDescriptor:logoDescriptor] ?: logoImage;
      if (logoDescriptor.prefersTemplateRendering) {
        [[UIColor whiteColor] setFill];
        [[UIColor whiteColor] setStroke];
      }
      [renderableLogo drawInRect:logoRect
                       blendMode:kCGBlendModeNormal
                           alpha:0.95];
      cursorX = CGRectGetMaxX(logoRect) + horizontalPadding * 0.6;
    }
  }

  CGFloat availableWidth =
      CGRectGetMaxX(contentRect) - horizontalPadding - cursorX;
  if (availableWidth <= 0) {
    return;
  }

  NSMutableParagraphStyle *captionParagraph =
      [[NSMutableParagraphStyle alloc] init];
  captionParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

  // 根据相框类型选择文本颜色
  UIColor *textColor = [UIColor whiteColor];
  if (frameDescriptor &&
      CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier)) {
    textColor = [UIColor blackColor]; // Studio模式使用黑色文字
  }

  NSDictionary *captionAttributes = @{
    NSFontAttributeName : captionFont,
    NSForegroundColorAttributeName : textColor,
    NSParagraphStyleAttributeName : captionParagraph
  };

  // Studio模式和Polaroid模式不在此处显示caption文字
  NSString *captionText = @"";
  CGRect captionRect = CGRectZero;
  if (frameDescriptor &&
      !CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier) &&
      ![frameDescriptor.identifier isEqualToString:@"frame.polaroid"]) {
    captionText =
        (configuration.isCaptionEnabled && configuration.captionText.length)
            ? configuration.captionText
            : @"";
    captionRect =
        CGRectMake(cursorX, contentCenterY - captionFont.lineHeight * 0.6,
                   availableWidth, captionFont.lineHeight);
    if (captionText.length > 0) {
      [captionText drawInRect:captionRect withAttributes:captionAttributes];
    }
  }

  // 宝丽来模式始终显示布局，不依赖detailString
  if (frameDescriptor &&
      [frameDescriptor.identifier isEqualToString:@"frame.polaroid"]) {
    // Polaroid模式使用3行布局：logo, 文字, 参数
    [self drawPolaroidLayoutInRect:contentRect
                     configuration:configuration
                    logoDescriptor:logoDescriptor
                      detailString:detailString ?: @""
                        canvasSize:canvasSize
                 horizontalPadding:horizontalPadding];
  } else if (frameDescriptor &&
             [frameDescriptor.identifier isEqualToString:@"frame.info"]) {
    // Info模式使用专门的布局：设备机型、时间、logo、参数、GPS坐标
    [self drawInfoLayoutInRect:contentRect
                 configuration:configuration
                logoDescriptor:logoDescriptor
                  detailString:detailString ?: @""
                    canvasSize:canvasSize
             horizontalPadding:horizontalPadding
                      metadata:metadata];
  } else if ((frameDescriptor &&
              CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier)) ||
             detailString.length > 0) {
    // 对于Studio模式，使用专门的参数布局
    if (frameDescriptor &&
        CMIsStudioLikeFrameIdentifier(frameDescriptor.identifier)) {
      NSString *studioDetailString = [self exposureStringFromMetadata:metadata];
      if (studioDetailString.length == 0) {
        studioDetailString = detailString;
      }
      [self drawStudioParametersInRect:contentRect
                          detailString:studioDetailString
                            canvasSize:canvasSize];
    } else {
      // 其他相框模式使用原有样式
      UIFont *detailFont = [UIFont systemFontOfSize:baseFontSize * 0.55
                                             weight:UIFontWeightMedium];
      NSMutableParagraphStyle *detailParagraph =
          [[NSMutableParagraphStyle alloc] init];
      detailParagraph.lineBreakMode = NSLineBreakByTruncatingTail;
      UIColor *detailTextColor =
          [[UIColor whiteColor] colorWithAlphaComponent:0.85];

      NSDictionary *detailAttributes = @{
        NSFontAttributeName : detailFont,
        NSForegroundColorAttributeName : detailTextColor,
        NSParagraphStyleAttributeName : detailParagraph
      };
      CGFloat detailBaselineY =
          captionText.length > 0
              ? CGRectGetMaxY(captionRect) + (6.0 * CMWatermarkUIScaleFactor)
              : (contentCenterY - detailFont.lineHeight * 0.5);
      CGRect detailRect = CGRectMake(cursorX, detailBaselineY, availableWidth,
                                     detailFont.lineHeight);
      [detailString drawInRect:detailRect withAttributes:detailAttributes];
    }
  }

  // 署名功能已完全删除
  // if (configuration.isSignatureEnabled && configuration.signatureText.length
  // > 0 &&
  //     !(frameDescriptor && [frameDescriptor.identifier
  //     isEqualToString:@"frame.studio"])) { UIFont *signatureFont = [UIFont
  //     italicSystemFontOfSize:baseFontSize * 0.6]; UIColor *signatureColor =
  //     [UIColor whiteColor]; if (frameDescriptor &&
  //     [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
  //         signatureColor = [UIColor blackColor];
  //     }
  //     NSDictionary *signatureAttributes = @{
  //         NSFontAttributeName: signatureFont,
  //         NSForegroundColorAttributeName: [signatureColor
  //         colorWithAlphaComponent:0.9]
  //     };
  //     CGSize signatureSize = [configuration.signatureText
  //     sizeWithAttributes:signatureAttributes]; CGFloat signatureX =
  //     CGRectGetMaxX(contentRect) - horizontalPadding - signatureSize.width;
  //     CGFloat signatureY = contentCenterY - signatureSize.height / 2.0;
  //     CGRect signatureRect = CGRectMake(MAX(signatureX, cursorX + 20.0),
  //     signatureY, signatureSize.width, signatureSize.height);
  //     [configuration.signatureText drawInRect:signatureRect
  //     withAttributes:signatureAttributes];
  // }
}

- (void)drawInlineWatermarkOnPhotoInContext:
            (UIGraphicsImageRendererContext *)context
                                 canvasSize:(CGSize)canvasSize
                              configuration:
                                  (CMWatermarkConfiguration *)configuration
                             logoDescriptor:
                                 (CMWatermarkLogoDescriptor *_Nullable)
                                     logoDescriptor
                               detailString:(NSString *)detailString {
  BOOL hasCaption =
      configuration.isCaptionEnabled && configuration.captionText.length > 0;
  BOOL hasDetail = detailString.length > 0;
  BOOL hasLogoAsset = (configuration.logoEnabled && logoDescriptor &&
                       logoDescriptor.assetName.length > 0);

  if (!hasCaption && !hasDetail && !hasLogoAsset) {
    return;
  }

  const CGFloat horizontalMargin = MAX(canvasSize.width * 0.05f, 40.0f);
  const CGFloat verticalInset = MAX(canvasSize.height * 0.06f, 80.0f);

  // 使用统一的画布缩放策略，保持不同来源照片的水印观感一致
  CGFloat baseFontSize =
      CMWatermarkScaledPointSize(canvasSize, 12.0f, 42.0f);
  CGFloat inlineAdaptiveScale = CMWatermarkInlineAdaptiveScale(canvasSize);
  baseFontSize *= inlineAdaptiveScale;
  UIFont *captionFont = [UIFont fontWithName:configuration.textFontName
                                        size:baseFontSize];
  if (!captionFont) {
    captionFont = [UIFont systemFontOfSize:baseFontSize
                                    weight:UIFontWeightSemibold];
  }
  CGFloat detailPointSize =
      MAX(10.0f * CMWatermarkUIScaleFactor, baseFontSize * 0.58f);
  UIFont *detailFont =
      [UIFont systemFontOfSize:detailPointSize weight:UIFontWeightMedium];
  const CGFloat lineSpacing = baseFontSize * 0.35f;

  NSTextAlignment textAlignment = NSTextAlignmentCenter;
  switch (configuration.watermarkAnchor) {
    case CMWatermarkAnchorTopLeft:
    case CMWatermarkAnchorBottomLeft:
      textAlignment = NSTextAlignmentLeft;
      break;
    case CMWatermarkAnchorTopRight:
    case CMWatermarkAnchorBottomRight:
      textAlignment = NSTextAlignmentRight;
      break;
    case CMWatermarkAnchorCenter:
    case CMWatermarkAnchorBottomCenter:
      textAlignment = NSTextAlignmentCenter;
      break;
  }

  NSMutableParagraphStyle *textParagraph = [[NSMutableParagraphStyle alloc] init];
  textParagraph.alignment = textAlignment;
  textParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

  CGFloat rendererScale = 1.0f;
  if ([context.format isKindOfClass:[UIGraphicsImageRendererFormat class]]) {
    rendererScale =
        MAX(((UIGraphicsImageRendererFormat *)context.format).scale, 1.0f);
  } else {
    rendererScale = MAX([UIScreen mainScreen].scale, 1.0f);
  }

  NSShadow *textShadow = [[NSShadow alloc] init];
  textShadow.shadowOffset = CGSizeMake(0.0f, 2.0f / rendererScale);
  textShadow.shadowBlurRadius = 4.0f / rendererScale;
  textShadow.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.6f];

  NSDictionary * (^fillAttributesForFont)(UIFont *) =
      ^NSDictionary *(UIFont *font) {
        return @{
          NSFontAttributeName : font,
          NSForegroundColorAttributeName : [UIColor whiteColor],
          NSParagraphStyleAttributeName : textParagraph,
          NSShadowAttributeName : textShadow
        };
      };

  NSMutableArray<NSDictionary<NSString *, id> *> *lines =
      [NSMutableArray array];
  if (hasCaption) {
    [lines addObject:@{
      @"text" : configuration.captionText,
      @"font" : captionFont
    }];
  }
  if (hasDetail) {
    [lines addObject:@{
      @"text" : detailString,
      @"font" : detailFont,
      @"detail" : @YES
    }];
  }

  UIImage *logoImage = nil;
  CGFloat logoHeight = 0.0f;
  CGFloat logoWidth = 0.0f;
  if (hasLogoAsset) {
    logoImage = [self cachedAssetImageNamed:logoDescriptor.assetName];
    if (!logoImage) {
      hasLogoAsset = NO;
    } else {
      CGFloat maxContentHeight = canvasSize.height * 0.3f;
      CGFloat targetLogoHeight =
          CMWatermarkConsistentLogoHeight(captionFont.lineHeight, canvasSize,
                                          maxContentHeight);
      targetLogoHeight *= inlineAdaptiveScale;
      CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
      logoHeight = targetLogoHeight;
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

  CGFloat startY = canvasSize.height - verticalInset - blockHeight;
  if (configuration.watermarkAnchor == CMWatermarkAnchorTopLeft ||
      configuration.watermarkAnchor == CMWatermarkAnchorTopRight) {
    startY = verticalInset;
  } else if (configuration.watermarkAnchor == CMWatermarkAnchorCenter) {
    startY = (canvasSize.height - blockHeight) * 0.5f;
  }
  CGFloat minimumTop = MAX(horizontalMargin, canvasSize.height * 0.08f);
  startY = MAX(startY, minimumTop);

  CGFloat currentY = startY;
  CGFloat anchorX = horizontalMargin;
  CGFloat availableWidth = canvasSize.width - horizontalMargin * 2.0f;
  if (availableWidth <= 0.0f) {
    availableWidth = canvasSize.width;
    anchorX = 0.0f;
  }
  if (configuration.watermarkAnchor == CMWatermarkAnchorTopRight ||
      configuration.watermarkAnchor == CMWatermarkAnchorBottomRight) {
    anchorX = canvasSize.width - horizontalMargin - availableWidth;
  } else if (configuration.watermarkAnchor == CMWatermarkAnchorCenter ||
             configuration.watermarkAnchor == CMWatermarkAnchorBottomCenter) {
    anchorX = (canvasSize.width - availableWidth) * 0.5f;
  }

  if (hasLogoAsset) {
    CGFloat logoX = (canvasSize.width - logoWidth) * 0.5f;
    if (configuration.watermarkAnchor == CMWatermarkAnchorTopLeft ||
        configuration.watermarkAnchor == CMWatermarkAnchorBottomLeft) {
      logoX = anchorX;
    } else if (configuration.watermarkAnchor == CMWatermarkAnchorTopRight ||
               configuration.watermarkAnchor == CMWatermarkAnchorBottomRight) {
      logoX = CGRectGetMaxX(CGRectMake(anchorX, 0.0f, availableWidth, 0.0f)) - logoWidth;
    }
    CGRect logoRect = CGRectMake(logoX, currentY, logoWidth, logoHeight);
    UIImage *renderableLogo =
        [self cachedRenderableLogoForDescriptor:logoDescriptor] ?: logoImage;
    if (logoDescriptor.prefersTemplateRendering) {
      [[UIColor whiteColor] setFill];
      [[UIColor whiteColor] setStroke];
    }
    [renderableLogo drawInRect:logoRect
                     blendMode:kCGBlendModeNormal
                         alpha:0.95f];
    currentY = CGRectGetMaxY(logoRect);
    if (lines.count > 0) {
      currentY += lineSpacing;
    }
  }

  for (NSUInteger index = 0; index < lines.count; index++) {
    NSString *text = lines[index][@"text"];
    UIFont *font = lines[index][@"font"];
    BOOL isDetailLine = [lines[index][@"detail"] boolValue];
    if (text.length == 0 || !font) {
      continue;
    }
    NSDictionary *fillAttributes = fillAttributesForFont(font);
    CGRect lineRect =
        CGRectMake(anchorX, currentY, availableWidth, font.lineHeight);
    if (isDetailLine && [text containsString:@"|"]) {
      BOOL isHasselbladInlineMode =
          hasLogoAsset &&
          [logoDescriptor.identifier hasPrefix:@"logo.hasselblad"];
      UIColor *labelColor = isHasselbladInlineMode
                                ? [UIColor colorWithRed:208.0 / 255.0
                                                  green:208.0 / 255.0
                                                   blue:208.0 / 255.0
                                                  alpha:1.0] // #D0D0D0
                                : [UIColor colorWithRed:199.0 / 255.0
                                                  green:201.0 / 255.0
                                                   blue:200.0 / 255.0
                                                  alpha:1.0];
      UIColor *valueColor = isHasselbladInlineMode
                                ? [UIColor colorWithRed:245.0 / 255.0
                                                  green:245.0 / 255.0
                                                   blue:245.0 / 255.0
                                                  alpha:1.0] // #F5F5F5
                                : [UIColor whiteColor];
      NSMutableParagraphStyle *paragraph =
          [[NSMutableParagraphStyle alloc] init];
      paragraph.alignment = textAlignment;
      paragraph.lineBreakMode = NSLineBreakByTruncatingTail;

      NSDictionary *labelAttributes = @{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : labelColor,
        NSParagraphStyleAttributeName : paragraph,
        NSShadowAttributeName : textShadow
      };
      NSDictionary *valueAttributes = @{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : valueColor,
        NSParagraphStyleAttributeName : paragraph,
        NSShadowAttributeName : textShadow
      };
      NSDictionary *separatorAttributes = @{
        NSFontAttributeName : font,
        NSForegroundColorAttributeName : labelColor,
        NSParagraphStyleAttributeName : paragraph,
        NSShadowAttributeName : textShadow
      };

      NSArray<NSString *> *components =
          [text componentsSeparatedByString:@"    "];
      NSMutableAttributedString *formatted =
          [[NSMutableAttributedString alloc] init];
      for (NSUInteger idx = 0; idx < components.count; idx++) {
        NSString *component = components[idx];
        NSArray<NSString *> *parts =
            [component componentsSeparatedByString:@"|"];
        NSString *label =
            parts.count > 0
                ? [parts[0] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]]
                : @"";
        NSString *value =
            parts.count > 1
                ? [parts[1] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]]
                : @"";

        if (idx > 0) {
          NSAttributedString *separator =
              [[NSAttributedString alloc] initWithString:@"    "
                                              attributes:separatorAttributes];
          [formatted appendAttributedString:separator];
        }

        if (label.length > 0) {
          NSString *labelText = [NSString stringWithFormat:@"%@ | ", label];
          [formatted
              appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:labelText
                                             attributes:labelAttributes]];
        }
        if (value.length > 0) {
          [formatted
              appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:value
                                             attributes:valueAttributes]];
        }
      }

      if (formatted.length > 0) {
        [formatted drawInRect:lineRect];
      } else {
        [text drawInRect:lineRect withAttributes:fillAttributes];
      }
    } else {
      [text drawInRect:lineRect withAttributes:fillAttributes];
    }
    currentY = CGRectGetMaxY(lineRect);
    if (index < lines.count - 1) {
      currentY += lineSpacing;
    }
  }
}

- (NSString *)supplementaryStringForConfiguration:
                  (CMWatermarkConfiguration *)configuration
                                         metadata:
                                             (NSDictionary *_Nullable)metadata
                                       inlineMode:(BOOL)inlineMode {
  NSMutableArray<NSString *> *components = [NSMutableArray array];
  CMWatermarkMetadataOptions options = configuration.metadataOptions;

  if (options == CMWatermarkMetadataOptionsNone) {
    if (configuration.preferenceOptions != CMWatermarkPreferenceOptionsNone) {
      if (configuration.preferenceOptions &
          CMWatermarkPreferenceOptionsExposure) {
        options |= (CMWatermarkMetadataOptionsLens |
                    CMWatermarkMetadataOptionsShutter |
                    CMWatermarkMetadataOptionsAperture);
      }
      if (configuration.preferenceOptions &
          CMWatermarkPreferenceOptionsCoordinates) {
        options |= CMWatermarkMetadataOptionsLocation;
      }
      if (configuration.preferenceOptions &
          CMWatermarkPreferenceOptionsDate) {
        options |= CMWatermarkMetadataOptionsDate;
      }
    } else {
      switch (configuration.preference) {
      case CMWatermarkPreferenceExposure:
        options |= (CMWatermarkMetadataOptionsLens |
                    CMWatermarkMetadataOptionsShutter |
                    CMWatermarkMetadataOptionsAperture);
        break;
      case CMWatermarkPreferenceCoordinates:
        options |= CMWatermarkMetadataOptionsLocation;
        break;
      case CMWatermarkPreferenceDate:
        options |= CMWatermarkMetadataOptionsDate;
        break;
      case CMWatermarkPreferenceOff:
      default:
        break;
      }
    }
  }

  if (options == CMWatermarkMetadataOptionsNone) {
    return configuration.auxiliaryText ?: @"";
  }

  if (options & CMWatermarkMetadataOptionsLens) {
    NSString *lens = [self lensStringFromMetadata:metadata inline:inlineMode];
    if (lens.length > 0) {
      [components addObject:lens];
    }
  }
  if (options & CMWatermarkMetadataOptionsShutter) {
    NSString *shutter =
        [self shutterStringFromMetadata:metadata inline:inlineMode];
    if (shutter.length > 0) {
      [components addObject:shutter];
    }
  }
  if (options & CMWatermarkMetadataOptionsAperture) {
    NSString *aperture =
        [self apertureStringFromMetadata:metadata inline:inlineMode];
    if (aperture.length > 0) {
      [components addObject:aperture];
    }
  }
  if (options & CMWatermarkMetadataOptionsDate) {
    NSString *date = [self dateStringFromMetadata:metadata];
    if (date.length > 0) {
      [components addObject:(inlineMode
                                 ? [NSString stringWithFormat:@"Date | %@", date]
                                 : date)];
    }
  }
  if (options & CMWatermarkMetadataOptionsLocation) {
    NSString *coordinates = [self coordinateStringFromMetadata:metadata];
    if (coordinates.length > 0) {
      [components addObject:(inlineMode
                                 ? [NSString stringWithFormat:@"Location | %@",
                                                              coordinates]
                                 : coordinates)];
    }
  }

  if (components.count == 0) {
    return configuration.auxiliaryText ?: @"";
  }
  return [components componentsJoinedByString:@"    "];
}

- (NSString *)lensStringFromMetadata:(NSDictionary *)metadata
                              inline:(BOOL)inlineMode {
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  double focalLength = [exif[(NSString *)kCGImagePropertyExifFocalLength]
      doubleValue];
  if (focalLength <= 0.0) {
    focalLength = [exif[(NSString *)kCGImagePropertyExifFocalLenIn35mmFilm]
        doubleValue];
  }
  if (focalLength <= 0.0) {
    return inlineMode ? @"Lens | --mm" : @"-- mm";
  }
  return inlineMode ? [NSString stringWithFormat:@"Lens | %.0fmm", focalLength]
                    : [NSString stringWithFormat:@"%.0f mm", focalLength];
}

- (NSString *)apertureStringFromMetadata:(NSDictionary *)metadata
                                  inline:(BOOL)inlineMode {
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  double fNumber = [exif[(NSString *)kCGImagePropertyExifFNumber] doubleValue];
  if (fNumber <= 0.0) {
    double apertureValue =
        [exif[(NSString *)kCGImagePropertyExifApertureValue] doubleValue];
    if (apertureValue > 0.0) {
      fNumber = pow(2.0, apertureValue / 2.0);
    }
  }
  if (fNumber <= 0.0) {
    return inlineMode ? @"Aperture | --" : @"-- F";
  }
  return inlineMode ? [NSString stringWithFormat:@"Aperture | f/%.1f", fNumber]
                    : [NSString stringWithFormat:@"%.1f F", fNumber];
}

- (NSString *)shutterStringFromMetadata:(NSDictionary *)metadata
                                 inline:(BOOL)inlineMode {
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  double exposureTime =
      [exif[(NSString *)kCGImagePropertyExifExposureTime] doubleValue];
  if (exposureTime <= 0.0) {
    double shutterSpeedValue =
        [exif[(NSString *)kCGImagePropertyExifShutterSpeedValue] doubleValue];
    if (shutterSpeedValue != 0.0) {
      exposureTime = 1.0 / pow(2.0, shutterSpeedValue);
    }
  }

  NSString *formatted = @"--";
  if (exposureTime > 0.0) {
    if (exposureTime >= 1.0) {
      formatted = [NSString stringWithFormat:@"%.1fs", exposureTime];
    } else {
      formatted = [NSString stringWithFormat:@"1/%.0fs",
                                             round(1.0 / exposureTime)];
    }
  }

  if (inlineMode) {
    return [NSString stringWithFormat:@"Shutter | %@", formatted];
  }
  return [formatted stringByReplacingOccurrencesOfString:@"s"
                                              withString:@" S"];
}

- (NSString *)exposureStringFromMetadata:(NSDictionary *)metadata {
  return [self exposureStringFromMetadata:metadata inline:NO];
}

- (NSString *)inlineExposureStringFromMetadata:(NSDictionary *)metadata {
  return [self exposureStringFromMetadata:metadata inline:YES];
}

- (NSString *)exposureStringFromMetadata:(NSDictionary *)metadata
                                  inline:(BOOL)inlineMode {
  if (!metadata) {
    if (inlineMode) {
      NSString *testParams =
          @"Aperture | f/2.8    Shutter | 1/60s    ISO | 800";
      return testParams;
    }
    return @"800 ISO    2.8 F    24 mm    1/60 S";
  }
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  if (!exif) {
    if (inlineMode) {
      return @"Aperture | f/1.8    Shutter | 1/125s    ISO | 1600";
    }
    return @"1600 ISO    1.8 F    50 mm    1/125 S";
  }

  double fNumber = [exif[(NSString *)kCGImagePropertyExifFNumber] doubleValue];
  if (fNumber <= 0.0) {
    double apertureValue =
        [exif[(NSString *)kCGImagePropertyExifApertureValue] doubleValue];
    if (apertureValue > 0.0) {
      fNumber = pow(2.0, apertureValue / 2.0);
    }
  }

  double focalLength =
      [exif[(NSString *)kCGImagePropertyExifFocalLength] doubleValue];
  if (focalLength <= 0.0) {
    double focalLength35 =
        [exif[(NSString *)kCGImagePropertyExifFocalLenIn35mmFilm] doubleValue];
    if (focalLength35 > 0.0) {
      focalLength = focalLength35;
    }
  }

  double exposureTime =
      [exif[(NSString *)kCGImagePropertyExifExposureTime] doubleValue];
  if (exposureTime <= 0.0) {
    double shutterSpeedValue =
        [exif[(NSString *)kCGImagePropertyExifShutterSpeedValue] doubleValue];
    if (shutterSpeedValue != 0.0) {
      exposureTime = 1.0 / pow(2.0, shutterSpeedValue);
    }
  }

  NSArray *isoArray = exif[(NSString *)kCGImagePropertyExifISOSpeedRatings];
  NSInteger isoValue = [[isoArray firstObject] integerValue];
  if (isoValue <= 0) {
    isoValue =
        [exif[(NSString *)kCGImagePropertyExifExposureIndex] integerValue];
  }

  NSString * (^trimmedDecimalString)(NSString *) =
      ^NSString *(NSString *value) {
        NSString *result = value;
        while ([result containsString:@"."] && [result hasSuffix:@"0"] &&
               result.length > 0) {
          result = [result substringToIndex:result.length - 1];
        }
        if ([result hasSuffix:@"."]) {
          result = [result substringToIndex:result.length - 1];
        }
        return result;
      };

  if (inlineMode) {
    NSString *apertureValue = @"--";
    if (fNumber > 0.0) {
      NSString *raw = [NSString stringWithFormat:@"%.1f", fNumber];
      raw = trimmedDecimalString(raw);
      apertureValue = [NSString stringWithFormat:@"f/%@", raw];
    }

    NSString *shutterValue = @"--";
    if (exposureTime > 0.0) {
      if (exposureTime >= 1.0) {
        NSString *raw = [NSString stringWithFormat:@"%.1f", exposureTime];
        raw = trimmedDecimalString(raw);
        shutterValue = [raw stringByAppendingString:@"s"];
      } else {
        double denominator = round(1.0 / exposureTime);
        if (!isfinite(denominator) || denominator <= 1.0) {
          NSString *raw = [NSString stringWithFormat:@"%.2f", exposureTime];
          raw = trimmedDecimalString(raw);
          shutterValue = [raw stringByAppendingString:@"s"];
        } else {
          shutterValue = [NSString stringWithFormat:@"1/%.0fs", denominator];
        }
      }
    }

    NSString *isoValueString =
        isoValue > 0 ? [NSString stringWithFormat:@"%ld", (long)isoValue]
                     : @"--";

    NSArray<NSString *> *components = @[
      [NSString stringWithFormat:@"Aperture | %@", apertureValue],
      [NSString stringWithFormat:@"Shutter | %@", shutterValue],
      [NSString stringWithFormat:@"ISO | %@", isoValueString]
    ];
    return [components componentsJoinedByString:@"    "];
  }

  NSString *isoString =
      isoValue > 0 ? [NSString stringWithFormat:@"%ld ISO", (long)isoValue]
                   : @"-- ISO";
  NSString *fString =
      fNumber > 0.0 ? [NSString stringWithFormat:@"%.1f F", fNumber] : @"-- F";
  NSString *focalString =
      focalLength > 0.0 ? [NSString stringWithFormat:@"%.0f mm", focalLength]
                        : @"-- mm";

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

  return [@[ isoString, fString, focalString, shutterString ]
      componentsJoinedByString:@"    "];
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
  double longitude =
      [gps[(NSString *)kCGImagePropertyGPSLongitude] doubleValue];
  if (latitude == 0.0 && longitude == 0.0) {
    // 测试数据：如果GPS坐标为0，返回示例坐标
    return @"N 22.3964°, E 114.1095°"; // 香港坐标示例
  }
  NSString *latRef = gps[(NSString *)kCGImagePropertyGPSLatitudeRef]
                         ?: (latitude >= 0.0 ? @"N" : @"S");
  NSString *lonRef = gps[(NSString *)kCGImagePropertyGPSLongitudeRef]
                         ?: (longitude >= 0.0 ? @"E" : @"W");
  return [NSString stringWithFormat:@"%@ %.4f°, %@ %.4f°", latRef,
                                    fabs(latitude), lonRef, fabs(longitude)];
}

- (NSString *)dateStringFromMetadata:(NSDictionary *)metadata {
  if (!metadata) {
    return [self.dateFormatter stringFromDate:[NSDate date]];
  }
  NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
  NSString *timestampString =
      exif[(NSString *)kCGImagePropertyExifDateTimeOriginal];
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
  // 使用统一缩放策略，确保不同分辨率下的参数字体大小一致
  CGFloat parameterFontSize =
      CMWatermarkScaledPointSize(canvasSize, 48.0f, 96.0f);
  parameterFontSize = MIN(parameterFontSize, contentRect.size.height * 0.85f);
  UIFont *parameterValueFont = [UIFont systemFontOfSize:parameterFontSize
                                                 weight:UIFontWeightSemibold];
  UIFont *parameterLabelFont = [UIFont systemFontOfSize:parameterFontSize * 0.65
                                                 weight:UIFontWeightMedium];

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
        CGFloat labelY = valueY + parameterValueFont.lineHeight +
                         (4.0 * CMWatermarkUIScaleFactor);

        // 绘制数值 - 居中对齐
        NSDictionary *valueAttributes = @{
          NSFontAttributeName : parameterValueFont,
          NSForegroundColorAttributeName : valueColor,
          NSParagraphStyleAttributeName : [[NSParagraphStyle alloc] init]
        };
        CGSize valueSize = [value sizeWithAttributes:valueAttributes];
        CGFloat valueX = centerX - (valueSize.width * 0.5);
        CGRect valueRect =
            CGRectMake(valueX, valueY, valueSize.width, valueSize.height);
        [value drawInRect:valueRect withAttributes:valueAttributes];

        // 绘制单位 - 居中对齐
        NSDictionary *labelAttributes = @{
          NSFontAttributeName : parameterLabelFont,
          NSForegroundColorAttributeName : labelColor,
          NSParagraphStyleAttributeName : [[NSParagraphStyle alloc] init]
        };
        CGSize labelSize = [unit sizeWithAttributes:labelAttributes];
        CGFloat labelX = centerX - (labelSize.width * 0.5);
        CGRect labelRect =
            CGRectMake(labelX, labelY, labelSize.width, labelSize.height);
        [unit drawInRect:labelRect withAttributes:labelAttributes];
      }
    }
  }
}

- (CGRect)aspectFillRectForImageSize:(CGSize)imageSize
                      inBoundingRect:(CGRect)boundingRect {
  if (imageSize.width <= 0.0 || imageSize.height <= 0.0 ||
      CGRectIsEmpty(boundingRect)) {
    return boundingRect;
  }
  CGFloat widthScale = boundingRect.size.width / imageSize.width;
  CGFloat heightScale = boundingRect.size.height / imageSize.height;
  CGFloat scale = MAX(widthScale, heightScale);
  CGSize scaledSize =
      CGSizeMake(imageSize.width * scale, imageSize.height * scale);
  CGFloat originX = CGRectGetMidX(boundingRect) - scaledSize.width / 2.0;
  CGFloat originY = CGRectGetMidY(boundingRect) - scaledSize.height / 2.0;
  return CGRectMake(originX, originY, scaledSize.width, scaledSize.height);
}

- (void)drawPolaroidLayoutInRect:(CGRect)contentRect
                   configuration:(CMWatermarkConfiguration *)configuration
                  logoDescriptor:
                      (CMWatermarkLogoDescriptor *_Nullable)logoDescriptor
                    detailString:(NSString *)detailString
                      canvasSize:(CGSize)canvasSize
               horizontalPadding:(CGFloat)horizontalPadding {

  CGFloat availableHeight = contentRect.size.height;
  if (availableHeight <= 0.0) {
    return;
  }

  BOOL hasCaption =
      configuration.isCaptionEnabled && configuration.captionText.length > 0;
  BOOL hasDetail = detailString.length > 0;

  UIImage *logoImage = nil;
  BOOL hasLogo = NO;
  if (logoDescriptor && logoDescriptor.assetName.length > 0) {
    logoImage = [self cachedAssetImageNamed:logoDescriptor.assetName];
    hasLogo = (logoImage != nil);
  }

  CGFloat minimumOuterMargin = MAX(availableHeight * 0.04, 12.0);
  minimumOuterMargin =
      MIN(minimumOuterMargin, availableHeight * 0.25); // clamp relative margin
  CGFloat usableHeight = availableHeight - minimumOuterMargin * 2.0;
  if (usableHeight <= 0.0) {
    usableHeight = availableHeight;
    minimumOuterMargin = MAX(availableHeight * 0.02, 4.0);
  }

  CGFloat baseLogoHeight = hasLogo ? availableHeight * 0.24 : 0.0;
  CGFloat baseLogoSpacing =
      (hasLogo && (hasCaption || hasDetail)) ? availableHeight * 0.05 : 0.0;
  CGFloat baseTextHeight = hasCaption ? availableHeight * 0.18 : 0.0;
  CGFloat baseTextSpacing =
      (hasCaption && hasDetail) ? availableHeight * 0.045 : 0.0;
  CGFloat baseParameterHeight = hasDetail ? availableHeight * 0.22 : 0.0;

  const CGFloat polaroidContentScale = 0.8f;
  baseLogoHeight *= polaroidContentScale;
  baseLogoSpacing *= polaroidContentScale;
  baseTextHeight *= polaroidContentScale;
  baseTextSpacing *= polaroidContentScale;
  baseParameterHeight *= polaroidContentScale;

  CGFloat baselineSum = baseLogoHeight + baseLogoSpacing + baseTextHeight +
                        baseTextSpacing + baseParameterHeight;
  CGFloat compression =
      baselineSum > 0.0 ? MIN(1.0, usableHeight / baselineSum) : 1.0;

  CGFloat logoHeight = baseLogoHeight * compression;
  CGFloat logoSpacing = baseLogoSpacing * compression;
  CGFloat textBlockHeight = baseTextHeight * compression;
  CGFloat textSpacing = baseTextSpacing * compression;
  CGFloat parameterHeight = baseParameterHeight * compression;

  CGFloat totalContentHeight = 0.0;
  if (hasLogo && logoHeight > 0.0) {
    totalContentHeight += logoHeight;
    if (logoSpacing > 0.0) {
      totalContentHeight += logoSpacing;
    }
  }
  BOOL hasTextBlock = (hasCaption && textBlockHeight > 0.0);
  if (hasTextBlock) {
    totalContentHeight += textBlockHeight;
  }
  BOOL hasParameters = (hasDetail && parameterHeight > 0.0);
  if (hasParameters) {
    if (textSpacing > 0.0 && hasTextBlock) {
      totalContentHeight += textSpacing;
    }
    totalContentHeight += parameterHeight;
  }
  if (totalContentHeight <= 0.0) {
    return;
  }

  CGFloat currentY = contentRect.origin.y +
                     (contentRect.size.height - totalContentHeight) * 0.5f;
  CGFloat minStartY = contentRect.origin.y + minimumOuterMargin;
  CGFloat maxStartY =
      CGRectGetMaxY(contentRect) - totalContentHeight - minimumOuterMargin;
  if (minStartY <= maxStartY) {
    currentY = MIN(MAX(currentY, minStartY), maxStartY);
  } else {
    currentY = MAX(contentRect.origin.y, currentY);
  }

  CGFloat availableWidth = contentRect.size.width - horizontalPadding * 2.0;
  if (availableWidth <= 0.0) {
    availableWidth = contentRect.size.width;
  }

  if (hasLogo && logoHeight > 0.0) {
    CGFloat aspect = logoImage.size.width / MAX(logoImage.size.height, 1.0f);
    CGFloat logoWidth = logoHeight * aspect;
    if (logoWidth > availableWidth) {
      CGFloat widthScale = availableWidth / logoWidth;
      logoWidth = availableWidth;
      logoHeight *= widthScale;
    }
    CGFloat logoX =
        contentRect.origin.x + (contentRect.size.width - logoWidth) / 2.0;
    CGRect logoRect = CGRectMake(logoX, currentY, logoWidth, logoHeight);

    UIImage *renderableLogo =
        [self cachedRenderableLogoForDescriptor:logoDescriptor] ?: logoImage;
    if (logoDescriptor.prefersTemplateRendering) {
      [[UIColor blackColor] setFill];
      [[UIColor blackColor] setStroke];
    }
    [renderableLogo drawInRect:logoRect
                     blendMode:kCGBlendModeNormal
                         alpha:0.95];
    currentY += logoHeight;
    if (logoSpacing > 0.0) {
      currentY += logoSpacing;
    }
  }

  NSMutableString *combinedText = [NSMutableString string];
  if (hasCaption) {
    [combinedText appendString:configuration.captionText];
  }

  CGFloat textFontSize = 0.0;
  if (combinedText.length > 0 && textBlockHeight > 0.0) {
    textFontSize = MIN(textBlockHeight * 0.82, availableHeight * 0.18);
    textFontSize = MAX(textFontSize, 28.0);
    UIFont *textFont = [UIFont systemFontOfSize:textFontSize
                                         weight:UIFontWeightMedium];
    UIColor *textColor = [UIColor blackColor];

    NSMutableParagraphStyle *textParagraph =
        [[NSMutableParagraphStyle alloc] init];
    textParagraph.alignment = NSTextAlignmentCenter;
    textParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *textAttributes = @{
      NSFontAttributeName : textFont,
      NSForegroundColorAttributeName : textColor,
      NSParagraphStyleAttributeName : textParagraph
    };

    CGFloat drawY =
        currentY + MAX(0.0, (textBlockHeight - textFont.lineHeight) / 2.0);
    CGRect textRect = CGRectMake(
        contentRect.origin.x + horizontalPadding, drawY,
        contentRect.size.width - 2.0 * horizontalPadding, textFont.lineHeight);
    [combinedText drawInRect:textRect withAttributes:textAttributes];
    currentY += textBlockHeight;
  }

  if (hasDetail && parameterHeight > 0.0) {
    if (textSpacing > 0.0 && currentY < CGRectGetMaxY(contentRect)) {
      currentY += textSpacing;
    }
    CGFloat parameterFontSize =
        MAX(20.0, MIN(parameterHeight * 0.6,
                      (textFontSize > 0.0 ? textFontSize * 0.75
                                          : availableHeight * 0.12)));
    CGRect parameterRect = CGRectMake(contentRect.origin.x, currentY,
                                      contentRect.size.width, parameterHeight);
    [self drawPolaroidParametersInRect:parameterRect
                          detailString:detailString
                            canvasSize:canvasSize
                     parameterFontSize:parameterFontSize];
  }
}

- (void)drawPolaroidParametersInRect:(CGRect)rect
                        detailString:(NSString *)detailString
                          canvasSize:(CGSize)canvasSize
                   parameterFontSize:(CGFloat)parameterFontSize {
  UIFont *parameterFont = [UIFont systemFontOfSize:parameterFontSize
                                            weight:UIFontWeightMedium];
  UIColor *parameterColor = [UIColor colorWithRed:102.0 / 255.0
                                            green:102.0 / 255.0
                                             blue:102.0 / 255.0
                                            alpha:1.0]; // #666666

  NSMutableParagraphStyle *parameterParagraph =
      [[NSMutableParagraphStyle alloc] init];
  parameterParagraph.alignment = NSTextAlignmentCenter;
  parameterParagraph.lineBreakMode = NSLineBreakByTruncatingTail;

  NSDictionary *parameterAttributes = @{
    NSFontAttributeName : parameterFont,
    NSForegroundColorAttributeName : parameterColor,
    NSParagraphStyleAttributeName : parameterParagraph
  };

  // 将参数字符串分解并水平排列
  NSString *trimmed = [detailString
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if (trimmed.length == 0) {
    return;
  }

  NSArray *components = [trimmed componentsSeparatedByString:@"    "];
  if (components.count > 0) {
    NSString *displayText = [components componentsJoinedByString:@"  •  "];

    CGFloat horizontalPadding = rect.size.width * 0.05;
    CGRect parameterRect = CGRectMake(
        rect.origin.x + horizontalPadding,
        rect.origin.y + (rect.size.height - parameterFont.lineHeight) / 2.0,
        rect.size.width - 2 * horizontalPadding, parameterFont.lineHeight);
    [displayText drawInRect:parameterRect withAttributes:parameterAttributes];
  }
}

- (void)drawInfoLayoutInRect:(CGRect)contentRect
               configuration:(CMWatermarkConfiguration *)configuration
              logoDescriptor:
                  (CMWatermarkLogoDescriptor *_Nullable)logoDescriptor
                detailString:(NSString *)detailString
                  canvasSize:(CGSize)canvasSize
           horizontalPadding:(CGFloat)horizontalPadding
                    metadata:(NSDictionary *_Nullable)metadata {

  NSLog(@"🔍 Info布局调试 - detailString: '%@', preference: %ld",
        detailString ?: @"(nil)", (long)configuration.preference);
  NSLog(@"📏 字体大小调试 - 画布尺寸: %.0fx%.0f, 底部区域: %.0fx%.0f",
        canvasSize.width, canvasSize.height, contentRect.size.width,
        contentRect.size.height);

  CGFloat layoutScale = CMWatermarkCanvasScaleForSize(canvasSize);

  CGFloat primaryFontSize =
      CMWatermarkScaledPointSize(canvasSize, 24.0f, 48.0f);
  if (contentRect.size.height > 0.0f) {
    primaryFontSize =
        MIN(primaryFontSize, contentRect.size.height * 0.45f);
  }
  UIFont *primaryFont = [UIFont systemFontOfSize:primaryFontSize
                                          weight:UIFontWeightSemibold];

  CGFloat secondaryFontSize =
      MAX(primaryFontSize * 0.82f, 28.0f * layoutScale);
  secondaryFontSize = MIN(secondaryFontSize, primaryFontSize * 0.92f);
  UIFont *secondaryFont = [UIFont systemFontOfSize:secondaryFontSize
                                            weight:UIFontWeightMedium];

  CGFloat textSpacing =
      MAX(primaryFont.lineHeight * 0.32f, 18.0f * layoutScale);
  CGFloat logoHeight = CMWatermarkConsistentLogoHeight(
      primaryFont.lineHeight, canvasSize, contentRect.size.height * 0.6f);

  NSLog(@"📏 字体大小调试 - baseFontSize: %.1f, primaryFontSize: %.1f, "
        @"secondaryFontSize: %.1f, logoHeight: %.1f",
        primaryFont.pointSize, primaryFontSize, secondaryFontSize,
        logoHeight);

  UIColor *blackColor = [UIColor blackColor];
  UIColor *grayColor = [UIColor colorWithRed:102.0 / 255.0
                                       green:102.0 / 255.0
                                        blue:102.0 / 255.0
                                       alpha:1.0];

  // 重新计算所有内容的总高度 - 确保包含文字的实际高度
  CGFloat textContentHeight =
      primaryFont.lineHeight + textSpacing + secondaryFont.lineHeight;
  CGFloat totalContentHeight = MAX(textContentHeight, logoHeight);

  // 确保内容块在底部区域垂直居中 - 使用更精确的计算
  CGFloat availableHeight = contentRect.size.height;
  CGFloat contentStartY =
      contentRect.origin.y + (availableHeight - totalContentHeight) / 2.0;
  CGFloat contentCenterY = contentStartY + totalContentHeight / 2.0;

  NSLog(@"📏 垂直居中调试 - 文字内容高度: %.1f, 总内容高度: %.1f, 可用高度: "
        @"%.1f, 开始Y: %.1f, 中心Y: %.1f",
        textContentHeight, totalContentHeight, availableHeight, contentStartY,
        contentCenterY);

  // 左侧区域：设备型号和时间
  NSString *deviceModel = [self deviceModelString];
  NSString *dateString = [self dateStringFromMetadata:metadata];

  // 计算左侧文字的实际宽度（自适应）
  NSDictionary *deviceAttributes = @{
    NSFontAttributeName : primaryFont,
    NSForegroundColorAttributeName : blackColor
  };
  NSDictionary *dateAttributes = @{
    NSFontAttributeName : secondaryFont,
    NSForegroundColorAttributeName : grayColor
  };

  CGSize deviceSize = [deviceModel sizeWithAttributes:deviceAttributes];
  CGSize dateSize = [dateString sizeWithAttributes:dateAttributes];
  CGFloat leftMaxWidth = MAX(deviceSize.width, dateSize.width);

  // 计算左侧内容的垂直居中位置 - 使用统一的contentStartY并向上调整
  CGFloat leftContentHeight =
      primaryFont.lineHeight + textSpacing + secondaryFont.lineHeight;
  // 向上调整偏移量，让内容更居中
  CGFloat verticalOffset = contentRect.size.height * 0.7; // 向上偏移10%
  CGFloat leftStartY = contentStartY - verticalOffset;

  // 绘制设备型号（上行）- 使用自适应宽度
  CGRect deviceRect =
      CGRectMake(contentRect.origin.x + horizontalPadding, leftStartY,
                 leftMaxWidth, primaryFont.lineHeight);
  [deviceModel drawInRect:deviceRect withAttributes:deviceAttributes];

  // 绘制时间（下行）- 使用自适应宽度
  CGRect dateRect =
      CGRectMake(contentRect.origin.x + horizontalPadding,
                 leftStartY + primaryFont.lineHeight + textSpacing,
                 leftMaxWidth, secondaryFont.lineHeight);
  [dateString drawInRect:dateRect withAttributes:dateAttributes];

  // 右侧区域：参数和GPS坐标
  if (detailString.length > 0) {
    NSLog(@"📊 绘制参数信息: '%@'", detailString);

    NSString *gpsString = [self coordinateStringFromMetadata:metadata];

    // 计算右侧文字的实际宽度（自适应）
    NSDictionary *paramAttributes = @{
      NSFontAttributeName : primaryFont,
      NSForegroundColorAttributeName : blackColor,
      NSParagraphStyleAttributeName : ({
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSTextAlignmentRight;
        style;
      })
    };
    NSDictionary *gpsAttributes = @{
      NSFontAttributeName : secondaryFont,
      NSForegroundColorAttributeName : grayColor,
      NSParagraphStyleAttributeName : ({
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSTextAlignmentRight;
        style;
      })
    };

    CGSize paramSize = [detailString sizeWithAttributes:paramAttributes];
    CGSize gpsSize = [gpsString sizeWithAttributes:gpsAttributes];
    CGFloat rightMaxWidth = MAX(paramSize.width, gpsSize.width);

    // 计算右侧内容的垂直居中位置 -
    // 使用统一的contentStartY并向上调整，与左侧保持一致
    CGFloat rightStartY = contentStartY - verticalOffset;

    NSLog(@"📏 垂直居中修复调试 - 左侧StartY: %.1f, 右侧StartY: %.1f, "
          @"向上偏移: %.1f, 可用高度: %.1f",
          leftStartY, rightStartY, verticalOffset, contentRect.size.height);

    // 计算右侧区域的位置（从右边开始布局）- 使用自适应宽度
    CGFloat rightX = contentRect.origin.x + contentRect.size.width -
                     horizontalPadding - rightMaxWidth;

    // 绘制参数（上行）- 使用自适应宽度
    CGRect paramRect =
        CGRectMake(rightX, rightStartY, rightMaxWidth, primaryFont.lineHeight);
    NSLog(@"📊 参数绘制区域: %@", NSStringFromCGRect(paramRect));
    [detailString drawInRect:paramRect withAttributes:paramAttributes];

    // 绘制GPS坐标（下行）- 使用自适应宽度
    CGRect gpsRect =
        CGRectMake(rightX, rightStartY + primaryFont.lineHeight + textSpacing,
                   rightMaxWidth, secondaryFont.lineHeight);
    [gpsString drawInRect:gpsRect withAttributes:gpsAttributes];

    // Logo绘制 - 紧靠右侧参数左边，垂直居中并向上调整
    if (logoDescriptor && logoDescriptor.assetName.length > 0) {
      UIImage *logoImage = [self cachedAssetImageNamed:logoDescriptor.assetName];
      if (logoImage) {
        CGFloat aspect =
            logoImage.size.width / MAX(logoImage.size.height, 1.0f);
        CGFloat logoWidth = logoHeight * aspect;

        // 灰色分隔线参数
        const CGFloat separatorWidth = 2.0;
        const CGFloat separatorHeight =
            logoHeight * 2;                   // 分隔线高度与logo成比例
        const CGFloat separatorMargin = 88.0; // 分隔线与logo和参数的间距

        // Logo位置：考虑分隔线的位置，垂直居中并向上调整
        CGFloat logoX = rightX - logoWidth - separatorMargin - separatorWidth -
                        separatorMargin;
        CGFloat logoY = contentRect.origin.y +
                        (contentRect.size.height - logoHeight) / 2.0 -
                        verticalOffset;

        CGRect logoRect = CGRectMake(logoX, logoY, logoWidth, logoHeight);

        UIImage *renderableLogo =
            [self cachedRenderableLogoForDescriptor:logoDescriptor] ?: logoImage;
        if (logoDescriptor.prefersTemplateRendering) {
          [[UIColor blackColor] setFill];
          [[UIColor blackColor] setStroke];
        }
        [renderableLogo drawInRect:logoRect
                         blendMode:kCGBlendModeNormal
                             alpha:0.95];

        // 绘制灰色分隔线 - 在logo和参数之间，垂直居中并向上调整
        CGFloat separatorX = logoX + logoWidth + separatorMargin;
        CGFloat separatorY = contentRect.origin.y +
                             (contentRect.size.height - separatorHeight) / 2.0 -
                             verticalOffset;
        CGRect separatorRect =
            CGRectMake(separatorX, separatorY, separatorWidth, separatorHeight);

        [[UIColor colorWithRed:180.0 / 255.0
                         green:180.0 / 255.0
                          blue:180.0 / 255.0
                         alpha:1.0] setFill];
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
  NSString *deviceIdentifier =
      [NSString stringWithCString:systemInfo.machine
                         encoding:NSUTF8StringEncoding];

  // 将设备标识符转换为友好的机型名称
  NSDictionary *deviceNames = @{
    // iPhone 15 系列
    @"iPhone16,1" : @"iPhone 15",
    @"iPhone16,2" : @"iPhone 15 Plus",
    @"iPhone15,4" : @"iPhone 15 Pro",
    @"iPhone15,5" : @"iPhone 15 Pro Max",

    // iPhone 14 系列
    @"iPhone14,7" : @"iPhone 14",
    @"iPhone14,8" : @"iPhone 14 Plus",
    @"iPhone15,2" : @"iPhone 14 Pro",
    @"iPhone15,3" : @"iPhone 14 Pro Max",

    // iPhone 13 系列
    @"iPhone14,5" : @"iPhone 13",
    @"iPhone14,2" : @"iPhone 13 mini",
    @"iPhone14,3" : @"iPhone 13 Pro",
    @"iPhone14,4" : @"iPhone 13 Pro Max",

    // iPhone 12 系列
    @"iPhone13,2" : @"iPhone 12",
    @"iPhone13,1" : @"iPhone 12 mini",
    @"iPhone13,3" : @"iPhone 12 Pro",
    @"iPhone13,4" : @"iPhone 12 Pro Max",

    // 模拟器
    @"x86_64" : @"iPhone Simulator",
    @"arm64" : @"iPhone Simulator"
  };

  NSString *friendlyName = deviceNames[deviceIdentifier];
  return friendlyName ?: deviceIdentifier;
}

@end
