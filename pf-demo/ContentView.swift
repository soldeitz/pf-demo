//
//  ContentView.swift
//  pf-demo
//
//  Created by Michele Andreata on 04/09/22.
//

import SwiftUI
import Combine

let SCREEN_WIDTH = UIScreen.main.bounds.width
let SCREEN_HEIGHT = UIScreen.main.bounds.height

let WIDTH = SCREEN_WIDTH - 350
let HEIGHT = SCREEN_HEIGHT - 20

let initialWall = Wall(from: Point(x: (WIDTH / 3)*2, y: HEIGHT / 4), to: Point(x: (WIDTH / 3)*2, y: (HEIGHT / 4)*3))
let initialNumParticles = 300
let initialMaxParticleVel = 200.0
let initialDefaultPosStd = Point(x: 30, y: 30)
let initialRandResPercentage = 0.01
let initialRandResInterval = 1.0
let initialApprxRadiusPercentage = 0.9
let initialTimerInterval = 0.1

let initialApproxPos = ApproximatedPosition(position: Point(x: WIDTH / 3, y: HEIGHT / 2), approximationRadius: 20)
let initialActualPos = Point(x: WIDTH / 3, y: HEIGHT / 2)

struct ContentView: View {
    
    @State var numParticles = initialNumParticles
    @State var maxParticleVel = initialMaxParticleVel
    @State var defaultPosStd = initialDefaultPosStd
    @State var randResPercentage = initialRandResPercentage
    @State var randResInterval = initialRandResInterval
    @State var apprxRadiusPercentage = initialApprxRadiusPercentage
    @State var timerInterval = initialTimerInterval
    
    @State var pf = ParticleFilter(
        numParticles: initialNumParticles,
        wall: initialWall,
        maxParticleVelocity: initialMaxParticleVel,
        defaultPositionStd: initialDefaultPosStd,
        randResamplePercentage: initialRandResPercentage,
        randResampleInterval: initialRandResInterval,
        apprxRadiusPercentage: initialApprxRadiusPercentage)
    @State var approxPos = initialApproxPos
    @State var actualPos = initialActualPos
    
    @State var timer = Timer.scheduledTimer(withTimeInterval: initialTimerInterval, repeats: true, block: {_ in })
    let floatFormatter = NumberFormatter()
    
    init() {
        self.floatFormatter.usesSignificantDigits = true
    }

    
    var body: some View {
        return HStack {
            VStack {
                Text("Timer interval:")
                    .font(Font.title2)
                TextField("", value: $timerInterval, formatter: floatFormatter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.timer.invalidate()
                        self.timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                            self.approxPos = self.pf.predictPosition(self.actualPos)
                        }
                        self.timer.fire()
                    }
                Text("Number of particles:")
                    .font(Font.title2)
                TextField("", value: $numParticles, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.changeNumParticles(numParticles: self.numParticles, arPosition: self.approxPos.position, arPosStd: self.defaultPosStd)
                    }
                Text("Maximum particle velocity:")
                    .font(Font.title2)
                TextField("", value: $maxParticleVel, formatter: floatFormatter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.maxParticleVelocity = self.maxParticleVel
                    }
                Text("Random resample interval:")
                    .font(Font.title2)
                TextField("", value: $randResInterval, formatter: floatFormatter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.randResampleInterval = self.randResInterval
                    }
                Text("Random resample percentage:")
                    .font(Font.title2)
                TextField("", value: $randResPercentage, formatter: floatFormatter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.randResamplePercentage = self.randResPercentage
                    }
                
            }
            PFView(pf: $pf, approxPos: $approxPos, actualPos: $actualPos)
        }.onAppear {
            self.timer.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                self.approxPos = self.pf.predictPosition(self.actualPos)
            }
        }
    }
}

struct PFView: View {
    @Binding var pf: ParticleFilter
    @Binding var approxPos: ApproximatedPosition
    @Binding var actualPos: Point

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(pf.particles, id: \.id) { particle in
                Circle()
                    .frame(width: 4, height: 4, alignment: .center)
                    .offset(x: particle.p.x, y: particle.p.y)
            }
            Circle()
                .fill(.blue)
                .frame(width: 10, height: 10, alignment: .center)
                .offset(x: approxPos.position.x - 5, y: approxPos.position.y - 5)
            Circle()
                .stroke(.blue)
                .frame(width: approxPos.approximationRadius * 2, height: approxPos.approximationRadius * 2, alignment: .topLeading)
                .offset(x: (approxPos.position.x - approxPos.approximationRadius), y: (approxPos.position.y - approxPos.approximationRadius))
            Path { path in
                path.move(to: CGPoint(x: pf.wall.from.x, y: pf.wall.from.y))
                path.addLine(to: CGPoint(x: pf.wall.to.x, y: pf.wall.to.y))
            }
                .strokedPath(StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round))
                .foregroundColor(.red)
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10, alignment: .center)
                .offset(x: actualPos.x - 5, y: actualPos.y - 5)
        }
            .frame(width: WIDTH, height: HEIGHT)
            .clipped().contentShape(Rectangle()).border(.blue).padding()
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        self.approxPos = self.pf.predictPosition(Point(x: value.location.x, y: value.location.y))
                        self.actualPos = Point(x: value.location.x, y: value.location.y)
                    }
              )
    }
}
