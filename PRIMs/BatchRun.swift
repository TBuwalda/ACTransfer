//
//  BatchRun.swift
//  PRIMs
//
//  Created by Niels Taatgen on 5/22/15.
//  Copyright (c) 2015 Niels Taatgen. All rights reserved.
//

import Foundation


class BatchRun {
    let batchScript: String
    let outputFileName: NSURL
    var model: Model
    unowned let mainModel: Model
    unowned let controller: MainViewController
    let directory: NSURL
    var progress: Double = 0.0
    var traceFileName: NSURL
    var activationTraceFileName: NSURL
    
    init(script: String, mainModel: Model, outputFile: NSURL, controller: MainViewController, directory: NSURL) {
        self.batchScript = script
        self.outputFileName = outputFile
        self.traceFileName = outputFile.URLByDeletingPathExtension!.URLByAppendingPathExtension("tracedat")
        self.activationTraceFileName = outputFile.URLByDeletingPathExtension!.URLByAppendingPathExtension("activitydat")
        self.model = Model(batchMode: true)
        self.controller = controller
        self.directory = directory
        self.mainModel = mainModel
    }
    

    
    func runScript() {
        mainModel.clearTrace()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) { () -> Void in

        var scanner = NSScanner(string: self.batchScript)
        let whiteSpaceAndNL = NSMutableCharacterSet.whitespaceAndNewlineCharacterSet()
        _ = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
        let numberOfRepeats = scanner.scanInt()
        if numberOfRepeats == nil {
            self.mainModel.addToTraceField("Illegal number of repeats")
            return
        }
        var newfile = true
        for i in 0..<numberOfRepeats! {
            self.mainModel.addToTraceField("Run #\(i + 1)")
            dispatch_async(dispatch_get_main_queue()) {
                self.controller.updateAllViews()
            }
            scanner = NSScanner(string: self.batchScript)
            
            while let command = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL) {
                var stopByTime = false
                switch command {
                case "run-time":
                    stopByTime = true
                    fallthrough
                case "run":
                    let taskname = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
                    if taskname == nil {
                        self.mainModel.addToTraceField("Illegal task name in run")
                        return
                    }
                    let taskLabel = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
                    if taskLabel == nil {
                        self.mainModel.addToTraceField("Illegal task label in run")
                        return
                    }
                    let endCriterium = scanner.scanDouble()
                    if endCriterium == nil {
                        self.mainModel.addToTraceField("Illegal number of trials or end time in run")
                        return
                    }
                    
                    while !scanner.atEnd && (scanner.string as NSString).characterAtIndex(scanner.scanLocation) != 10 && (scanner.string as NSString).characterAtIndex(scanner.scanLocation) != 13 {
                        let batchParam = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
                        self.model.batchParameters.append(batchParam!)
                        self.mainModel.addToTraceField("Parameter: \(batchParam!)")
                    }
                
                    if stopByTime {
                        self.mainModel.addToTraceField("Running task \(taskname!) with label \(taskLabel!) for \(endCriterium!) seconds")
                    } else {
                        self.mainModel.addToTraceField("Running task \(taskname!) with label \(taskLabel!) for \(endCriterium!) trials")
                    }
                    dispatch_async(dispatch_get_main_queue()) {
                        self.controller.updateAllViews()
                    }
                    var tasknumber = self.model.findTask(taskname!)
                    if tasknumber == nil {
                        let taskPath = self.directory.URLByAppendingPathComponent(taskname! + ".prims")
                        print("Trying to load \(taskPath)")
                        if !self.model.loadModelWithString(taskPath) {
                            self.mainModel.addToTraceField("Task \(taskname!) is not loaded nor can it be found")
                            return
                        }
                        tasknumber = self.model.findTask(taskname!)
                    }
                    if tasknumber == nil {
                        self.mainModel.addToTraceField("Task \(taskname!) cannot be found")
                        return
                    }
                    self.model.loadOrReloadTask(tasknumber!)
                    var j = 0
                    let startTime = self.model.time
                    while (!stopByTime && j < Int(endCriterium!)) || (stopByTime && (self.model.time - startTime) < endCriterium!) {
                        j += 1
//                    for j in 0..<numberOfTrials! {
//                        print("Trial #\(j)")
                        self.model.run()
                        var output: String = ""
                        for line in self.model.outputData {
                            output += "\(i) \(taskname!) \(taskLabel!) \(j) \(line.time) \(line.eventType) \(line.eventParameter1) \(line.eventParameter2) \(line.eventParameter3) "
                            for item in line.inputParameters {
                                output += item + " "
                            }
                            output += "\n"
                        }
                        // Print trace to file
                        var traceOutput = ""
                        if self.model.batchTrace {
                            for (time, type, event) in self.model.batchTraceData {
                                traceOutput += "\(i) \(taskname!) \(taskLabel!) \(j) \(time) \(type) \(event) \n"
                            }
                            self.model.batchTraceData = []
                        }
                        
                        // Print activition trace to file
                        var activationTraceOutput = ""
                        if self.model.activationTrace {
                            for (time, chunk, activation) in self.model.activationTraceData {
                                activationTraceOutput += "\(i) \(taskname!) \(taskLabel!) \(j) \(time) \(chunk) \(activation) \n"
                            }
                            self.model.activationTraceData = []
                        }
                        
                        if !newfile {
                            // Output File
                            if NSFileManager.defaultManager().fileExistsAtPath(self.outputFileName.path!) {
                                var err:NSError?
                                do {
                                    let fileHandle = try NSFileHandle(forWritingToURL: self.outputFileName)
                                    fileHandle.seekToEndOfFile()
                                    let data = output.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                                    fileHandle.writeData(data!)
                                    fileHandle.closeFile()
                                } catch let error as NSError {
                                    err = error
                                    self.mainModel.addToTraceField("Can't open fileHandle \(err)")
                                }
                            }
                            // Trace File
                            if NSFileManager.defaultManager().fileExistsAtPath(self.traceFileName.path!) && self.model.batchTrace {
                                var err:NSError?
                                do {
                                    let fileHandle = try NSFileHandle(forWritingToURL: self.traceFileName)
                                    fileHandle.seekToEndOfFile()
                                    let data = traceOutput.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                                    fileHandle.writeData(data!)
                                    fileHandle.closeFile()
                                } catch let error as NSError {
                                    err = error
                                    self.mainModel.addToTraceField("Can't open trace fileHandle \(err)")
                                }
                            }
                            
                            // Activation Trace File
                            if NSFileManager.defaultManager().fileExistsAtPath(self.activationTraceFileName.path!) && self.model.activationTrace {
                                var err:NSError?
                                do {
                                    let fileHandle = try NSFileHandle(forWritingToURL: self.activationTraceFileName)
                                    fileHandle.seekToEndOfFile()
                                    let data = activationTraceOutput.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                                    fileHandle.writeData(data!)
                                    fileHandle.closeFile()
                                } catch let error as NSError {
                                    err = error
                                    self.mainModel.addToTraceField("Can't open activation trace fileHandle \(err)")
                                }
                            }
                        } else {
                            newfile = false
                            var err:NSError?
                            // Output file
                            do {
                                try output.writeToURL(self.outputFileName, atomically: false, encoding: NSUTF8StringEncoding)
                            } catch let error as NSError {
                                err = error
                                self.mainModel.addToTraceField("Can't write datafile \(err)")
                            }
                            // Trace file
                            do {
                                try traceOutput.writeToURL(self.traceFileName, atomically: false, encoding: NSUTF8StringEncoding)
                            } catch let error as NSError {
                                err = error
                                self.mainModel.addToTraceField("Can't write tracefile \(err)")
                            }
                            
                            // Activation Trace file
                            do {
                                try traceOutput.writeToURL(self.activationTraceFileName, atomically: false, encoding: NSUTF8StringEncoding)
                            } catch let error as NSError {
                                err = error
                                self.mainModel.addToTraceField("Can't write activation tracefile \(err)")
                            }
                        }
                    }
                case "reset":
                    self.mainModel.addToTraceField("Resetting models")
                    dispatch_async(dispatch_get_main_queue()) {
                        self.controller.updateAllViews()
                    }
                    print("*** About to reset model ***")
                    self.model.dm = nil
                    self.model.procedural = nil
                    self.model.action = nil
                    self.model.operators = nil
                    self.model.action = nil
                    self.model.imaginal = nil
                    self.model.batchParameters = []
                    self.model = Model(batchMode: true)
                case "repeat":
                    scanner.scanInt()
                case "done": break
//                    print("*** Model has finished running ****")
                case "load-image":
                    let filename = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
                    if filename == nil {
                        self.mainModel.addToTraceField("Illegal task name in run")
                        return
                    }
                    let taskPath = self.directory.URLByAppendingPathComponent(filename! + ".brain").path
                    self.mainModel.addToTraceField("Loading image file \(taskPath!)")
                    guard let m = (NSKeyedUnarchiver.unarchiveObjectWithFile(taskPath!) as? Model) else { return }
                    self.model = m
                    self.model.dm.reintegrateChunks()
                    self.model.batchMode = true
                case "save-image":
                    let filename = scanner.scanUpToCharactersFromSet(whiteSpaceAndNL)
                    if filename == nil {
                        self.mainModel.addToTraceField("Illegal task name in run")
                        return
                    }
                    let taskPath = self.directory.URLByAppendingPathComponent(filename! + ".brain").path
                    self.mainModel.addToTraceField("Saving image to file \(taskPath!)")
                    NSKeyedArchiver.archiveRootObject(self.model, toFile: taskPath!)
                default: break
                    
                }
            }
            self.mainModel.addToTraceField("Done")
            dispatch_async(dispatch_get_main_queue()) {
                self.controller.updateAllViews()
            }
            self.progress = 100 * (Double(i) + 1) / Double(numberOfRepeats!)
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName("progress",object: nil)
            }
            }
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName("progress",object: nil)
            }
        }

        
    }

    
}