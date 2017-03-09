//
//  ScriptFunctions.swift
//  PRIMs
//
//  Created by Niels Taatgen on 1/12/16.
//  Copyright © 2016 Niels Taatgen. All rights reserved.
//

import Foundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


let scriptFunctions: [String:([Factor], Model?) throws -> (result: Factor?, done: Bool)] =
["screen": setScreen,
    "nested-screen": setScreenArray,
    "random": randIntNumber,
    "time": modelTime,
    "run-step": runStep,
    "run-until-action": runUntilAction,
    "run-relative-time": runRelativeTimeOrAction,
    "run-absolute-time": runAbsoluteTimeOrAction,
    "run-until-relative-time-or-action": runRelativeTimeOrAction,
    "run-absolute-time-or-action": runAbsoluteTimeOrAction,
    "print": printArg,
    "trial-end": trialEnd,
    "trial-start": trialStart,
    "data-line": dataLine,
    "issue-reward": issueReward,
    "shuffle": shuffle,
    "length": length,
    "sleep": sleepPrims,
    "set-data-file-field": setDataFileField,
    "last-action": lastAction,
    "add-dm": addDM,
    "set-activation": setActivation,
    "set-sji": setSji,
    "random-string": randomString,
    "sgp": setGlobalParameter,
    "batch-parameters": batchParameters,
    "str-to-int": strToInt,
    "open-jar": openJar,
    "report-memory": reportMemory,
    "imaginal-to-dm": imaginalToDM,
    "set-references": setReferences,
    "select-problem": selectProblem,
    "update-rating": updateRating,
    "fixed-problems": fixedProblems,
    "split-numbers": splitNumbers,
    ]



/// Things that can be set
// model.scenario.nextEventTime: time at which the script continues
// model.scenario.currentScreen: screen we are working on

/**
    Helper function for setScreenArray
*/
func createPRObject(_ f: ScriptArray, sup: PRObject?, model: Model) throws -> PRObject {
    guard f.elements.count > 0 else { throw RunTimeError.errorInFunction("Invalid Screen definition") }
    let name = f.elements[0].firstTerm.factor.description
    var i = 1
    var attributes: [String] = [name]
    var done = false
    while i < f.elements.count && !done {
        switch f.elements[i].firstTerm.factor {
        case .str(let s):
            attributes.append(s)
        case .intNumber(let num):
            attributes.append(String(num))
        case .realNumber(let num):
            attributes.append(String(num))
        case .arr:
            done = true
            i -= 1
        default:
            throw RunTimeError.errorInFunction("Invalid Screen definition")
        }
        i += 1
    }
    let obj = PRObject(name: model.generateName(name), attributes: attributes, superObject: sup)
    while (i < f.elements.count) {
        switch f.elements[i].firstTerm.factor {
        case .arr(let arr):
            let _ = try createPRObject(arr, sup: obj, model: model)
        default:
            throw RunTimeError.errorInFunction("Invalid Screen definition")
        }
        i += 1
    }
    return obj
}

/**
 Set the screen to a particular context.
 Pass a set of (possibly nested) Arrays (e.g. screen(["acquarium", "one", ["fish", "red"], ["fish", "green"]])).
 */
func setScreenArray(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    let screen = PRScreen(name: "run-time")
    let rootObject = PRObject(name: "card", attributes: ["card"], superObject: nil)
    screen.object = rootObject
    for obj in content {
        switch obj {
        case .arr(let arr):
            let _ = try createPRObject(arr, sup: rootObject, model: model!)
        default:
            throw RunTimeError.errorInFunction("Wrong argument in screen-array")
        }
    }
    model!.scenario.currentScreen = screen
    screen.start()
    model!.buffers["input"] = model!.scenario.current(model!)
    return (nil, true)
}


/**
    Set the screen to a particular context. Can be called in two different ways.
    Just pass the contents of the screen as arguments (e.g. screen("one","two").
*/
func setScreen(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if content.count > 0 && content[0].type() == "array" {
        return try setScreenArray(content, model: model)
    }
    let screen = PRScreen(name: "run-time")
    let rootObject = PRObject(name: "card", attributes: ["card"], superObject: nil)
    screen.object = rootObject
    var attributes: [String] = []
    for obj in content {
        switch obj {
        case .str(let s):
            attributes.append(s)
        case .intNumber(let num):
            attributes.append(String(num))
        case .realNumber(let num):
            attributes.append(String(num))
        default:
            throw RunTimeError.errorInFunction("Wrong argument in screen")
        }
    }
    let subObject = PRObject(name: model!.generateName("object"), attributes: attributes, superObject: rootObject)
    rootObject.subObjects.append(subObject)
    model!.scenario.currentScreen = screen
    screen.start()
    model!.buffers["input"] = model!.scenario.current(model!)
    return (nil, true)
}

