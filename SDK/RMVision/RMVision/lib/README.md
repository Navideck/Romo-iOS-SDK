## RMVision Library Generation
#### November 12, 2013

![Romotive Logo](http://romotive.com/img/hero_developers.png)

OpenCV
--------
To generate a new OpenCV framework, follow the directions here:

[http://docs.opencv.org/doc/tutorials/introduction/ios_install/ios_install.html](http://docs.opencv.org/doc/tutorials/introduction/ios_install/ios_install.html)

NOTE: For iOS6 devices, I was getting a crash if I didn't set `IPHONEOS_DEPLOYMENT_TARGET=6.0` in the python script. I set the following:

`os.system("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=6.0 -parallelizeTargets ARCHS=%s -jobs 8 -sdk %s -configuration Release -target ALL_BUILD" % (arch, target.lower()))
os.system("xcodebuild IPHONEOS_DEPLOYMENT_TARGET=6.0 ARCHS=%s -sdk %s -configuration Release -target install install" % (arch, target.lower()))`

See [http://stackoverflow.com/questions/17553332/using-custom-built-opencv-for-ios-on-xcode-produces-sincos-stret-undefined-sy](http://stackoverflow.com/questions/17553332/using-custom-built-opencv-for-ios-on-xcode-produces-sincos-stret-undefined-sy)


Replace the old opencv2.framework folder with the new one that you have generated. You might have to rename the new folder.