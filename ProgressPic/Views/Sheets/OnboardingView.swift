//
//  OnboardingView.swift
//  ProgressPic
//
//  Created by Claude
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showTemplateSelection = false
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.fill",
            title: "Track Your Progress",
            description: "Take consistent progress photos and watch your transformation unfold over time",
            color: Color(red: 0.24, green: 0.85, blue: 0.80)
        ),
        OnboardingPage(
            icon: "ruler.fill",
            title: "Measure & Analyze",
            description: "Track body measurements and visualize your progress with detailed charts",
            color: Color(red: 0.24, green: 0.85, blue: 0.80)
        ),
        OnboardingPage(
            icon: "square.split.2x1.fill",
            title: "Compare & Share",
            description: "Compare photos side-by-side, create timelapse videos, and celebrate your wins",
            color: Color(red: 0.24, green: 0.85, blue: 0.80)
        ),
        OnboardingPage(
            icon: "icloud.fill",
            title: "Sync Everywhere",
            description: "Your data syncs automatically across all your devices with iCloud",
            color: Color(red: 0.24, green: 0.85, blue: 0.80)
        )
    ]
    
    var body: some View {
        ZStack {
            AppStyle.Colors.bgDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                }
                .opacity(currentPage < pages.count - 1 ? 1 : 0)
                
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                // Bottom button
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        // Get Started button on last page
                        Button(action: {
                            showTemplateSelection = true
                        }) {
                            HStack {
                                Text("Get Started")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.24, green: 0.85, blue: 0.80),
                                        Color(red: 0.20, green: 0.70, blue: 0.70)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    } else {
                        // Next button
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showTemplateSelection) {
            JourneyTemplateSelectionView {
                completeOnboarding()
            }
        }
    }
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "HasCompletedOnboarding")
        dismiss()
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)
                
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(page.color)
            }
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
    }
}

// Journey template selection
struct JourneyTemplateSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let onComplete: () -> Void
    
    @State private var selectedTemplate: JourneyTemplate?
    
    let templates: [JourneyTemplate] = [
        JourneyTemplate(
            name: "Weight Loss Journey",
            icon: "figure.walk",
            description: "Track your weight loss progress with photos and measurements",
            measurements: [.weight, .waist, .hips, .chest]
        ),
        JourneyTemplate(
            name: "Muscle Building",
            icon: "figure.strengthtraining.traditional",
            description: "Monitor muscle growth and strength gains",
            measurements: [.weight, .chest, .bicepsLeft, .bicepsRight, .thighLeft, .thighRight]
        ),
        JourneyTemplate(
            name: "Body Recomposition",
            icon: "figure.mixed.cardio",
            description: "Transform your physique by building muscle and losing fat",
            measurements: [.weight, .bodyFat, .waist, .chest, .bicepsLeft, .bicepsRight]
        ),
        JourneyTemplate(
            name: "Custom Journey",
            icon: "star.fill",
            description: "Start from scratch and customize everything",
            measurements: []
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppStyle.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Choose Your Journey")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Select a template to get started quickly, or create your own")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal)
                        
                        // Templates
                        VStack(spacing: 16) {
                            ForEach(templates) { template in
                                TemplateCard(
                                    template: template,
                                    isSelected: selectedTemplate?.id == template.id
                                ) {
                                    selectedTemplate = template
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Create button
                        if selectedTemplate != nil {
                            Button(action: {
                                createJourneyFromTemplate()
                            }) {
                                Text("Create Journey")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.24, green: 0.85, blue: 0.80),
                                                Color(red: 0.20, green: 0.70, blue: 0.70)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        // Skip button
                        Button("I'll create my own later") {
                            onComplete()
                        }
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { onComplete() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func createJourneyFromTemplate() {
        guard let template = selectedTemplate else { return }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Create journey
        let journey = Journey(
            name: template.name,
            saveToCameraRoll: false,
            autoSyncStartDate: true,
            template: template.name
        )
        ctx.insert(journey)
        
        // Save
        do {
            try ctx.save()
            AppConstants.Log.app.info("Created journey from template: \(template.name)")
        } catch {
            AppConstants.Log.app.error("Failed to create journey: \(error.localizedDescription)")
        }
        
        // Complete onboarding
        onComplete()
    }
}

struct JourneyTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let measurements: [MeasurementType]
}

struct TemplateCard: View {
    let template: JourneyTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 0.24, green: 0.85, blue: 0.80).opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? Color(red: 0.24, green: 0.85, blue: 0.80) : .white)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(red: 0.24, green: 0.85, blue: 0.80))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(red: 0.24, green: 0.85, blue: 0.80) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
}