/**
    Return the current time in the model
 */
func modelTime(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    return (Factor.realNumber(model!.time), true)
}

/** 
    Print one or more values
*/
 func printArg(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    var s: String = ""
    for arg in content {
        s += arg.description + " "
    }
    if(!model!.batchMode) {
        print(s)
    }
    model?.addToTraceField(s)
    return (nil, true)
}

/**
   Generate a random number integer between 0 and the argument (exclusive)
*/
func randIntNumber(_ content: [Factor], model: Model?)  throws -> (result: Factor?, done: Bool) {
    guard content.count == 1 else { throw RunTimeError.invalidNumberOfArguments }
    switch content[0] {
    case .intNumber(let num):
        guard num >= 0 else { throw RunTimeError.errorInFunction("Negative argument in random") }
        let result = Int(arc4random_uniform(UInt32(num)))
        return (Factor.intNumber(result), true)
    default:
        throw RunTimeError.errorInFunction("Call of random without Integer argument")
    }
}

/**
    Put the items of the given array in random order
*/
func shuffle(_ content: [Factor], model: Model?)  throws -> (result: Factor?, done: Bool) {
    guard content.count == 1 else { throw RunTimeError.invalidNumberOfArguments }
    switch content[0] {
    case .arr(let a):
        var newArray: [Expression] = []
        var oldArray = a.elements
        while oldArray.count > 0 {
            let index = Int(arc4random_uniform(UInt32(oldArray.count)))
            newArray.append(oldArray[index])
            oldArray.remove(at: index)
        }
        return (Factor.arr(ScriptArray(elements: newArray)), true)
    default: throw RunTimeError.errorInFunction("Trying to shuffle a non-array")
    }
}

/** 
   Starts a trial: adds a line to the data and sets the startTime to the current model time.
   Also causes model to pause when stepping
*/
func trialStart(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    model!.startTime = model!.time
    let dl = DataLine(eventType: "trial-start", eventParameter1: "void", eventParameter2: "void", eventParameter3: "void", inputParameters: model!.scenario.inputMappingForTrace, time:model!.startTime)
    model!.outputData.append(dl)
    return (nil, true)
}

/**
    Ends a trial: adds a line to the data, stores the result for the graph,
    initialized the model for a new trial
*/
func trialEnd(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if let imaginalChunk = model!.buffers["imaginal"] {
        model!.dm.addToDM(imaginalChunk)
    }
//    model!.running = false
    model!.resultAdd(model!.time - model!.startTime)
    if model!.running {
        let dl = DataLine(eventType: "trial-end", eventParameter1: "success", eventParameter2: "void", eventParameter3: "void", inputParameters: model!.scenario.inputMappingForTrace, time: model!.time - model!.startTime)
        model!.outputData.append(dl)
    }
    model!.commitToTrace(false)
    model!.initializeNextTrial()
    return(nil, true)
}

/**
 Add a Line to the Data: adds a line to the data with the first three arguments. Max of three arguments will be put in the data.*/
func dataLine(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    var eventParams = [String]()
    for i in 0...2 {
        eventParams.append(content.count > i ? content[i].description : "void")
    }
    let dl = DataLine(eventType: "data-line", eventParameter1: eventParams[0], eventParameter2: eventParams[1], eventParameter3: eventParams[2], inputParameters: model!.scenario.inputMappingForTrace, time: model!.time - model!.startTime)
    model!.outputData.append(dl)
    return(nil, true)
}

/**
  Run the model a single step
*/
func runStep(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if model!.fallingThrough { return(nil, true) }
    model!.newStep()
//    print("Running a step")
    return (nil, true)
}

/**
 Run the model until it takes the action specified
 */
func runUntilAction(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    //    content.insert(Factor.RealNumber(-1.0), atIndex: 0)
    //    return try runRelativeTimeOrAction(content, model: model)
    if model!.fallingThrough { return(nil, true) }
    model!.newStep()
    var actionFound = true
    if model!.formerBuffers["action"] == nil {
        actionFound = false
    }
    for i in content.indices.suffix(from: 0) {
        if let action = model!.formerBuffers["action"]?.slotvals["slot\(i+1)"]?.description {
            if content[i] != Factor.str(action) {
                actionFound = false
            }
        } else {
            actionFound = false
        }
    }
    if actionFound  {
        model!.scenario.nextEventTime = nil
        return (nil, true)
    } else {
        return (nil, false)
    }
    
}


