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
let initialRandResPercentage = 1.0
let initialRandResInterval = 1.0
let initialApprxRadiusPercentage = 90.0
let initialTimerInterval = 0.1

let initialApproxPos = ApproximatedPosition(position: Point(x: WIDTH / 3, y: HEIGHT / 2), approximationRadius: 20)
let initialActualPos = Point(x: WIDTH / 3, y: HEIGHT / 2)

struct ContentView: View {
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
    @State var toggleTimer = true
    
    var body: some View {
        return HStack {
            FormView(pf: $pf, actualPos: $actualPos, approxPos: $approxPos, toggleTimer: $toggleTimer)
            PFView(pf: $pf, approxPos: $approxPos, actualPos: $actualPos, toggleTimer: $toggleTimer)
        }.preferredColorScheme(.dark).edgesIgnoringSafeArea(.all).statusBar(hidden: true)
    }
}

struct FormView: View {
    
    @Binding var pf: ParticleFilter
    @Binding var approxPos: ApproximatedPosition
    @Binding var actualPos: Point
    @Binding var toggleTimer: Bool
    
    @State var numParticles = initialNumParticles
    @State var maxParticleVel = initialMaxParticleVel
    @State var defaultPosStd = initialDefaultPosStd
    @State var randResPercentage = initialRandResPercentage
    @State var randResInterval = initialRandResInterval
    @State var apprxRadiusPercentage = initialApprxRadiusPercentage
    @State var timerInterval = initialTimerInterval
    
    @State var timer = Timer.scheduledTimer(withTimeInterval: initialTimerInterval, repeats: true, block: {_ in })

    let floatFormatter = NumberFormatter()
    
    init(pf: Binding<ParticleFilter>, actualPos: Binding<Point>, approxPos: Binding<ApproximatedPosition>, toggleTimer: Binding<Bool>) {
        self._pf = pf
        self._actualPos = actualPos
        self._approxPos = approxPos
        self._toggleTimer = toggleTimer
        
        floatFormatter.usesSignificantDigits = true
    }

    func updateParticleFilter() {
        self.approxPos = self.pf.predictPosition(self.actualPos)
    }
    
    var body: some View {
        return VStack {
            Group {
                Text("Timer interval:")
                    .font(Font.title2)
                HStack {
                    TextField("", value: $timerInterval, formatter: floatFormatter)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Font.title2)
                        .padding(.leading, 10)
                        .onSubmit {
                            self.timer.invalidate()
                            self.timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                                updateParticleFilter()
                            }
                            self.timer.fire()
                        }
                    Text("s").font(Font.title2)
                }
            }
            Group {
                Text("Number of particles:")
                    .font(Font.title2)
                TextField("", value: $numParticles, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.changeNumParticles(numParticles: self.numParticles, arPosition: self.approxPos.position, arPosStd: self.defaultPosStd)
                    }
            }
            Group {
                Text("Maximum particle velocity:")
                    .font(Font.title2)
                TextField("", value: $maxParticleVel, formatter: floatFormatter)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Font.title2)
                    .padding(.leading, 10)
                    .onSubmit {
                        self.pf.maxParticleVelocity = self.maxParticleVel
                    }
            }
            Group {
                Text("Random resample interval:")
                    .font(Font.title2)
                HStack {
                    TextField("", value: $randResInterval, formatter: floatFormatter)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Font.title2)
                        .padding(.leading, 10)
                        .onSubmit {
                            self.pf.randResampleInterval = self.randResInterval
                        }
                    Text("s").font(Font.title2)
                }
            }
            Group {
                Text("Random resample percentage:")
                    .font(Font.title2)
                HStack {
                    TextField("", value: $randResPercentage, formatter: floatFormatter)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Font.title2)
                        .padding(.leading, 10)
                        .onSubmit {
                            self.pf.randResamplePercentage = self.randResPercentage
                        }
                    Text("%").font(Font.title2)
                }
            }
            Toggle(isOn: $toggleTimer) {
                Text("Toggle Timer").font(Font.title2)
            }
                .onChange(of: toggleTimer) { value in
                    if (value) {
                        self.timer.invalidate()
                        self.timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                            updateParticleFilter()
                        }
                    }
                    else {
                        self.timer.invalidate()
                    }
                }
                .padding()
        }.onAppear {
            self.timer.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
                updateParticleFilter()
            }
        }
    }
}

let BLUE = Color(red: 0.0078, green: 0.5176, blue: 1.0)
let GREEN = Color(red: 0.0706, green: 0.9020, blue: 0.5686)
let RED = Color(red: 0.9960, green: 0.0, blue: 0.2276)
let ORANGE = Color(red: 1.0, green: 0.7686, blue: 0.2392)

struct PFView: View {
    @Binding var pf: ParticleFilter
    @Binding var approxPos: ApproximatedPosition
    @Binding var actualPos: Point
    
    @Binding var toggleTimer: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Particles of the PF
            ForEach(pf.particles, id: \.id) { particle in
                Circle()
                    .frame(width: 4, height: 4, alignment: .center)
                    .offset(x: particle.p.x, y: particle.p.y)
            }
            // Particle representing the calculated approximate position
            Circle()
                .fill(BLUE)
                .frame(width: 10, height: 10, alignment: .center)
                .offset(x: approxPos.position.x - 5, y: approxPos.position.y - 5)
            // Approximation radius
            Circle()
                .stroke(BLUE)
                .frame(width: approxPos.approximationRadius * 2, height: approxPos.approximationRadius * 2, alignment: .topLeading)
                .offset(x: (approxPos.position.x - approxPos.approximationRadius), y: (approxPos.position.y - approxPos.approximationRadius))
            // Wall
            Path { path in
                path.move(to: CGPoint(x: pf.wall.from.x, y: pf.wall.from.y))
                path.addLine(to: CGPoint(x: pf.wall.to.x, y: pf.wall.to.y))
            }
                .strokedPath(StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .round))
                .foregroundColor(RED)
            // First wall knob
            Circle()
                .fill(ORANGE)
                .frame(width: 16, height: 16, alignment: .center)
                .offset(x: pf.wall.from.x - 8, y: pf.wall.from.y - 8)
                .gesture(DragGesture()
                    .onChanged { value in
                        pf.wall.from.x = value.location.x
                        pf.wall.from.y = value.location.y
                    })
            // Second wall knob
            Circle()
                .fill(ORANGE)
                .frame(width: 16, height: 16, alignment: .center)
                .offset(x: pf.wall.to.x - 8, y: pf.wall.to.y - 8)
                .gesture(DragGesture()
                    .onChanged { value in
                        pf.wall.to.x = value.location.x
                        pf.wall.to.y = value.location.y
                    })
            // Actual position defined by user input
            Circle()
                .fill(GREEN)
                .frame(width: 10, height: 10, alignment: .center)
                .offset(x: actualPos.x - 5, y: actualPos.y - 5)
        }
            .frame(width: WIDTH, height: HEIGHT)
            .clipped().contentShape(Rectangle()).border(BLUE).padding()
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if (toggleTimer) {
                            self.actualPos = Point(x: value.location.x, y: value.location.y)
                        }
                        else {
                            self.approxPos = self.pf.predictPosition(Point(x: value.location.x, y: value.location.y))
                            self.actualPos = Point(x: value.location.x, y: value.location.y)
                        }
                    }
              )
    }
}
