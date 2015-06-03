//
//  RMNormalBayes.cpp
//  RMVision
//
//  Created on 9/27/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#include "RMNormalBayes.h"

using namespace std;

void RMNormalBayes::print()
{
    
    cout << "Printing summary of normal bayes model:" << endl << endl;
    
    int numClasses = cls_labels->cols;
    cout << "numClasses: " << numClasses << endl;
    
    cout << "Classes:" << endl;
    cout << cv::Mat(cls_labels).t() << endl;
    
    cout << "Log Det Covariance:" << endl;
    //    cout << cv::Mat(c).t() << endl;
    cout << cv::format(cv::Mat(c).t(), "C") << endl;
    
    
    int numFeatures = avg[0]->cols;
    cout << "numFeatures: " << numFeatures << endl;
    
    for (int i = 0; i < numClasses; i++)
    {
        cout << "Means values for Class: " << i << endl;
        //        cout << cv::Mat(avg[i]).t() << endl;
        cout << cv::format(cv::Mat(avg[i]).t() , "C") << endl;
        
        
        
        cout << "Inverse covariance for Class: " << i << endl;
        
        cv::Mat inv_w = cv::Mat(inv_eigen_values[i]);
        
        cv::Mat u = cv::Mat(cov_rotate_mats[i]);
        cout << "u:" << endl;
        cout << u << endl;
        
        cout << "inv_w" << endl;
        cout << inv_w << endl;
        
        cout << "w" << endl;
        cv::Mat w = 1.0/inv_w;
        cout << cv::Mat::diag(w) << endl;
        
        
        cv::Mat covar = u.t()*cv::Mat::diag(w)*u;
        
        cout << "Normal covar" << endl;
        cout << covar << endl;
        
        cout << "Inverse covar" << endl;
        cout << cv::format(covar.inv(), "C") << endl;
        
    }
    
    
}