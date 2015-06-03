//
//  RMNormalBayes.h
//  RMVision
//
//  Created on 9/27/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#ifndef __RMVision__RMNormalBayes__
#define __RMVision__RMNormalBayes__

#include <iostream>

class RMNormalBayes : public CvNormalBayesClassifier
{
public:
    int getVarCount()           { return var_count; }
    int getVarAll()             { return var_all; }
    
    CvMat* getVarIdx()          { return var_idx; }
    CvMat* getClsLabels()       { return cls_labels; }          // Class labels
    CvMat** getCount()          { return count; }
    CvMat** getSum()            { return sum; }
    CvMat** getProductSum()     { return productsum; }
    CvMat** getAvg()            { return avg; }
    CvMat** getInvEigenValues() { return inv_eigen_values; }
    CvMat** getCovRotateMats()  { return cov_rotate_mats; }
    CvMat* getC()               { return c; }                   // Log of covariance determinates
    
    
    void print(void);
    
    
};
#endif /* defined(__RMVision__RMNormalBayes__) */