/**
    Run the model for a specific amount of time OR until it performs
    the specified action. First argument is the amount of time, the
    rest of the arguments are action slots to be compared
*/
func runRelativeTimeOrAction(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.endIndex >= 1 else { throw RunTimeError.invalidNumberOfArguments }
    if model!.fallingThrough { return(nil, true) }
    if model!.scenario.nextEventTime == nil {
        var time: Double
        switch content[0] {
        case .intNumber(let num): time = Double(num)
        case .realNumber(let num): time = num
        default: throw RunTimeError.nonNumberArgument
        }
        if time >= 0 {
            model!.scenario.nextEventTime = model!.time + time
        }
    }
    model!.newStep()
    var actionFound: Bool
    if content.endIndex == 1 {
        actionFound = false
    } else {
        actionFound = true
        for i in content.indices.suffix(from: 1) {
            if let action = model!.formerBuffers["action"]?.slotvals["slot\(i)"]?.description {
//                print(content[i], action)
                if content[i] != Factor.str(action) {
                    actionFound = false
                } else {
//                    print("Match")
                }
            } else {
                actionFound = false
            }
        }
    }
    if actionFound || (model!.scenario.nextEventTime != nil && model!.time >= model!.scenario.nextEventTime) {
        model!.scenario.nextEventTime = nil
        return (nil, true)
    } else {
        return (nil, false)
    }
    
}

/**
 Run the model until a certain moment in time OR until it performs
 the specified action. First argument is the time, the
 rest of the arguments are action slots to be compared
 */
func runAbsoluteTimeOrAction(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.endIndex >= 1 else { throw RunTimeError.invalidNumberOfArguments }
    if model!.fallingThrough { return(nil, true) }
    if model!.scenario.nextEventTime == nil {
        var time: Double
        switch content[0] {
        case .intNumber(let num): time = Double(num)
        case .realNumber(let num): time = num
        default: throw RunTimeError.nonNumberArgument
        }
        model!.scenario.nextEventTime = time
    }
    return try runRelativeTimeOrAction(content, model: model)
}


/**
  Issue a reward
*/
func issueReward(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    var reward = model!.reward
    if content.count > 0 {
        switch (content[0]) {
        case .realNumber(let num):
            reward = num
        case .intNumber(let num):
            reward = Double(num)
        default: throw RunTimeError.nonNumberArgument
        }
    }
    if content.count > 1 {
        model!.operators.updateOperatorSjis(reward, time: Double(content[1].description))
    } else {
        model!.operators.updateOperatorSjis(reward, time: nil)
    }
    return (nil, true)
}

/**
  Move the model clock forward by the number of seconds in the argument
*/
func sleepPrims(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.endIndex == 1 else { throw RunTimeError.invalidNumberOfArguments }
    switch content[0] {
    case .intNumber(let num):
        model!.time += Double(num)
    case .realNumber(let num):
        model!.time += num
    default: throw RunTimeError.nonNumberArgument
    }
    return (nil, true)
}

/**
  Return the length of an array
*/
func length(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.endIndex == 1 else { throw RunTimeError.invalidNumberOfArguments }
    switch content[0] {
    case .arr(let a): return (Factor.intNumber(a.elements.count), true)
    case .str(let s): return (Factor.intNumber(s.characters.count), true)
    default: throw RunTimeError.errorInFunction("Trying to get the length of a non-array or -string")
    }
}

/** 
Set one of the input variables (0..3) to a value, so that it will show up in the
output file
*/
func setDataFileField(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.endIndex == 2 else { throw RunTimeError.invalidNumberOfArguments }
    guard content[0].type() == "integer" else { throw RunTimeError.nonNumberArgument }
    model!.scenario.currentInput["?\(content[0].intValue()!)"] = content[1].description
    return (nil, true)
}

/**
Return array with the last action
*/
func lastAction(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    var result: [Expression] = []
    if let action = model!.formerBuffers["action"] {
        var i = 1
        while (action.slotvals["slot\(i)"] != nil) {
            result.append(Expression(preop: "", firstTerm: Term(factor: Factor.str(action.slotvals["slot\(i)"]!.description), op: "", term: nil), op: "", secondTerm: nil))
            i += 1
        }
    } else {
        result.append(generateFactorExpression(Factor.str("")))
    }
    return(Factor.arr(ScriptArray(elements: result)), true)
}

