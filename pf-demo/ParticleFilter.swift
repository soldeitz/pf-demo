//
//  ParticleFilter.swift
//  ParticleFilter
//
//  Created by Michele Andreata on 27/07/22.
//
import Foundation

public class ParticleFilter {
    /// Time instant of the last prediction
    public var lastPredictionTime = -1.0
    
    /// Number of particles to draw
    public var numParticles: Int {
        get {
            return self._numParticles
        }
    }
    private var _numParticles: Int
    
    ///  Set of current particles
    public var particles = [Particle]()
    
    /// A simulated wall
    public var wall: Wall
    
    /// Used in the transition model to move the particles
    public var maxParticleVelocity: Double
    
    /// x and y deviation for initialization and random resampling
    public var defaultPositionStd: Point
    
    /// Interval in seconds at which it performs a random resampling
    public var randResampleInterval: Double {
        get {return self._randResampleInterval}
        set {
            self._randResampleInterval = newValue
            self.timer.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: _randResampleInterval, repeats: true) { _ in
                self.randomResampling = true
            }
        }
    }
    private var _randResampleInterval = 1.0
    private var timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {_ in }
    
    /// percentage (value between 0 and 100) of particles randomly resampled
    public var randResamplePercentage: Double {
        get {return self._randResamplePercentage}
        set {
            if newValue >= 0.0 && newValue <= 100.0 {
                self._randResamplePercentage = newValue
            }
            else if newValue > 100.0 {
                self._randResamplePercentage = 100.0
            }
            else {
                self._randResamplePercentage = 0.0
            }
        }
    }
    private var _randResamplePercentage = 10.0
    
    /// Percentage (value between 0 and 100) of the longest distance to the center of gravity. It defines the size of the approximationRadius
    public var apprxRadiusPercentage: Double {
        get {return self._apprxRadiusPercentage}
        set {
            if newValue >= 0.0 && newValue <= 100.0 {
                self._apprxRadiusPercentage = newValue
            }
            else if newValue > 100.0 {
                self._apprxRadiusPercentage = 100.0
            }
            else {
                self._apprxRadiusPercentage = 0.0
            }
        }
    }
    private var _apprxRadiusPercentage = 90.0
    
    public var isInitialized = false
    
    private var approxPos = ApproximatedPosition(position: Point(x: 0, y: 0), approximationRadius: 0)
    
    private var randomResampling = false
    
    public init(numParticles: Int, wall: Wall, maxParticleVelocity: Double, defaultPositionStd: Point, randResamplePercentage: Double, randResampleInterval: Double, apprxRadiusPercentage: Double) {
        self._numParticles = numParticles
        self.wall = wall
        self.maxParticleVelocity = maxParticleVelocity
        self.defaultPositionStd = defaultPositionStd
        self.randResampleInterval = randResampleInterval
        self.apprxRadiusPercentage = apprxRadiusPercentage
        self.randResamplePercentage = randResamplePercentage
    }
    
    public func predictPosition(_ arPosition: Point) -> ApproximatedPosition {
        let firstPosStd = self.defaultPositionStd
        
        if self.lastPredictionTime == -1 {
            self.approxPos = ApproximatedPosition(position: arPosition, approximationRadius: firstPosStd.x / 2)
            self.initializeDistribution(firstPosition: arPosition, firstPositionStd: firstPosStd)
            self.lastPredictionTime = Date().timeIntervalSince1970
        }
        else {
            let currentLastPredTime = Date().timeIntervalSince1970
            let dt = currentLastPredTime - self.lastPredictionTime
            self.lastPredictionTime = currentLastPredTime
            transitionModel(deltaT: dt)
        }
        
        self.perceptionModel(arPosition)
        
        self.resample()
        
        self.approxPos = self.estimatePosition()
        
        return self.approxPos
    }
    
    public func changeNumParticles(numParticles: Int, arPosition: Point, arPosStd: Point) {
        self._numParticles = numParticles
        self.particles.removeAll()
        self.initializeDistribution(firstPosition: arPosition, firstPositionStd: arPosStd)
    }
    
    /**
     * Initializes the particle filter by initializing particles to Gaussian
     * distribution around first position and all the weights set to 1
     */
    private func initializeDistribution(firstPosition firstPos: Point,  firstPositionStd firstPosStd: Point) {
        for idx in 0..<self.numParticles {
            let sampleX = gaussianDistribution(mean: firstPos.x, deviation: firstPosStd.x)
            let sampleY = gaussianDistribution(mean: firstPos.y, deviation: firstPosStd.y)
            let newParticle = Particle(id: idx, p: Point(x: sampleX, y: sampleY), weight: 1)
            self.particles.append(newParticle)
        }
        self.isInitialized = true
    }
    
    /**
     * chooses an angle randomly with uniform distribution on [0, 360]
     * chooses a velocity randomly with uniform ditribution on [0, maxParticleVelocity]
     * moves the particle in that direction
     * if displacement segment intercepts the wall, particle does not move
     */
    private func transitionModel(deltaT dt: Double) {
        for idx in 0..<self.numParticles {
            let oldPos = self.particles[idx].p
            let velocity = Double.random(in: 0...maxParticleVelocity)
            let angle = Double.random(in: 0 ... 2 * Double.pi)
            let newXPos = oldPos.x + velocity * dt * cos(angle)
            let newYPos = oldPos.y + velocity * dt * sin(angle)
            let newPos = Point(x: newXPos, y: newYPos)
            let int = getIntersection(newPos, oldPos, self.wall.from, self.wall.to)
            if int != nil {
                self.particles[idx].p = oldPos
            }
            else {
                self.particles[idx].p = newPos
            }
        }
    }
    
    private func perceptionModel(_ arPos: Point) {
        for idx in 0..<self.numParticles {
            let distance = distance(self.particles[idx].p, arPos)
            self.particles[idx].weight = 1 / (distance)
        }
    }
    
    /**
     * Resample particles with replacement with probability proportional to weight
     */
    private func resample() {
        let particlesCopy = self.particles
        self.particles.removeAll()
        
        var weights = [Double]()
        for p in particlesCopy {
            weights.append(p.weight)
        }
        
        let weightsDist = DiscreteDistribution(weights: weights)
        
        // With the discrete distribution pick out particles according to their
        // weights. The higher the weight of the particle, the higher are the chances
        // of the particle being included multiple times.
        // It also resamples randomly a percentage (randResamplePercentage) of the
        // particles every randResampleInterval seconds
        if self.randomResampling {
            let partialNumPart = Int(floor((1 - randResamplePercentage/100)*Double(particlesCopy.count)))
            let arPosStd = self.defaultPositionStd
            for i in 0..<partialNumPart {
                var p = particlesCopy[weightsDist.draw()]
                p.id = i
                self.particles.append(p)
            }
            for i in partialNumPart..<particlesCopy.count {
                let randX = gaussianDistribution(mean: self.approxPos.position.x, deviation: arPosStd.x)
                let randY = gaussianDistribution(mean: self.approxPos.position.y, deviation: arPosStd.y)
                let randomParticle = Particle(id: i, p: Point(x: randX, y: randY), weight: 1.0)
                self.particles.append(randomParticle)
            }
            self.randomResampling = false
        }
        else {
            for i in 0..<particlesCopy.count {
                var p = particlesCopy[weightsDist.draw()]
                p.id = i
                particles.append(p)
            }
        }
    }
    
    public func estimatePosition() -> ApproximatedPosition {
        let cogX = (self.particles.reduce(0.0, {$0 + $1.p.x})) / Double(self.particles.count)
        let cogY = (self.particles.reduce(0.0, {$0 + $1.p.y})) / Double(self.particles.count)
        let centerOfGravity = Point(x: cogX, y: cogY)
        
        let distances = self.particles.map{distance($0.p, centerOfGravity)}
        
        let maxDist = distances.max()
        let radius = (apprxRadiusPercentage/100.0) * maxDist!
        
//        let sortedDistances = distances.sorted(by: {$0<$1})
//        let idx = Int(floor((apprxRadiusPercentage/100.0)*Double(self.particles.count - 1)))
//        let radius = sortedDistances[idx]

        return ApproximatedPosition(position: centerOfGravity, approximationRadius: radius)
    }
}

