#!/bin/bash

if [ ! -f ./face.mov ]; then
curl -O http://macau.romotive.com/bitbucket/VisionUnitTestData/face.mov
fi

if [ ! -f ./green_ball.mov ]; then
curl -O http://macau.romotive.com/bitbucket/VisionUnitTestData/green_ball.mov
fi

if [ ! -f ./green_ball_isFast_ColorTracking.plist ]; then
curl -O http://macau.romotive.com/bitbucket/VisionUnitTestData/green_ball_isFast_ColorTracking.plist
fi