/**
Add a fact chunk to DM. Assume first argument is chunkname, rest are slots
*/
func addDM(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.count >= 2 else { throw RunTimeError.invalidNumberOfArguments }
    let name = content[0].description
    let chunk = Chunk(s: name, m: model!)
    chunk.setSlot("isa", value: "fact")
    for i in 1..<content.count {
        let slotval = content[i].description
        if model!.dm.chunks[slotval] == nil {
            let extraChunk = Chunk(s: slotval, m: model!)
            extraChunk.setSlot("isa", value: "fact")
            extraChunk.setSlot("slot1", value: slotval)
            extraChunk.fixedActivation = model!.dm.defaultActivation
            model!.dm.addToDM(extraChunk)
        }
        chunk.setSlot("slot\(i)", value: slotval)
    }
    chunk.fixedActivation = model!.dm.defaultActivation
    model!.dm.addToDM(chunk)
    return (nil, true)
}

/** 
Set the fixed activation of a chunk. First argument in chunk name, second is activation value
*/
func setActivation(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.count == 2 else { throw RunTimeError.invalidNumberOfArguments }
    let chunk = model!.dm.chunks[content[0].description]
    guard chunk != nil else { throw RunTimeError.errorInFunction("Chunk does not exist") }
    let value = content[1].doubleValue()
    guard value != nil else { throw RunTimeError.nonNumberArgument }
    chunk!.fixedActivation = value!
    return (nil, true)
}

/**
 Set Sji between two chunks
 */
func setSji(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.count == 3 else { throw RunTimeError.invalidNumberOfArguments}
    let chunk1 = model!.dm.chunks[content[0].description]
    guard chunk1 != nil else { throw RunTimeError.errorInFunction("Chunk 1 does not exist") }
    let chunk2 = model!.dm.chunks[content[1].description]
    guard chunk2 != nil else { throw RunTimeError.errorInFunction("Chunk 2 does not exist") }
    let assoc = content[2].doubleValue()
    guard assoc != nil else { throw RunTimeError.nonNumberArgument }
    chunk2!.assocs[chunk1!.name] = Assocs(name: chunk1!.name, sji: assoc!, opLearning: 0)
    return (nil, true)
}

/**
Generate a random string with optional starting string
*/
func randomString(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    let prefix = content.count == 0 ? "fact" : content[0].description
    let result = Factor.str(model!.generateName(prefix))
    return (result, true)
}

/**
Set a parameter
 First argument: parameter name
 Second argument: parameter value
*/
func setGlobalParameter(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.count == 2 else { throw RunTimeError.invalidNumberOfArguments }
    var parName = content[0].description
    if parName[parName.characters.index(before: parName.endIndex)] != ":" {
        parName = parName + ":"
    }
    let parValue = content[1].description
    if !model!.setParameter(parName, value: parValue) {
        throw RunTimeError.errorInFunction("Parameter \(parName) does not exist or cannot take value \(parValue)")
    }
    return (nil, true)
}

/**
Retrieve Array containing batchParameters
Returns "NA" when not in batch mode
*/
func batchParameters(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if model!.batchMode {
        var scrArray: [Expression] = []
        for param in model!.batchParameters {
            if Double(param) != nil {
                if param.range(of: ".") != nil {
                    scrArray.append(generateFactorExpression(Factor.realNumber(Double(param)!)))
                } else {
                    scrArray.append(generateFactorExpression(Factor.intNumber(Int(param)!)))
                }
            } else {
                scrArray.append(generateFactorExpression(Factor.str(param)))
            }
        }
        let result = Factor.arr(ScriptArray(elements: scrArray))
        return (result, true)
    } else {
        return (Factor.str("NA"), true)
    }
}

/** 
Convert String to Int
*/
func strToInt(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    let result = Int(content[0].description)
    if content[0].type() == "string" &&  result != nil {
        return (Factor.intNumber(result!), true)
    } else {
        throw RunTimeError.errorInFunction("\(content[0]) cannot be converted from string to int")
    }
}

/**
 Open jar file, parameters are passed on to command line
 */
