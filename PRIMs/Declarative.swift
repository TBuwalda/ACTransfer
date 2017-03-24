//
//  Declarative.swift
//  actr
//
//  Created by Niels Taatgen on 3/1/15.
//  Copyright (c) 2015 Niels Taatgen. All rights reserved.
//

import Foundation

class Declarative: NSObject, NSCoding  {
    unowned let model: Model
    static let baseLevelDecayDefault = 0.5
    static let optimizedLearningDefault = true
    static let maximumAssociativeStrengthDefault = 3.0
    static let goalActivationDefault = 1.0
    static let inputActivationDefault = 0.0
    static let retrievalActivationDefault = 0.0
    static let imaginalActivationDefault = 0.0
    static let retrievalThresholdDefault = -2.0
    static let activationNoiseDefault = 0.2
    static let defaultOperatorAssocDefault = 3.0
    static let defaultInterOperatorAssocDefault = 1.0
    static let defaultOperatorSelfAssocDefault = -1.0
    static let misMatchPenaltyDefault = 5.0
    static let goalSpreadingActivationDefault = false
    static let latencyFactorDefault = 0.2
    static let goalOperatorLearningDefault = false
    static let betaDefault = 0.1
    static let explorationExploitationFactorDefault = 0.0
    static let declarativeBufferStuffingDefault = false
    static let retrievalReinforcesDefault = false
    static let defaultActivationDefault: Double? = nil
    static let partialMatchingDefault = false
    static let newPartialMatchingDefault: Double? = nil
    static let assocDefault = 10.0
    static let associativeLearningDefault = false
    /// Baseleveldecay parameter (d in ACT-R)
    var baseLevelDecay: Double = baseLevelDecayDefault
    /// Optimized learning on or off
    var optimizedLearning = optimizedLearningDefault
    /// mas parameter in ACT-R
    var maximumAssociativeStrength: Double = maximumAssociativeStrengthDefault
    /// W parameter in ACT-R
    var goalActivation: Double = goalActivationDefault
    /// Spreading activation from perception
    var inputActivation: Double = inputActivationDefault
    /// Spreading activation from retrieval
    var retrievalActivation: Double = retrievalActivationDefault
    /// Spreading activation from imaginal
    var imaginalActivation: Double = imaginalActivationDefault
    /// RT or tau parameter in ACT-R
    var retrievalThreshold: Double = retrievalThresholdDefault
    /// ans parameter in ACT-R
    var activationNoise: Double? = activationNoiseDefault
    /// Operators are associated with goals, and use this value as standard Sji
    var defaultOperatorAssoc: Double = defaultOperatorAssocDefault
    /// Operators that are associated with the same goal are associated with each other with the following Sji
    var defaultInterOperatorAssoc: Double = defaultInterOperatorAssocDefault
    /// Operators are negatively associated with themselves to prevent the same operator from being used twice with the following Sji
    var defaultOperatorSelfAssoc: Double = defaultOperatorSelfAssocDefault
    /// MP parameter in ACT-R
    var misMatchPenalty: Double = misMatchPenaltyDefault
    /// Parameter that controls whether to use standard spreading from the goal (false), or spreading by activation of goal chunks (true)
    var goalSpreadingByActivation = goalSpreadingActivationDefault
    /// ACT-R latency factor (F)
    var latencyFactor = latencyFactorDefault
    /// Indicates whether associations between goals and operators will be learned
    var goalOperatorLearning = goalOperatorLearningDefault
    /// Learning rate of goal operator association learning
    var beta = betaDefault
    /// Parameter that controls the amount of exploration vs. exploitation. Higher is more exploration
    var explorationExploitationFactor = explorationExploitationFactorDefault
    /// Parameter that control whether we use declarative buffer stuffing
    var declarativeBufferStuffing = declarativeBufferStuffingDefault
    /// Parameter that determines whether a retrieval alone increase baselevel activation
    var retrievalReinforces = retrievalReinforcesDefault
    /// default Activation for chunks
    var defaultActivation = defaultActivationDefault
    /// assoc Parameter for associative learning
    var assoc = assocDefault
    /// associativeLearning parameter
    var associativeLearning = associativeLearningDefault
    
    
    /// Dictionary with all the chunks in DM, maps name onto Chunk
    var chunks = [String:Chunk]()
    /// List of all the chunks that partipated in the last retrieval. Tuple has Chunk and activation value
    var conflictSet: [(Chunk,Double)] = []
    /// Finst list for the current retrieval
    var finsts: [String] = []
    /// This Array has all the operators with arrays of their conditions and actions. We use this to find the optimal ovelap when defining new operators
    var operatorCA: [(String,[String],[String])] = []
    /// Parameter that controls whether to use partial matching (true) or not (false, default)
    var partialMatching = partialMatchingDefault
    var newPartialMatchingPow = newPartialMatchingDefault
    var newPartialMatchingExp = newPartialMatchingDefault
    
    
    var retrieveBusy = false
    var retrieveError = false
    var retrievaltoDM = false
    
