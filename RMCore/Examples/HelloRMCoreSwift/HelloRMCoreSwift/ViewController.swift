//
//  ViewController.swift
//  HelloRMCoreSwift
//
//  Created by Foti Dim on 25.04.20.
//  Copyright © 2020 navideck. All rights reserved.
//

class ViewController: UIViewController, RMCoreDelegate {

    var robot: RMCoreRobotRomo3?

    // UI
    var connectedView: UIView?
    var unconnectedView: UIView?
    var driveInCircleButton = UIButton(type: .roundedRect)
    var tiltUpButton = UIButton(type: .roundedRect)
    var tiltDownButton = UIButton(type: .roundedRect)

    // MARK: -- View Lifecycle --
    override func viewDidLoad() {
        super.viewDidLoad()

        // Assume the Robot is not connected
        layoutForUnconnected()

        // To receive messages when Robots connect & disconnect, set RMCore's delegate to self
        RMCore.setDelegate(self)
    }

    // MARK: -- RMCoreDelegate Methods --
    func robotDidConnect(_ robot: RMCoreRobot) {
        // Currently the only kind of robot is Romo3, which supports all of these
        //  protocols, so this is just future-proofing
        self.robot = robot as? RMCoreRobotRomo3

        // Change the robot's LED to be solid at 80% power
        self.robot?.leds.setSolidWithBrightness(0.8)

        layoutForConnected()
    }

    func robotDidDisconnect(_ robot: RMCoreRobot) {
        if robot == self.robot {
            self.robot = nil

            layoutForUnconnected()
        }
    }

    // MARK: -- IBAction Methods --

    @objc func didTouchDrive(inCircleButton sender: UIButton?) {
        // If the robot is driving, let's stop driving
        if let robot = robot, robot.isDriving {
            // Change the robot's LED to be solid at 80% power
            robot.leds.setSolidWithBrightness(0.8)

            // Tell the robot to stop
            robot.stopDriving()

            sender?.setTitle("Drive in circle", for: .normal)
        } else {
            // Change the robot's LED to pulse
            robot?.leds.pulse(withPeriod: 1.0, direction: RMCoreLEDPulseDirectionUpAndDown)

            // Romo's top speed is around 0.75 m/s
            let speedInMetersPerSecond: Float = 0.5

            // Drive a circle about 0.25 meter in radius
            let radiusInMeters: Float = 0.25

            // Give the robot the drive command
            robot?.drive(withRadius: radiusInMeters, speed: speedInMetersPerSecond)

            sender?.setTitle("Stop Driving", for: .normal)
        }
    }

    @objc func didTouchTiltUpButton(_ sender: UIButton?) {
        // If the robot is tilting, stop tilting
        if let robot = robot, robot.isTilting {

            // Tell the robot to stop tilting
            robot.stopTilting()

            sender?.setTitle("Tilt Up", for: .normal)
        } else {

            sender?.setTitle("Stop", for: .normal)

            // Tilt down by ten degrees
            let tiltByAngleInDegrees: Float = 10.0

            robot?.tilt(byAngle: tiltByAngleInDegrees) { success in
                // Reset button title on the main queue
                DispatchQueue.main.async(execute: {
                    sender?.setTitle("Tilt Up", for: .normal)
                })
            }
        }
    }

    @objc func didTouchTiltDownButton(_ sender: UIButton?) {
        // If the robot is tilting, stop tilting
        if let robot = robot, robot.isTilting {

            // Tell the robot to stop tilting
            robot.stopTilting()

            sender?.setTitle("Tilt Down", for: .normal)
        } else {

            sender?.setTitle("Stop", for: .normal)

            // Tilt up by ten degrees
            let tiltByAngleInDegrees: Float = -10.0

            robot?.tilt(byAngle: tiltByAngleInDegrees) { success in
                // Reset button title on the main queue
                DispatchQueue.main.async(execute: {
                    sender?.setTitle("Tilt Down", for: .normal)
                })
            }
        }
    }

    // MARK: -- Private Methods: Build the UI --

    func layoutForConnected() {
        // Lets make some buttons so we can tell the robot to do stuff
        if connectedView == nil {
            connectedView = UIView(frame: view.bounds)
            connectedView?.backgroundColor = UIColor.white

            driveInCircleButton.frame = CGRect(x: 70, y: 50, width: 180, height: 60)
            driveInCircleButton.setTitle(
                "Drive in circle",
                for: .normal)
            driveInCircleButton.addTarget(
                self,
                action: #selector(didTouchDrive(inCircleButton:)),
                for: .touchUpInside)
            connectedView?.addSubview(driveInCircleButton)

            tiltDownButton.frame = CGRect(x: 70, y: 130, width: 80, height: 60)
            tiltDownButton.setTitle("Tilt Up", for: .normal)
            tiltDownButton.addTarget(self, action: #selector(didTouchTiltUpButton), for: .touchUpInside)
            connectedView?.addSubview(tiltDownButton)

            tiltUpButton.frame = CGRect(x: 170, y: 130, width: 80, height: 60)
            tiltUpButton.setTitle("Tilt Down", for: .normal)
            tiltUpButton.addTarget(self, action: #selector(didTouchTiltDownButton), for: .touchUpInside)
            connectedView?.addSubview(tiltUpButton)
        }
        self.unconnectedView?.removeFromSuperview()
        if let connectedView = connectedView {
            self.view.addSubview(connectedView)
        }
    }

    func layoutForUnconnected() {
        // If we aren't connected to a robotic base, just show a label
        if unconnectedView == nil {
            unconnectedView = UIView(frame: view.bounds)
            unconnectedView?.backgroundColor = UIColor.black

            let notConnectedLabel = UILabel(frame: CGRect(x: 0, y: view.center.y, width: view.frame.size.width, height: 40))
            notConnectedLabel.textAlignment = .center
            notConnectedLabel.text = "Romo Not Connected"
            unconnectedView?.addSubview(notConnectedLabel)
        }

        connectedView?.removeFromSuperview()
        if let unconnectedView = unconnectedView {
            view.addSubview(unconnectedView)
        }
    }

}
