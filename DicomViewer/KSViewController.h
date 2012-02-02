//
//  KSViewController.h
//  DicomViewer
//
//  Created by LuoZhaohui on 12/30/11.
//  Copyright 2011 LuoZhaohui. All rights reserved.
//  Contact:    kesalin@gmail.com
//              http://blog.csdn.net/kesalin
//

#import <UIKit/UIKit.h>

@class KSDicom2DView;
@class KSDicomDecoder;

@interface KSViewController : UIViewController
{
    KSDicom2DView   *dicom2DView;
    KSDicomDecoder  *dicomDecoder;
    
    UILabel * patientName;
    UILabel * modality;
    UILabel * windowInfo;
    UILabel * date;
    
    UIPanGestureRecognizer *panGesture;
    CGAffineTransform prevTransform;
    CGPoint startPoint;
}

@property (nonatomic, retain) IBOutlet KSDicom2DView *dicom2DView;
@property (nonatomic, retain) IBOutlet UILabel * patientName;
@property (nonatomic, retain) IBOutlet UILabel * modality;
@property (nonatomic, retain) IBOutlet UILabel * windowInfo;
@property (nonatomic, retain) IBOutlet UILabel * date;

@end
