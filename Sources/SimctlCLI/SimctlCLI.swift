//
//  SimctlCLI.swift
//
//
//  Created by Christian Treffs on 18.03.20.
//

import ArgumentParser
import Foundation
import Logging
import ShellOut
import SimctlShared
import Swifter

/// **SimctlCLI**
///
/// A command line interface to run a server accepting remote commands from your app to execute locally.
///
public class SimctlCLI {
    let server: SimctlServer
    let log: Logger

    static let instance = SimctlCLI()

    public init() {
        log = Logger(label: "com.simctl.cli")
        server = SimctlServer()

        server.onPushNotification { [unowned self] deviceId, bundleId, pushContent -> Result<String, Error> in
            let cmd: ShellOutCommand = .simctlPush(to: deviceId,
                                                   pushContent: pushContent,
                                                   bundleIdentifier: bundleId)

            return self.runCommand(cmd)
        }

        server.onPrivacy { [unowned self] deviceId, bundleId, action, service -> Result<String, Error> in
            let cmd: ShellOutCommand = .simctlPrivacy(action,
                                                      permissionsFor: service,
                                                      on: deviceId,
                                                      bundleIdentifier: bundleId)

            return self.runCommand(cmd)
        }
    }

    deinit {
        server.stop()
    }

    func listDevices() -> [SimulatorDevice] {
        do {
            let devicesJSONString = try shellOut(to: .simctlList(.devices, true))
            let devicesData: Data = devicesJSONString.data(using: .utf8)!
            let decoder = JSONDecoder()
            let listing = try decoder.decode(SimulatorDeviceListing.self, from: devicesData)
            return listing.devices
        } catch {
            log.error("\(error)")
            return []
        }
    }

    func runCommand(_ cmd: ShellOutCommand) -> Result<String, Error> {
        do {
            log.info("Executing '\(cmd)'")
            let output: String = try shellOut(to: cmd)
            return .success(output)
        } catch {
            log.error("\(error)")
            return .failure(error)
        }
    }
}

// MARK: - CLI Commands

struct Simctl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simctl",
        abstract: "Run simulator controls easily and trigger remote push notifications from your app.",
        subcommands: [
            StartServer.self,
            ListDevices.self
        ])

    struct StartServer: ParsableCommand {
        @Option(default: 8080, help: "The port to run the server on.")
        var port: SimctlShared.Port

        func run() throws {
            SimctlCLI.instance.server.startServer(on: port)
        }
    }

    struct ListDevices: ParsableCommand {
        func run() throws {
            let devices = SimctlCLI.instance.listDevices()
            print("\(devices.map { $0.description }.sorted().joined(separator: "\n"))")
        }
    }
}
