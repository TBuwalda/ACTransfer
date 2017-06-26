//
//  Operator.swift
//  PRIMs
//
//  Created by Niels Taatgen on 7/28/15.
//  Copyright (c) 2015 Niels Taatgen. All rights reserved.
//

import Foundation

/**
    The Operator class contains many of the functions that deal with operators. Most of these still have to be migrated from Model.swift
*/
class Operator {

    unowned let model: Model
    
    init(model: Model) {
        self.model = model
    }

    
    /**
    Reset the operator object
    */
    func reset() {
    }
    
    
    /**
    Determine the amount of overlap between two lists of PRIMs
    */
    func determineOverlap(_ oldList: [String], newList: [String]) -> Int {
        var count = 0
        for prim in oldList {
            if !newList.contains(prim) {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
    Construct a string of PRIMs from the best matching operators
    */
    func constructList(_ template: [String], source: [String], overlap: Int) -> (String, [String]) {
        var primList = ""
        var primArray = [String]()
        if overlap > 0 {
            for i in 0..<overlap {
                primList =  (primList == "" ? template[i] : template[i] + ";" ) + primList
                primArray.append(template[i])
            }
        }
        for prim in source {
            if !primArray.contains(prim) {
                primList = (primList == "" ? prim : prim + ";" ) + primList
                primArray.append(prim)
            }
        }
        return (primList, primArray)
    }
    
    
    
    /**
    Add conditions and actions to an operator while trying to optimize the order of the PRIMs to maximize overlap with existing operators 
    */
    /*
    func addOperator(_ op: Chunk, conditions: [String], actions: [String]) {
        var bestConditionMatch: [String] = []
        var bestConditionNumber: Int = -1
        var bestConditionActivation: Double = -1000
        var bestActionMatch: [String] = []
        var bestActionNumber: Int = -1
        var bestActionActivation: Double = -1000
        for (chunkName, chunkConditions, chunkActions) in model.dm.operatorCA {
            if let chunkActivation = model.dm.chunks[chunkName]?.baseLevelActivation() {
                let conditionOverlap = determineOverlap(chunkConditions, newList: conditions)
                if (conditionOverlap > bestConditionNumber) || (conditionOverlap == bestConditionNumber && chunkActivation > bestConditionActivation) {
                    bestConditionMatch = chunkConditions
                    bestConditionNumber = conditionOverlap
                    bestConditionActivation = chunkActivation
                }
                let actionOverlap = determineOverlap(chunkActions, newList: actions)
                if (actionOverlap > bestActionNumber) || (actionOverlap == bestActionNumber && chunkActivation > bestActionActivation) {
                    bestActionMatch = chunkActions
                    bestActionNumber = actionOverlap
                    bestActionActivation = chunkActivation
                }
            }
        }
        let (conditionString, conditionList) = constructList(bestConditionMatch, source: conditions, overlap: bestConditionNumber)
        let (actionString, actionList) = constructList(bestActionMatch, source: actions, overlap: bestActionNumber)
        op.setSlot("condition", value: conditionString)
        op.setSlot("action", value: actionString)
        model.dm.operatorCA.append((op.name, conditionList, actionList))
    }
    */
    
    /// List of chosen operators with time
    var previousOperators: [(Chunk,Double)] = []     
    /**
    Update the Sji's between the current goal(s?) and the operators that have fired. Restrict to updating the goal in G1 for now.
    
    - parameter payoff: The payoff that will be distributed
    */
//    func updateOperatorSjis(_ payoff: Double) {
//        if !model.dm.goalOperatorLearning || model.reward == 0.0 { return } // only do this when switched on
//        let goalChunk = model.formerBuffers["goal"]?.slotvals["slot1"]?.chunk() // take formerBuffers goal, because goal may have been replace by stop or nil
//        if goalChunk == nil { return }
//        for (operatorChunk,operatorTime) in previousOperators {
//            let opReward = model.dm.defaultOperatorAssoc * (payoff - (model.time - operatorTime)) / model.reward
//            let opChunkAssocGoal = operatorChunk.assocs[goalChunk!.name]
//            if opChunkAssocGoal == nil || opChunkAssocGoal!.1 != 0 { // We don't update when the assoc is defined in the model
//                if operatorChunk.assocs[goalChunk!.name] == nil {
//                    operatorChunk.assocs[goalChunk!.name] = (0.0, 0)
//                }
//                operatorChunk.assocs[goalChunk!.name]!.0 += model.dm.beta * (opReward - operatorChunk.assocs[goalChunk!.name]!.0)
//                operatorChunk.assocs[goalChunk!.name]!.1 += 1
//                print("Operator \(operatorChunk.name) receives reward \(opReward)")
//                if opReward > 0 {
//                    operatorChunk.addReference() // Also increase baselevel activation of the operator
//                }
//                if !model.silent {
//                    model.addToTrace("Updating assoc between \(goalChunk!.name) and \(operatorChunk.name) to \(operatorChunk.assocs[goalChunk!.name]!)", level: 5)
//                }
//            }
//        }
//    }
    func updateOperatorSjis(_ payoff: Double) {
        if !model.dm.goalOperatorLearning || model.reward == 0.0 { return } // only do this when switched on
        let goalChunk = model.formerBuffers["goal"]?.slotvals["slot1"]?.chunk() // take formerBuffers goal, because goal may have been replace by stop or nil
        if goalChunk == nil { return }
        for (operatorChunk,operatorTime) in previousOperators {
            let opReward = model.dm.defaultOperatorAssoc * (payoff - (model.time - operatorTime)) / model.reward
            if operatorChunk.assocs[goalChunk!.name] == nil {
                operatorChunk.assocs[goalChunk!.name] = (0.0, 0)
            }
            operatorChunk.assocs[goalChunk!.name]!.0 += model.dm.beta * (opReward - operatorChunk.assocs[goalChunk!.name]!.0)
            operatorChunk.assocs[goalChunk!.name]!.1 += 1
            if opReward > 0 {
                operatorChunk.addReference() // Also increase baselevel activation of the operator
            }
            if !model.silent {
                model.addToTrace("Updating assoc between \(goalChunk!.name) and \(operatorChunk.name) to \(operatorChunk.assocs[goalChunk!.name]!)", level: 5)
            }
        }
    }

    
    //static let literalRoles = ["stop", "wait", "error", "focus-up", "focusup","one","two","three","four","five","six","yes","no"] // not complete yet!!!
    
    /**
    Function that checks whether the operator matches the current roles in the goals. If it does, it also returns an operator with the appropriate substitution.
     - parameter op: The candidate operator
     - returns: nil if there is no match, otherwise the operator with the appropriate substitution
    */
    func checkOperatorGoalMatch(op: Chunk) -> Chunk? {
        guard let goalChunk = model.buffers["goal"] else { return nil }
        let opCopy = op.copyChunk()
        var referenceList: [String:Value] = [:]
        for (_,value) in goalChunk.slotvals {  // Go through all the goals in the goal buffer
//            print("Value is \(value.description)")
            if let chunk = value.chunk() {   // if it is a chunk
                if chunk.type == "goaltype" {  // and it is a goal
                    for (slot,val) in chunk.slotvals {
                        if slot != "isa" {
                            referenceList[slot] = val
                        }
                    }
                } else if let nestedGoal = chunk.slotvals["slot1"]?.chunk(), nestedGoal.type == "goaltype" {
                    for (slot, val) in chunk.slotvals {
                        if slot.hasPrefix("slot") && !slot.hasPrefix("slot1") {
                            if let slotValChunk = val.chunk(), let slotVal1 = slotValChunk.slotvals["slot1"], let slotVal2 = slotValChunk.slotvals["slot2"]  {
                                referenceList[slotVal1.description] = slotVal2
                            }
                        }
                    }
                }
            }
        }
        var i = 1
        while let opSlotValue = opCopy.slotvals["slot\(i)"]  {
            if opSlotValue.description.hasPrefix("*") {
                var tempString = opSlotValue.description
                tempString.remove(at: tempString.startIndex)
                if let subst = referenceList[tempString] {
                    opCopy.setSlot("slot\(i)", value: subst)
                } else {
                    return nil
                }
            }
            i += 1
        }
/*                    var i = 1
                    while let opSlotValue = opCopy.slotvals["slot\(i)"]  {
                        if opSlotValue.chunk() != nil && opSlotValue.chunk()!.type == "reference" {
                            if let substitute = chunk.slotvals[opSlotValue.description] {
                                opCopy.setSlot("slot\(i)", value: substitute)
                            }
                        }
                        i += 1
                    }
                }
            }
        }
        // Check whether there are any references left
        // BUG: if we replace a reference by itself, it will be considered a mismatch here
        var i = 1
        while let opSlotValue = opCopy.slotvals["slot\(i)"] {
            if opSlotValue.chunk() != nil && opSlotValue.chunk()!.type == "reference" {
                return nil
            }
            i += 1
        }
 */
        return opCopy
    }
    
    
    /**
    This function finds an applicable operator and puts it in the operator buffer.
    
    - returns: Whether an operator was successfully found
    */
    func findOperator() -> Bool {
        let retrievalRQ = Chunk(s: "operator", m: model)
        retrievalRQ.setSlot("isa", value: "operator")
        var (latency,opRetrieved) = model.dm.retrieve(retrievalRQ)
            var cfs = model.dm.conflictSet.sorted(by: { (item1, item2) -> Bool in
                let (_,u1) = item1
                let (_,u2) = item2
                return u1 > u2
            })
        if !model.silent {
            model.addToTrace("Conflict Set", level: 5)
            for (chunk,activation) in cfs {
                let outputString = "  " + chunk.name + "A = " + String(format:"%.3f", activation) //+ "\(activation)"
                model.addToTrace(outputString, level: 5)
            }
        }
        var match = false
        var candidate: Chunk = Chunk(s: "empty", m: model)
        var candidateWithSubstitution: Chunk = Chunk(s: "empty", m: model)
        var activation: Double = 0.0
        var prim: Prim?
        if !cfs.isEmpty {
            repeat {
                (candidate, activation) = cfs.remove(at: 0)
                if let toBeCheckedOperator = checkOperatorGoalMatch(op: candidate) {
                    candidateWithSubstitution = toBeCheckedOperator.copyChunk()
                    model.buffers["operator"] = toBeCheckedOperator
                    let inst = model.procedural.findMatchingProduction()
                    (match, prim) = model.procedural.fireProduction(inst, compile: false)
                    model.buffers["imaginal"] = model.formerBuffers["imaginal"]
                    if let pr = prim {
                        if !match && !model.silent {
                            let s = "   Operator " + candidate.name + " does not match because of " + pr.name
                            model.addToTrace(s, level: 5)
                        }
                    }
// Temporary (?) commented out
//                    if match && candidate.spreadingActivation() <= 0.0 && model.buffers["operator"]?.slotValue("condition") != nil {
//                        match = false
//                        if !model.silent {
//                            let s = "   Rejected operator " + candidate.name + " because it has no associations and no production that tests all conditions"
//                            model.addToTrace(s, level: 2)
//                        }
//                        model.buffers["operator"] = nil
//                    }
                } else {
                    if !model.silent {
                        let s = "   Rejected operator " + candidate.name + " because its roles do not match any goal"
                        model.addToTrace(s, level: 3)
                    }
                }
            } while !match && !cfs.isEmpty && cfs[0].1 > model.dm.retrievalThreshold
        } else {
            match = false
            if !model.silent {
                model.addToTrace("   No matching operator found", level: 2)
            }
        }
        if match {
            opRetrieved = candidate
            latency = model.dm.latency(activation)
        } else {
            opRetrieved = nil
            if !model.silent {
                model.addToTrace("   No matching operator found", level: 2)
            }
            latency = model.dm.latency(model.dm.retrievalThreshold)
            }
        model.time += latency
        if opRetrieved == nil { return false }
        if model.dm.goalOperatorLearning {
            let item = (opRetrieved!, model.time - latency)
            previousOperators.append(item)
        }
        if !model.silent {
            if let opr = opRetrieved {
                model.addToTrace("*** Retrieved operator \(opr.name) with spread \(opr.spreadingActivation())", level: 1)
//                print("*** Retrieved operator \(opr.name) with spread \(opr.spreadingActivation())")
            }
        }
        model.dm.addToFinsts(opRetrieved!)
        model.buffers["goal"]!.setSlot("last-operator", value: opRetrieved!)
        model.buffers["operator"] = candidateWithSubstitution
        model.formerBuffers["operator"] = candidateWithSubstitution.copyLiteral()

        return true
    }
    
    
    /**
    This function carries out productions for the current operator until it has a PRIM that fails, in
    which case it returns false, or until all the conditions of the operator have been tested and
    all actions have been carried out.
    */
    func carryOutProductionsUntilOperatorDone() -> Bool {
        var match: Bool = true
        var first: Bool = true
        while match && (model.buffers["operator"]?.slotvals["condition"] != nil || model.buffers["operator"]?.slotvals["action"] != nil) {
            let inst = model.procedural.findMatchingProduction()
            var pname = inst.p.name
            if pname.hasPrefix("t") {
                pname = String(pname.characters.dropFirst())
            }
            if !model.silent {
                model.addToTrace("Firing \(pname)", level: 3)
            }
            (match, _) = model.procedural.fireProduction(inst, compile: true)
            if first {
                model.time += model.procedural.productionActionLatency
                first = false
            } else {
                model.time += model.procedural.productionAndPrimLatency
            }
        }
        return match
    }
    
    
}