public struct Point {
    var x: Double
    var y: Double
}

public struct Particle: Identifiable {
    public var id: Int
    var p: Point
    var weight: Double
}

public struct ApproximatedPosition {
    var position: Point
    var approximationRadius: Double
}

public struct Wall {
    var from: Point
    var to: Point
}

/**
 * Gaussian Distribution using the Box-Muller Transformation
 */
func gaussianDistribution(mean: Double, deviation: Double) -> Double {
    guard deviation > 0 else { return mean }
    
    let x1 = Double.random(in: 0 ..< 1)
    let x2 = Double.random(in: 0 ..< 1)
    let z1 = sqrt(-2 * log(x1)) * cos(2 * Double.pi * x2) // z1 is normally distributed
    
    // Convert z1 from the Standard Normal Distribution to Normal Distribution
    return z1 * deviation + mean
}

/**
 * Random number distribution that produces integer values according to a discrete distribution
 * It works the same as in: https://cplusplus.com/reference/random/discrete_distribution/
 */
class DiscreteDistribution {
    private var cumsum: [Double]
    
    init(weights w: [Double]) {
        let sum = w.reduce(0) {$0+$1}
        let probDist = w.map {$0 / sum} // it is the weights vector normalized
        self.cumsum = (probDist.reduce(into: [0.0]) { $0.append($0.last! + $1) }).dropLast(1)
    }
    
//    func draw() -> Int {
//        let r = Double.random(in: 0..<1)
//        var idx = 0
//        while (idx < self.cumsum.count && self.cumsum[idx] < r) {
//            idx += 1
//        }
//        return idx - 1
//    }
    