func openJar(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    /// Write to file
    let output = "=======================================================\n"
    do {
        let fileHandle = try FileHandle(forWritingTo: URL(string: "/Users/trudybuwalda/Desktop/Holiday/assocs.dat")!)
        fileHandle.seekToEndOfFile()
        let data = output.data(using: String.Encoding.utf8, allowLossyConversion: false)
        fileHandle.write(data!)
        fileHandle.closeFile()
    } catch let error as NSError {
        let err = error
        print(err)
    }

//    let task = NSTask()
//    task.launchPath = "/usr/bin/java"
//    task.arguments = ["-jar"]
//    for arg in content {
//        task.arguments?.append(arg.description)
//    }
//    let pipe = NSPipe()
//    task.standardOutput = pipe
//    task.launch()
//    let data = pipe.fileHandleForReading.readDataToEndOfFile()
//    pipe.fileHandleForReading.closeFile()
//    let output: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
//    task.terminate()
    return (nil, true)
}


/**
 Memory Management
 */
func reportMemory(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    var info = task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info))/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        
        task_info(mach_task_self_,
                  task_flavor_t(TASK_BASIC_INFO),
                  task_info_t($0),
                  &count)
        
    }
    
    if kerr == KERN_SUCCESS {
        return(Factor.str("\(info.resident_size)"), true)
    }
    else {
        return(Factor.str("Error"), true)
    }
}

/* Put the contents of the imaginal buffer in the declarative memory
 */
func imaginalToDM(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if let imaginalChunk = model!.buffers["imaginal"] {
        model!.dm.addToDM(imaginalChunk)
    }
    return(nil, true)
}

/**
 - Set the number of references of a chunk
 - 1st argument: chunk name
 - 2nd argument: number of references (int)
 - */
func setReferences(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    guard content.count == 2 else { throw RunTimeError.invalidNumberOfArguments }
    let chunk = model!.dm.chunks[content[0].description]
    guard chunk != nil else { throw RunTimeError.errorInFunction("Chunk does not exist") }
    let value = content[1].intValue()
    guard value != nil else { throw RunTimeError.errorInFunction("Second argument is not an int") }
    chunk!.references = value!
    return(nil, true)
}

/* High Speed, High Stakes Scoring Rule
    First argument: current rating of model
    Second argument: current rating of item
    Third argument: accuracy
    Fourth argument: response time
    Fifth argument: response deadline
    */
func updateRating(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    if (content.count < 4) {
        throw RunTimeError.errorInFunction("The function updateModelRating requires five arguments")
    } else if (Double(content[0].description) == nil) {
        throw RunTimeError.errorInFunction("\(content[0]) is not a double")
    } else if (Double(content[1].description) == nil) {
        throw RunTimeError.errorInFunction("\(content[1]) is not a double")
    } else if (content[2].type() != "integer") {
        throw RunTimeError.errorInFunction("\(content[2]) is not an integer")
    } else if (Double(content[3].description) == nil) {
        throw RunTimeError.errorInFunction("\(content[3]) is not a double")
    } else if (Double(content[4].description) == nil) {
        throw RunTimeError.errorInFunction("\(content[4]) is not a double")
    }
    let e = 2.71828
    let score = (2 * Double(content[2].intValue()! - 1)) * (1 - (1/content[4].doubleValue()!) * content[3].doubleValue()!)
    let euler = pow(e, (2 * (content[0].doubleValue()! - content[1].doubleValue()!)))
    let expectedProbability = (euler + 1) / (euler - 1) - (1 / (content[0].doubleValue()! - content[1].doubleValue()!))
    let newModelRating = content[0].doubleValue()! + 0.0075 * (score - expectedProbability)
    let newItemRating = content[1].doubleValue()! + 0.0075 * (expectedProbability - score)

    return(Factor.arr(ScriptArray(elements: [generateFactorExpression(Factor.realNumber(newModelRating)), generateFactorExpression(Factor.realNumber(newItemRating))])), true)
    }

/* Select Problem
    First argument: current rating of model
    Second argument: list of last 10 problems
    */
