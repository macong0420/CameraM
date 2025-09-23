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
#import <math.h>

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
            if (!frameDescriptor.allowsParameterEditing && frameDescriptor.enforcedPreferenceRawValue != NSNotFound) {
                effectiveConfiguration.preference = (CMWatermarkPreference)frameDescriptor.enforcedPreferenceRawValue;
            }
        }

        CMWatermarkLogoDescriptor *logoDescriptor = nil;
        if (effectiveConfiguration.logoEnabled) {
            logoDescriptor = [CMWatermarkCatalog logoDescriptorForIdentifier:effectiveConfiguration.logoIdentifier ?: CMWatermarkLogoIdentifierNone];
        }
        const CGFloat baseWidth = image.size.width;
        const CGFloat baseHeight = image.size.height;
        const CGFloat bottomPadding = MAX(0.0, frameDescriptor.bottomExpansionRatio * baseWidth);
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
            
            // 对于Studio模式，使用白色背景，否则使用黑色
            if ([frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
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

            // 对于Studio模式，使用sign_b保持比例显示在底部区域一半高度
            if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"] && bottomPadding > 0.0) {
                if (frameDescriptor.backgroundAssetName.length > 0) {
                    UIImage *background = [UIImage imageNamed:frameDescriptor.backgroundAssetName];
                    if (background) {
                        // sign_b高度为底部区域的四分之一，保持原始比例
                        CGFloat signBHeight = bottomPadding * 0.25;
                        CGFloat originalAspectRatio = background.size.width / background.size.height;
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
                        CGFloat centerY = baseHeight + (bottomPadding - finalHeight) / 2.0 - 150.0;
                        CGRect backgroundRect = CGRectMake(centerX, centerY, finalWidth, finalHeight);
                        [background drawInRect:backgroundRect blendMode:kCGBlendModeNormal alpha:1.0];
                    }
                }
                
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

    // Studio模式不显示logo
    if (logoDescriptor && logoDescriptor.assetName.length > 0 && 
        !(frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"])) {
        UIImage *logoImage = [UIImage imageNamed:logoDescriptor.assetName];
        if (logoImage) {
            CGFloat maxLogoHeight = MIN(contentRect.size.height * 0.6, 140.0);
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

    CGFloat baseFontSize = MAX(18.0, MIN(42.0, canvasSize.width * 0.035));
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

    // Studio模式不显示caption文字
    NSString *captionText = @"";
    CGRect captionRect = CGRectZero;
    if (frameDescriptor && ![frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
        captionText = (configuration.isCaptionEnabled && configuration.captionText.length) ? configuration.captionText : @"";
        captionRect = CGRectMake(cursorX, contentCenterY - captionFont.lineHeight * 0.6, availableWidth, captionFont.lineHeight);
        if (captionText.length > 0) {
            [captionText drawInRect:captionRect withAttributes:captionAttributes];
        }
    }

    NSString *detailString = [self supplementaryStringForConfiguration:configuration metadata:metadata];
    if (detailString.length > 0) {
        // 对于Studio模式，使用特殊的参数显示样式
        if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
            [self drawStudioParametersInRect:contentRect 
                                detailString:detailString 
                                  canvasSize:canvasSize];
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
            CGFloat detailBaselineY = captionText.length > 0 ? CGRectGetMaxY(captionRect) + 6.0 : (contentCenterY - detailFont.lineHeight * 0.5);
            CGRect detailRect = CGRectMake(cursorX, detailBaselineY, availableWidth, detailFont.lineHeight);
            [detailString drawInRect:detailRect withAttributes:detailAttributes];
        }
    }

    // Studio模式不显示signature
    if (configuration.isSignatureEnabled && configuration.signatureText.length > 0 &&
        !(frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"])) {
        UIFont *signatureFont = [UIFont italicSystemFontOfSize:baseFontSize * 0.6];
        UIColor *signatureColor = [UIColor whiteColor];
        if (frameDescriptor && [frameDescriptor.identifier isEqualToString:@"frame.studio"]) {
            signatureColor = [UIColor blackColor];
        }
        NSDictionary *signatureAttributes = @{
            NSFontAttributeName: signatureFont,
            NSForegroundColorAttributeName: [signatureColor colorWithAlphaComponent:0.9]
        };
        CGSize signatureSize = [configuration.signatureText sizeWithAttributes:signatureAttributes];
        CGFloat signatureX = CGRectGetMaxX(contentRect) - horizontalPadding - signatureSize.width;
        CGFloat signatureY = contentCenterY - signatureSize.height / 2.0;
        CGRect signatureRect = CGRectMake(MAX(signatureX, cursorX + 20.0), signatureY, signatureSize.width, signatureSize.height);
        [configuration.signatureText drawInRect:signatureRect withAttributes:signatureAttributes];
    }
}

- (NSString *)supplementaryStringForConfiguration:(CMWatermarkConfiguration *)configuration
                                         metadata:(NSDictionary * _Nullable)metadata {
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
    if (!metadata) {
        return @"";
    }
    NSDictionary *exif = metadata[(NSString *)kCGImagePropertyExifDictionary];
    if (!exif) {
        return @"";
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
        return @"";
    }
    NSDictionary *gps = metadata[(NSString *)kCGImagePropertyGPSDictionary];
    if (!gps) {
        return @"";
    }
    double latitude = [gps[(NSString *)kCGImagePropertyGPSLatitude] doubleValue];
    double longitude = [gps[(NSString *)kCGImagePropertyGPSLongitude] doubleValue];
    if (latitude == 0.0 && longitude == 0.0) {
        return @"";
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
    // 参数字体样式 - 扩大3倍
    CGFloat parameterFontSize = MAX(48.0, MIN(96.0, canvasSize.width * 0.075)); // 原来的3倍大小
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
                CGFloat labelY = valueY + parameterValueFont.lineHeight + 4.0;
                
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

@end