    init(model: Model) {
        self.model = model

    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let model = aDecoder.decodeObject(forKey: "model") as? Model,
            let chunks = aDecoder.decodeObject(forKey: "chunks") as? [String:Chunk],
            let operatorCACol1 = aDecoder.decodeObject(forKey: "operatorCACol1") as? [String],
            let operatorCACol2 = aDecoder.decodeObject(forKey: "operatorCACol2") as? [[String]],
            let operatorCACol3 = aDecoder.decodeObject(forKey: "operatorCACol3") as? [[String]]
            else { return nil }
        self.init(model: model)
        self.chunks = chunks
        for i in 0..<operatorCACol1.count {
            self.operatorCA.append((operatorCACol1[i], operatorCACol2[i], operatorCACol3[i]))
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self.model, forKey: "model")
        coder.encode(self.chunks, forKey: "chunks")
        let operatorCACol1 = self.operatorCA.map{ $0.0 }
        let operatorCACol2 = self.operatorCA.map{ $0.1 }
        let operatorCACol3 = self.operatorCA.map{ $0.2 }
        coder.encode(operatorCACol1, forKey: "operatorCACol1")
        coder.encode(operatorCACol2, forKey: "operatorCACol2")
        coder.encode(operatorCACol3, forKey: "operatorCACol3")
        
    }

    /**
        After chunks have been loaded from a file, not all slotvalues necessarily point to chunks, but instead
        may still be Strings. This function properly sets those values.
    */
    func reintegrateChunks() {
        for (_,chunk) in chunks {
            for (slot,value) in chunk.slotvals {
                switch value {
                case .Text(let s):
                    chunk.setSlot(slot, value: s)
                default: break
                }
            }
        }
    }
    
    func setParametersToDefault() {
        baseLevelDecay = Declarative.baseLevelDecayDefault
        optimizedLearning = Declarative.optimizedLearningDefault
        maximumAssociativeStrength = Declarative.maximumAssociativeStrengthDefault
        goalActivation = Declarative.goalActivationDefault
        inputActivation = Declarative.inputActivationDefault
        retrievalActivation = Declarative.retrievalActivationDefault
        imaginalActivation = Declarative.imaginalActivationDefault
        retrievalThreshold = Declarative.retrievalThresholdDefault
        activationNoise = Declarative.activationNoiseDefault
        defaultOperatorAssoc = Declarative.defaultOperatorAssocDefault
        defaultInterOperatorAssoc = Declarative.defaultInterOperatorAssocDefault
        defaultOperatorSelfAssoc = Declarative.defaultOperatorSelfAssocDefault
        misMatchPenalty = Declarative.misMatchPenaltyDefault
        goalSpreadingByActivation = Declarative.goalSpreadingActivationDefault
        latencyFactor = Declarative.latencyFactorDefault
        goalOperatorLearning = Declarative.goalOperatorLearningDefault
        beta = Declarative.betaDefault
        explorationExploitationFactor = Declarative.explorationExploitationFactorDefault
        declarativeBufferStuffing = Declarative.declarativeBufferStuffingDefault
        retrievalReinforces = Declarative.retrievalReinforcesDefault
        defaultActivation = Declarative.defaultActivationDefault
        partialMatching = Declarative.partialMatchingDefault
        newPartialMatchingPow = Declarative.newPartialMatchingDefault
        newPartialMatchingExp = Declarative.newPartialMatchingDefault
    }
    
