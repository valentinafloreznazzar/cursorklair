import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var age: Int = 28
    @State private var weightKg: Double = 62
    @State private var heightCm: Double = 168
    @State private var selectedGoals: Set<String> = []
    @State private var selectedConditions: Set<String> = []
    @State private var medications: [String] = []
    @State private var medicationInput = ""
    @State private var ouraConnecting = false
    @State private var ouraConnected = false
    @State private var appearAnimation = false

    let onComplete: () -> Void

    private let totalSteps = 4

    var body: some View {
        ZStack {
            KlairTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                progressIndicator
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                TabView(selection: $currentStep) {
                    basicInfoStep.tag(0)
                    goalsStep.tag(1)
                    medicalStep.tag(2)
                    ouraPairingStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentStep)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? KlairTheme.cyan : KlairTheme.surfaceHigh)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Basic Info

    private var basicInfoStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                stepHeader(icon: "person.crop.circle", color: KlairTheme.cyan, title: "About You", subtitle: "Help Klair personalize your experience")
                    .padding(.top, 32)

                VStack(spacing: 20) {
                    pickerCard(title: "AGE", icon: "calendar", color: KlairTheme.cyan) {
                        Picker("Age", selection: $age) {
                            ForEach(16...80, id: \.self) { Text("\($0) years").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }

                    HStack(spacing: 16) {
                        pickerCard(title: "WEIGHT", icon: "scalemass", color: KlairTheme.orange) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(weightKg))")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundStyle(KlairTheme.textPrimary)
                                Text("kg")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(KlairTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            Slider(value: $weightKg, in: 35...150, step: 1)
                                .tint(KlairTheme.orange)
                        }

                        pickerCard(title: "HEIGHT", icon: "ruler", color: KlairTheme.amethyst) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(heightCm))")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundStyle(KlairTheme.textPrimary)
                                Text("cm")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(KlairTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            Slider(value: $heightCm, in: 130...220, step: 1)
                                .tint(KlairTheme.amethyst)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Step 2: Goals

    private var goalsStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(icon: "target", color: KlairTheme.amethyst, title: "Your Goals", subtitle: "Select what matters most to you")
                    .padding(.top, 32)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(goalOptions, id: \.title) { goal in
                        goalCard(goal: goal)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
    }

    private func goalCard(goal: GoalOption) -> some View {
        let isSelected = selectedGoals.contains(goal.title)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected { selectedGoals.remove(goal.title) }
                else { selectedGoals.insert(goal.title) }
            }
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isSelected
                            ? LinearGradient(colors: [goal.color.opacity(0.25), goal.color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [KlairTheme.surfaceHigh.opacity(0.4), KlairTheme.surfaceHigh.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 70)
                    Image(systemName: goal.icon)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(isSelected ? goal.color : KlairTheme.textTertiary)
                        .symbolEffect(.bounce, value: isSelected)
                }
                Text(goal.title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(isSelected ? KlairTheme.textPrimary : KlairTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .padding(14)
            .background(KlairTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                    .stroke(isSelected ? goal.color.opacity(0.4) : .clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? goal.color.opacity(0.15) : KlairTheme.cloudShadow, radius: isSelected ? 16 : 10, y: isSelected ? 8 : 4)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Medical Context

    private var medicalStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(icon: "cross.case", color: KlairTheme.emerald, title: "Health Context", subtitle: "Optional — helps Klair give better insights")
                    .padding(.top, 32)

                VStack(alignment: .leading, spacing: 16) {
                    Text("CONDITIONS")
                        .font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary)
                    ForEach(conditionOptions, id: \.self) { condition in
                        conditionRow(condition)
                    }
                }
                .padding(20)
                .background(KlairTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
                .cloudShadow()

                VStack(alignment: .leading, spacing: 16) {
                    Text("MEDICATIONS")
                        .font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary)
                    HStack(spacing: 10) {
                        TextField("Add medication...", text: $medicationInput)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(12)
                            .background(KlairTheme.surfaceHigh.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .submitLabel(.done)
                            .onSubmit { addMedication() }
                        Button(action: addMedication) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(KlairTheme.emerald)
                        }
                        .disabled(medicationInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !medications.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(medications, id: \.self) { med in
                                HStack(spacing: 6) {
                                    Image(systemName: "pill.fill").font(.system(size: 10))
                                    Text(med).font(.system(.caption, design: .rounded).weight(.medium))
                                    Button { withAnimation { medications.removeAll { $0 == med } } } label: {
                                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                    }
                                }
                                .foregroundStyle(KlairTheme.amethyst)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(KlairTheme.amethyst.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(20)
                .background(KlairTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
                .cloudShadow()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
    }

    private func conditionRow(_ condition: String) -> some View {
        let isSelected = selectedConditions.contains(condition)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected { selectedConditions.remove(condition) }
                else { selectedConditions.insert(condition) }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? KlairTheme.emerald : KlairTheme.surfaceHigh.opacity(0.5))
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
                Text(condition).font(.system(.subheadline, design: .rounded)).foregroundStyle(KlairTheme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Oura Pairing

    private var ouraPairingStep: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(KlairTheme.cyan.opacity(0.15), lineWidth: 2)
                    .frame(width: 180, height: 180)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [KlairTheme.cyan.opacity(0.6), KlairTheme.amethyst.opacity(0.6), KlairTheme.cyan.opacity(0.6)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(ouraConnecting ? 360 : 0))
                    .animation(ouraConnecting ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: ouraConnecting)

                VStack(spacing: 8) {
                    Image(systemName: ouraConnected ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 44))
                        .foregroundStyle(ouraConnected ? KlairTheme.emerald : KlairTheme.cyan)
                        .symbolEffect(.bounce, value: ouraConnected)
                    Text(ouraConnected ? "Connected" : "Oura Ring")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(KlairTheme.textPrimary)
                }
            }

            VStack(spacing: 12) {
                Text("Connect Your Oura Ring")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(KlairTheme.textPrimary)
                Text("Klair syncs sleep, HRV, activity, and temperature data for personalized insights.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlairTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !ouraConnected {
                Button {
                    ouraConnecting = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.spring(response: 0.4)) {
                            ouraConnecting = false
                            ouraConnected = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 14, weight: .bold))
                        Text("Pair Oura Ring")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 16)
                    .background(KlairTheme.cyanGradient)
                    .clipShape(Capsule())
                    .shadow(color: KlairTheme.cyan.opacity(0.3), radius: 16, y: 8)
                }

                Button {
                    // skip pairing
                } label: {
                    Text("Skip for now")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(KlairTheme.textTertiary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlairTheme.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(KlairTheme.surfaceHigh.opacity(0.5))
                        .clipShape(Circle())
                }
            }

            Spacer()

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    saveAndComplete()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep < totalSteps - 1 ? "Continue" : "Get Started")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Image(systemName: currentStep < totalSteps - 1 ? "arrow.right" : "sparkles")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 16)
                .background(KlairTheme.heroGradient)
                .clipShape(Capsule())
                .shadow(color: KlairTheme.amethyst.opacity(0.3), radius: 16, y: 8)
            }
        }
    }

    // MARK: - Helpers

    private func stepHeader(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(KlairTheme.textPrimary)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlairTheme.textSecondary)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    private func pickerCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
                Text(title).font(.system(size: 10, weight: .semibold)).kerning(1.2).foregroundStyle(KlairTheme.textTertiary)
            }
            content()
        }
        .padding(16)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 16, y: 6)
    }

    private func addMedication() {
        let trimmed = medicationInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation { medications.append(trimmed) }
        medicationInput = ""
    }

    private func saveAndComplete() {
        let profile = UserProfile(
            knownConditions: selectedConditions.sorted().joined(separator: ", "),
            healthGoals: selectedGoals.sorted().joined(separator: ", "),
            hasCompletedOnboarding: true, age: age, ouraConnected: ouraConnected
        )
        profile.weightKg = weightKg
        profile.heightCm = heightCm
        profile.medications = medications.joined(separator: ", ")
        modelContext.insert(profile)
        try? modelContext.save()
        onComplete()
    }

    // MARK: - Data

    private var goalOptions: [GoalOption] {
        [
            GoalOption(title: "Optimize Sleep", icon: "moon.zzz.fill", color: KlairTheme.indigo),
            GoalOption(title: "Manage Stress", icon: "brain.head.profile.fill", color: KlairTheme.cyan),
            GoalOption(title: "Hormonal Health", icon: "leaf.circle.fill", color: KlairTheme.emerald),
            GoalOption(title: "Build Strength", icon: "dumbbell.fill", color: KlairTheme.orange),
            GoalOption(title: "Improve Focus", icon: "eye.circle.fill", color: KlairTheme.amethyst),
            GoalOption(title: "Weight Balance", icon: "scalemass.fill", color: KlairTheme.coral),
        ]
    }

    private var conditionOptions: [String] {
        ["PCOS", "Anemia", "Insulin Sensitivity", "Thyroid Condition", "Iron Deficiency", "Celiac Disease", "Endometriosis", "Anxiety / Depression"]
    }
}

private struct GoalOption {
    let title: String; let icon: String; let color: Color
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing; rowHeight = max(rowHeight, s.height)
        }
    }
}
