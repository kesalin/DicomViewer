//
//  KSViewController.m
//  DicomViewer
//
//  Created by LuoZhaohui on 12/30/11.
//  Copyright 2011 LuoZhaohui. All rights reserved.
//  Contact:    kesalin@gmail.com
//              http://blog.csdn.net/kesalin
//

#import "KSViewController.h"
#import "KSDicom2DView.h"
#import "KSDicomDecoder.h"

// KSViewController PrivateMethods
// 
@interface KSViewController(PrivateMethods)

- (void) decodeAndDisplay:(NSString *)path;
- (void) displayWith:(NSInteger)windowWidth windowCenter:(NSInteger)windowCenter;

@end

// KSViewController @implementation
//
@implementation KSViewController

@synthesize dicom2DView;
@synthesize patientName, modality, windowInfo, date;

#pragma mark -
#pragma mark - View lifecycle

- (void) dealloc
{
    [super dealloc];
    
    self.dicom2DView = nil;
    self.patientName = nil;
    self.modality = nil;
    self.windowInfo = nil;
    self.date = nil;
    
    [dicomDecoder release];
    [panGesture release];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // decode and display dicom
    //
    NSString * dicomPath = [[NSBundle mainBundle] pathForResource:@"test" ofType: @"dcm"];
    
    [self decodeAndDisplay:dicomPath];
    
    NSString * info = [dicomDecoder infoFor:PATIENT_NAME];
    self.patientName.text = [NSString stringWithFormat:@"Patient: %@", info];
    
    info = [dicomDecoder infoFor:MODALITY];
    self.modality.text = [NSString stringWithFormat:@"Modality: %@", info];
    
    info = [dicomDecoder infoFor:SERIES_DATE];
    self.date.text = info;
    
    info = [NSString stringWithFormat:@"WW/WL: %d / %d", dicom2DView.winWidth, dicom2DView.winCenter];
    self.windowInfo.text = info;
    
    // Add gesture
    //
    panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.maximumNumberOfTouches = 1;
    [dicom2DView addGestureRecognizer:panGesture];
	[panGesture release];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [dicom2DView removeGestureRecognizer:panGesture];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark -
#pragma mark - Gesture

-(IBAction) handlePanGesture:(UIPanGestureRecognizer *) sender
{
    UIGestureRecognizerState state = [sender state];
    
    if (state == UIGestureRecognizerStateBegan)
    {
        prevTransform = dicom2DView.transform;
        startPoint = [sender locationInView:self.view];
    }
    else if (state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded)
    {

        CGPoint location    = [sender locationInView:self.view];
        CGFloat offsetX     = location.x - startPoint.x;
        CGFloat offsetY     = location.y - startPoint.y;
        startPoint          = location;

#if 0   
        // translate
        //
        CGAffineTransform translate = CGAffineTransformMakeTranslation(offsetX, offsetY);
        dicom2DView.transform  = CGAffineTransformConcat(prevTransform, translate);
#else
        // adjust window width/level
        //
        dicom2DView.winWidth  += offsetX * dicom2DView.changeValWidth;
        dicom2DView.winCenter += offsetY * dicom2DView.changeValCentre;
        
        if (dicom2DView.winWidth <= 0) {
            dicom2DView.winWidth = 1;
        }
        
        if (dicom2DView.winCenter == 0) {
            dicom2DView.winCenter = 1;
        }
        
        if (dicom2DView.signed16Image) {
            dicom2DView.winCenter += SHRT_MIN;
        }
        
        [dicom2DView setWinWidth:dicom2DView.winWidth];
        [dicom2DView setWinCenter:dicom2DView.winCenter];

        [self displayWith:dicom2DView.winWidth windowCenter:dicom2DView.winCenter];
#endif
    }
}

#pragma mark -
#pragma mark - Dicom

- (void) decodeAndDisplay:(NSString *)path
{
    [dicomDecoder release];
    dicomDecoder = [[KSDicomDecoder alloc] init];
    [dicomDecoder setDicomFilename:path];
    
    [self displayWith:dicomDecoder.windowWidth windowCenter:dicomDecoder.windowCenter];
}

- (void) displayWith:(NSInteger)windowWidth windowCenter:(NSInteger)windowCenter
{
    if (!dicomDecoder.dicomFound || !dicomDecoder.dicomFileReadSuccess) 
    {
        [dicomDecoder release];
        dicomDecoder = nil;
        return;
    }

    NSInteger winWidth        = windowWidth;
    NSInteger winCenter       = windowCenter;
    NSInteger imageWidth      = dicomDecoder.width;
    NSInteger imageHeight     = dicomDecoder.height;
    NSInteger bitDepth        = dicomDecoder.bitDepth;
    NSInteger samplesPerPixel = dicomDecoder.samplesPerPixel;
    BOOL signedImage          = dicomDecoder.signedImage;
    
    BOOL needsDisplay = NO;
    
    if (samplesPerPixel == 1 && bitDepth == 8)
    {
        Byte * pixels8 = [dicomDecoder getPixels8];
        
        if (winWidth == 0 && winCenter == 0)
        {
            Byte max = 0, min = 255;
            NSInteger num = imageWidth * imageHeight;
            for (NSInteger i = 0; i < num; i++)
            {
                if (pixels8[i] > max) {
                    max = pixels8[i];
                }
                
                if (pixels8[i] < min) {
                    min = pixels8[i];
                }
            }
            
            winWidth = (NSInteger)((max + min)/2.0 + 0.5);
            winCenter = (NSInteger)((max - min)/2.0 + 0.5);
        }
        
        [dicom2DView setPixels8:pixels8
                          width:imageWidth
                         height:imageHeight
                    windowWidth:winWidth
                   windowCenter:winCenter
                samplesPerPixel:samplesPerPixel
                    resetScroll:YES];
        
        needsDisplay = YES;
    }
    
    if (samplesPerPixel == 1 && bitDepth == 16)
    {
        ushort * pixels16 = [dicomDecoder getPixels16];
        
        if (winWidth == 0 || winCenter == 0)
        {
            ushort max = 0, min = 65535;
            NSInteger num = imageWidth * imageHeight;
            for (NSInteger i = 0; i < num; i++)
            {
                if (pixels16[i] > max) {
                    max = pixels16[i];
                }
                
                if (pixels16[i] < min) {
                    min = pixels16[i];
                }
            }
            
            winWidth = (NSInteger)((max + min)/2.0 + 0.5);
            winCenter = (NSInteger)((max - min)/2.0 + 0.5);
        }
        
        dicom2DView.signed16Image = signedImage;
        
        [dicom2DView setPixels16:pixels16
                           width:imageWidth
                          height:imageHeight
                     windowWidth:winWidth
                    windowCenter:winCenter
                 samplesPerPixel:samplesPerPixel
                     resetScroll:YES];
        
        needsDisplay = YES;
    }
    
    if (samplesPerPixel == 3 && bitDepth == 8)
    {
        Byte * pixels24 = [dicomDecoder getPixels24];
        
        if (winWidth == 0 || winCenter == 0)
        {
            Byte max = 0, min = 255;
            NSInteger num = imageWidth * imageHeight * 3;
            for (NSInteger i = 0; i < num; i++)
            {
                if (pixels24[i] > max) {
                    max = pixels24[i];
                }
                
                if (pixels24[i] < min) {
                    min = pixels24[i];
                }
            }
            
            winWidth = (max + min)/2 + 0.5;
            winCenter = (max - min)/2 + 0.5;
        }
        
        [dicom2DView setPixels8:pixels24
                          width:imageWidth
                         height:imageHeight
                    windowWidth:winWidth
                   windowCenter:winCenter
                samplesPerPixel:samplesPerPixel
                    resetScroll:YES];
        
        needsDisplay = YES;
    }
    
    if (needsDisplay)
    {
        CGFloat x = (self.view.frame.size.width - imageWidth) /2;
        CGFloat y = (self.view.frame.size.height - imageHeight) /2;
        dicom2DView.frame = CGRectMake(x, y, imageWidth, imageHeight);
        [dicom2DView setNeedsDisplay];
        
        NSString * info = [NSString stringWithFormat:@"WW/WL: %d / %d", dicom2DView.winWidth, dicom2DView.winCenter];
        self.windowInfo.text = info;
    }
}

@end