func selectProblem(_ content: [Factor], model: Model?) throws -> (result: Factor?, done: Bool) {
    let filepath = "/Volumes/Double-Whopper/Trudy/2015_Rekentuin/Model/CurrentModel/Models/10-parameterSweepPartialMatchingOnly/itemratings.txt"

    var input: [String] = [];
    do {
        if true {//let path = NSBundle.mainBundle().pathForResource(filepath, ofType: "txt"){
            let data = try String(contentsOfFile:filepath, encoding: String.Encoding.utf8)
            input = data.components(separatedBy: CharacterSet.newlines)
        }
    } catch {
        throw RunTimeError.errorInFunction("Select Problem: File cannot be read")
    }

    var probabilityP = 0
    for _ in 1...100 {
        if Int(arc4random_uniform(100)) > 50 {
            probabilityP += 1
        }
    }

    probabilityP = probabilityP * 2 - 25
    if(probabilityP > 99) {
        probabilityP = 99
    } else if (probabilityP < 50) {
        probabilityP = 50
    }
    let targetRating = content[0].doubleValue()! + log(Double(probabilityP) / Double(100 - probabilityP))

    var bestMatch = ["10", "10", 1000.0] as [Any]
    for line in input {
        let addend1 = line.substring(with: Range<String.Index>(line.startIndex..<line.characters.index(line.startIndex, offsetBy: 1)))
        let addend2 = line.substring(with: Range<String.Index>(line.characters.index(line.startIndex, offsetBy: 4)..<line.characters.index(line.startIndex, offsetBy: 5)))
        let itemRating = Double(line.substring(with: Range<String.Index>(line.characters.index(line.startIndex, offsetBy: 6)..<line.endIndex)))

        var recent = 0
        switch content[1] {
            case .arr(let arr):
                var idx = 0
                while idx < arr.elements.count {
                    if arr.elements[idx].description == addend1 + " x " + addend2 {
                        recent = 1
                    }
                    idx += 1
                }
                if recent == 0 && abs(targetRating - itemRating!) < Double((bestMatch[2] as AnyObject).description) {
                    bestMatch = [addend1, addend2, targetRating - itemRating!]
                }

            default:
                throw RunTimeError.errorInFunction("Wrong argument in select-problem")
            }

        }

    let bestMatchFinal = ScriptArray(elements: [generateFactorExpression(Factor.str(bestMatch[0].description)), generateFactorExpression(Factor.str(bestMatch[1].description)), generateFactorExpression(Factor.realNumber(Double(bestMatch[2].description)!))])
    return (Factor.arr(bestMatchFinal), true)

    }

/**
 Present items in a fixed math garden way
 */
func fixedProblems(_ content: [Factor], model:Model?) throws -> (result: Factor?, done: Bool) {
    let filepath = "/Users/trudybuwalda/Desktop/fixedOrder.txt"
    var input: [String] = [];
    do {
        let data = try String(contentsOfFile:filepath, encoding: String.Encoding.utf8)
        input = data.components(separatedBy: CharacterSet.newlines)
    } catch {
        throw RunTimeError.errorInFunction("Select Problem: File cannot be read")
    }
    let line = input[content[0].intValue()!]
    var addend1 = ""
    var addend2 = ""
    if(line != "") {
        addend1 = line.substring(with: Range<String.Index>(line.startIndex..<line.characters.index(line.startIndex, offsetBy: 1)))
        addend2 = line.substring(with: Range<String.Index>(line.characters.index(line.startIndex, offsetBy: 6)..<line.characters.index(line.startIndex, offsetBy: 7)))
    }

    let outputFinal = ScriptArray(elements: [generateFactorExpression(Factor.str(addend1)), generateFactorExpression(Factor.str(addend2))])
    return(Factor.arr(outputFinal), true)
}


/**
 Split numbers in ones and tens
 */
func splitNumbers(_ content: [Factor], model:Model?) throws -> (result: Factor?, done: Bool) {
    var output: ScriptArray
    if(content.count == 1 && Int(content[0].description) != nil) {
        let numbers = String(describing: content[0])
        let array = numbers.utf8.map{Int($0)-48}
        
        if(array.count == 1) {
            output = ScriptArray(elements: [generateFactorExpression(Factor.intNumber(0)),
                generateFactorExpression(Factor.intNumber(array[0]))])
        } else if(array.count == 2) {
            output = ScriptArray(elements: [generateFactorExpression(Factor.intNumber(array[0])),
                generateFactorExpression(Factor.intNumber(array[1]))])
            } else {
                throw RunTimeError.errorInFunction("The function split-numbers cannot split numbers with more than 3 digits")
        }
       
    } else {
        throw RunTimeError.errorInFunction("The function split-numbers requires one numerical argument")
    }
    return(Factor.arr(output), true)
}

/**
 Set Sji's for numbers
 */
//func numberSjis(content: [Factor], model:Model?) throws -> (result: Factor?, done: Bool) {
//    guard content.count == 3 else { throw RunTimeError.invalidNumberOfArguments}
//    for (_,ch1) in model!.dm.chunks {
//        for (_,slotval1) in ch1.slotvals {
//            if slotval2.description.containsString(slotval1.description) {
//            }
//         }
//    }
//    }
//    }
//    return(nil, true)
//    }