    func draw() -> Int {
        let r = Double.random(in: 0..<1)
        if (r >= self.cumsum[self.cumsum.count-1]) {
            return self.cumsum.count - 1
        }
        return drawRecursive(r: r, start: 0, end: self.cumsum.count-1)
    }

    private func drawRecursive(r: Double, start: Int, end: Int) -> Int {
        if (r >= self.cumsum[start] && r < self.cumsum[start + 1]) {
            return start
        }
        let middle = Int((start + end) / 2)
        if (r <= self.cumsum[middle]) {
            return drawRecursive(r: r, start: start, end: middle)
        }
        else {
            return drawRecursive(r: r, start: middle, end: end)
        }
    }
}

/**
 * Returns true if the lines intercept, otherwise false. In addition, if they intersect, the
 * intersection point is stored in Point i
 * Readapted for swift from:
 * https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect/#1968345
 */
func getIntersection(_ p0: Point,_ p1: Point,_ p2: Point,_ p3: Point) -> Point? {
    let s1 = Point(x: (p1.x - p0.x), y: (p1.y - p0.y))
    let s2 = Point(x: (p3.x - p2.x), y: (p3.y - p2.y))
    
    let s = (-s1.y * (p0.x - p2.x) + s1.x * (p0.y - p2.y)) / (-s2.x * s1.y + s1.x * s2.y)
    let t = ( s2.x * (p0.y - p2.y) - s2.y * (p0.x - p2.x)) / (-s2.x * s1.y + s1.x * s2.y)
    
    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
        return Point(x: p0.x + (t * s1.x), y: p0.y + (t * s1.y))
    }
    else {
        return nil
    }
}

func distance(_ p1: Point,_ p2: Point) -> Double {
    return sqrt((p1.x - p2.x)*(p1.x - p2.x) + (p1.y - p2.y)*(p1.y - p2.y))
}