    func duplicateChunk(_ chunk: Chunk) -> Chunk? {
        /* Return duplicate chunk if there is one, else nil */
        for (_,c1) in chunks {
            if c1 == chunk { return c1 }
        }
        return nil
    }
    
    func retrievalState(_ slot: String, value: String) -> Bool {
        switch (slot,value) {
        case ("state","busy"): return retrieveBusy
        case ("state","error"): return retrieveError
        default: return false
        }
    }
    
    func clearFinsts() {
        finsts = []
    }
    
    func addToFinsts(_ c: Chunk) {
        finsts.append(c.name)
    }
    
    
    func addToDM(_ chunk: Chunk) {
        if let dupChunk = duplicateChunk(chunk) {
            dupChunk.addReference()
            dupChunk.mergeAssocs(chunk)
            dupChunk.definedIn.append(contentsOf: chunk.definedIn)
            if chunk.fixedActivation != nil && dupChunk.fixedActivation != nil {
                dupChunk.fixedActivation = max(chunk.fixedActivation!, dupChunk.fixedActivation!)
            }
        } else {
            chunk.startTime()
            chunks[chunk.name] = chunk
            for (_,val) in chunk.slotvals {
                switch val {
                case .symbol(let refChunk):
                    refChunk.fan += 1
                default: break
                }
            }
        }
    }
    
    /**
    Checks all chunks in DM to make sure threre are no Strings in slots that are the same as the name
    of a chunk (replaces those).
    */
    func stringsToChunks() {
        for (_,chunk) in chunks {
            for (slot,val) in chunk.slotvals {
                switch val {
                case .Text(let s):
                    if let altChunk = chunks[s] {
                        chunk.slotvals[slot] = Value.symbol(altChunk)
//                        print("Fixing \(altChunk.name) in \(chunk.name)")
                    }
                default: break
                }
            }
        }
    }
    
    /**
    Calculate chunk latency
    - parameter activation: an activation value
    - returns: the latency
    */
    func latency(_ activation: Double) -> Double {
        return latencyFactor * exp(-activation)
    }
    
    func retrieve(_ chunk: Chunk) -> (Double, Chunk?) {
        retrieveError = false
        var bestMatch: Chunk? = nil
        var bestActivation: Double = retrievalThreshold
        conflictSet = []
        chunkloop: for (_,ch1) in chunks {
            if !finsts.contains(ch1.name) {
                for (slot,value) in chunk.slotvals {
                    if let val1 = ch1.slotValue(slot)  {
                        if !val1.isEqual(value) {
                            continue chunkloop }
                    } else { continue chunkloop }
                }
                conflictSet.append((ch1,ch1.activation()))
              //  print("Activation of \(ch1.name) is \(ch1.activation())")
                if ch1.activation() > bestActivation {
                    bestActivation = ch1.activation()
                    bestMatch = ch1
                }
            }
        }
        
        if model.activationTrace {
            if !model.batchMode {
                for (chunk,activation) in conflictSet {
                    model.addToTrace("   CFS: \(chunk.name) \(activation)", level: 3)
                }
            } else {
                if chunk.type == "fact" {
                    for (_, ch) in chunks {
                        //model.addToActivationTrace(model.time - model.startTime, name: ch.name, activation: ch.activation())
                    }
                }
            }
        }
        if bestActivation > retrievalThreshold {
            return (latency(bestActivation) , bestMatch)
        } else {
            retrieveError = true
            return (latency(retrievalThreshold), nil)
        }
        
    }
        
    /* Mismatch Functions */
    // Mismatch function for operators
    func mismatchOperators(_ x: Value, _ y: Value) -> Double {
        /* Return similarity if there is one, else return -1*/
        if (x.description == "times" || x.description == "plus" || x.description == "minus" || x.description == "divided-by") {
            if (y.description == "times" || y.description == "plus" || y.description == "minus" || y.description == "divided-by") {
                return -0.35
            }
            return -1
        } else {
            return -1
        }
    }
    
