//
//  Shell.swift
//  swiftcov
//
//  Created by Kishikawa Katsumi on 2015-05-24.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import Foundation
import Commandant
import Result

public typealias TerminationStatus = Int32

public class Shell {
    var commandPath: String
    var arguments: [String]
    var workingDirectoryPath: String?
    var environment: [String: String]?

    var outputString = ""

    public init(commandPath: String, arguments: [String] = [], workingDirectoryPath: String? = nil, environment: [String: String]? = nil) {
        self.commandPath = commandPath
        self.arguments = arguments
        self.workingDirectoryPath = workingDirectoryPath
        self.environment = environment
    }

    public func run() -> Result<(), Int32> {
        let task = createTask()
        task.launch()
        task.waitUntilExit()

        if task.terminationStatus == EXIT_SUCCESS {
            return .success()
        } else {
            return .failure(task.terminationStatus)
        }
    }

    public func output() -> Result<String, TerminationStatus> {
        let task = createTask()

        let pipe = NSPipe()
        task.standardOutput = pipe

        let result = launchTask(task, pipe: pipe)
        return result
    }

    public func combinedOutput() -> Result<String, TerminationStatus> {
        let task = createTask()

        let pipe = NSPipe()
        task.standardOutput = pipe
        task.standardError = pipe

        let result = launchTask(task, pipe: pipe)
        return result
    }

    private func createTask() -> NSTask {
        let task = NSTask()
        task.setValue(false, forKey: "startsNewProcessGroup")
        task.launchPath = commandPath
        task.arguments = arguments
        if let workingDirectoryPath = workingDirectoryPath {
            task.currentDirectoryPath = workingDirectoryPath
        }
        if let environment = environment {
            task.environment = environment
        }
        return task
    }

    private func launchTask(task: NSTask, pipe: NSPipe) -> Result<String, TerminationStatus> {
        if task.standardOutput.fileHandleForReading != nil {
            task.standardOutput.fileHandleForReading.readabilityHandler = { fileHandle in
                if let string = NSString(data: fileHandle.availableData, encoding: NSUTF8StringEncoding) {
                    fputs("\(string)", stdout)
                    self.outputString += string as String
                }
            }
        }
        if task.standardError.fileHandleForReading != nil {
            task.standardError.fileHandleForReading.readabilityHandler = { fileHandle in
                if let string = NSString(data: fileHandle.availableData, encoding: NSUTF8StringEncoding) {
                    fputs("\(string)", stderr)
                    self.outputString += string as String
                }
            }
        }

        task.launch()
        task.waitUntilExit()

        if task.terminationStatus == EXIT_SUCCESS {
            return .success(outputString)
        } else {
            return .failure(task.terminationStatus)
        }
    }
}