//
//  ContentView.swift
//  WatchOSExample Watch App
//
//  Created by Samuel Osborne on 13/04/2026.
//

import SwiftUI
import DotLottie

struct ContentView: View {
    let animation = DotLottieAnimation(fileName: "radial", config: AnimationConfig())

    var body: some View {
        animation.view()
            .ignoresSafeArea()
            .onAppear {
            let l = self.animation.stateMachineLoad(id: "Numeric input")
            let s = self.animation.stateMachineStart()
            print(l,s)
        }
    }
}

#Preview {
    ContentView()
}