    // Mismatch function for numbers
    func mismatchNumbers(_ x: Value, _ y: Value) -> Double {
        /* Return similarity if there is one, else return -1
         Similarity is calculated by dividing the smallest number by the largest number.*/
        if (Int(x.description) != nil && Int(y.description) != nil)  {
            print("mismatchNumbers")
            print(x)
            print(y)
            let maxValue = max(Double(x.description)!, Double(y.description)!)
            let minValue = min(Double(x.description)!, Double(y.description)!)
            let mismatch = (minValue - maxValue) / 10
            print(mismatch)
            print("\n")
            return mismatch >= -1 ? mismatch : -1
        } else {
            return -1
        }
    }
    
    // Mismatch function for numbers with intercept
    func mismatchNumbersIntercept(_ x: Value, _ y: Value) -> Double {
        /* Return similarity if there is one, else return -1
         Similarity is calculated by dividing the smallest number by the largest number.*/
        if (Int(x.description) != nil && Int(y.description) != nil)  {
            let maxValue = max(Double(x.description)!, Double(y.description)!)
            let minValue = min(Double(x.description)!, Double(y.description)!)
            var mismatch = (minValue - maxValue) / 10
            if (minValue != maxValue) {
                mismatch -= 0.05
            }
            return mismatch >= -1 ? mismatch : -1
        } else {
            return -1
        }
    }
    
    // Mismatch function for numbers with slope
    func mismatchNumbersSlope(_ x: Value, _ y: Value) -> Double {
        /* Return similarity if there is one, else return -1
         Similarity is calculated by dividing the smallest number by the largest number.*/
        if (Int(x.description) != nil && Int(y.description) != nil)  {
            let maxValue = max(Double(x.description)!, Double(y.description)!)
            let minValue = min(Double(x.description)!, Double(y.description)!)
            var mismatch = (minValue - maxValue) / 10
            mismatch = mismatch * 2
            return mismatch >= -1 ? mismatch : -1
        } else {
            return -1
        }
    }
    
    // General Mismatch Function
    func mismatchFunction(_ x: Value, y: Value) -> Double? {
        /* Select the correct mismatch function and return similarity if there is one */
        var mismatch: Double
        if (x.description == y.description) {
            mismatch = 0
        } else if (Double(x.description) != nil && Double(y.description) != nil) {
            mismatch = mismatchNumbers(x, y)
        } else {
            mismatch = -1
        }
        return mismatch
    }

    
    func partialRetrieve(_ chunk: Chunk, mismatchFunction: (_ x: Value, _ y: Value) -> Double? ) -> (Double, Chunk?) {
        var bestMatch: Chunk? = nil
        var bestActivation: Double = retrievalThreshold
        conflictSet = []
        chunkloop: for (_,ch1) in chunks {
            var mismatch = 0.0
            for (slot,value) in chunk.slotvals {
                if let val1 = ch1.slotvals[slot] {
                    if !val1.isEqual(value) {
                        let slotmismatch = mismatchFunction(val1, value)
                        if slotmismatch != nil {
                            mismatch += slotmismatch!
                        } else
                        {
                            continue chunkloop
                        }
                    }
                } else { continue chunkloop }
            }
//            println("Candidate: \(ch1) with activation \(ch1.activation() + mismatch)")
            var activation = retrievalThreshold
            if (newPartialMatchingPow != nil)  {
                activation = ch1.activation() + mismatch * misMatchPenalty * pow(Double(ch1.references),newPartialMatchingPow!)
            } else if (newPartialMatchingExp != nil) {
                activation = ch1.activation() + mismatch * misMatchPenalty * pow(newPartialMatchingExp!,Double(ch1.references))
            } else {
                activation = ch1.activation() + mismatch * misMatchPenalty
            }
            if model.batchMode && model.activationTrace {
                if chunk.type == "fact" {
                    model.addToActivationTrace(model.time - model.startTime, request: model.buffers["retrievalR"]!.slotvals["slot1"]!.description + "x" + model.buffers["retrievalR"]!.slotvals["slot3"]!.description, name: ch1.name, activation: activation, type: "activation")
                    model.addToActivationTrace(model.time - model.startTime, request: model.buffers["retrievalR"]!.slotvals["slot1"]!.description + "x" + model.buffers["retrievalR"]!.slotvals["slot3"]!.description, name: ch1.name, activation: mismatch * misMatchPenalty, type: "mismatch")
                }
            }
            conflictSet.append((ch1,activation))
            if activation > bestActivation {
                bestActivation = activation
                bestMatch = ch1
            }        
            }

        
        if bestActivation > retrievalThreshold {
            return (latency(bestActivation) , bestMatch)
        } else {
            retrieveError = true
            return (latency(retrievalThreshold), nil)
        }
    }

    func action() -> Double {
        let stuff = model.buffers["retrievalR"] == nil
        let emptyRetrieval = Chunk(s: "emptyRetrieval", m: model)
        emptyRetrieval.setSlot("isa", value: "fact")
        let retrievalQuery = model.buffers["retrievalR"] ?? emptyRetrieval
        var latency: Double = 0.0
        var retrieveResult: Chunk? = nil
        if partialMatching {
            (latency, retrieveResult) = partialRetrieve(retrievalQuery, mismatchFunction: mismatchFunction)
        } else {
            (latency, retrieveResult) = retrieve(retrievalQuery)
        }
        if retrieveResult != nil {
            if stuff {
                if !model.silent {
                    model.addToTrace("Stuffing retrieval buffer \(retrieveResult!.name) (latency = \(latency))", level: 2)
                }
                model.addToBatchTrace(model.time - model.startTime, type: "retrieval", addToTrace: "\(retrieveResult!.name)")
            } else {
                if !model.silent {
                    model.addToTrace("\(retrieveResult!.name) (latency = \(latency))", level: 2)
                }
                model.addToBatchTrace(model.time - model.startTime, type: "retrieval", addToTrace: "\(retrieveResult!.name)")
                if retrievalReinforces {
                    retrieveResult!.addReference()
                }
            }
            model.buffers["retrievalH"] = retrieveResult!

            updateFrequency()

        } else if !stuff  {
            if !model.silent {
                model.addToTrace("Retrieval failure", level: 2)
            }
            model.addToBatchTrace(model.time - model.startTime, type: "retrieval", addToTrace: "Failure")
            let failChunk = Chunk(s: "RetrievalFailure", m: model)
            failChunk.setSlot("slot1", value: "error")
            model.buffers["retrievalH"] = failChunk
        }
        model.buffers["retrievalR"] = nil
        return retrieveResult == nil && stuff ? 0.0 : latency
    }
    
    func updateFrequency() {
        // Update the F(Ni & Cj) between the retrieved chunk and the context
        let contextj = model.buffers["input"]!
        let neededi = model.buffers["retrievalH"]!

        for (_, slot) in contextj.slotvals {
            if slot.chunk() != nil {
                for (_, slotNeeded) in neededi.slotvals {
                    if slotNeeded.chunk() != nil && slotNeeded.chunk()! == slot.chunk()! {
                        if slot.chunk()!.assocs[neededi.name] == nil {
                            slot.chunk()!.assocs[neededi.name] = Assocs(s: neededi.name)
                        }
                        slot.chunk()!.assocs[neededi.name]!.frequency += 1
                    }
                }
            }
        }
        
//        /// Write to file
//        let output = "===========\n" + contextj.description + "\n" + neededi.name + "\n" + "\(contextj.assocs[neededi.name]!.frequency)" + "\n"
//        do {
//            let fileHandle = try NSFileHandle(forWritingToURL: NSURL(string: "/Users/trudybuwalda/Desktop/Holiday/assocs1.dat")!)
//            fileHandle.seekToEndOfFile()
//            let data = output.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//            fileHandle.writeData(data!)
//            fileHandle.closeFile()
//        } catch let error as NSError {
//            let err = error
//            print(err)
//        }
    }

    
}
