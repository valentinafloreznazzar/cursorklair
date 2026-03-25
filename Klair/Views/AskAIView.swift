import SwiftUI
import SwiftData

struct AskAIView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var profiles: [UserProfile]
    @State private var viewModel: AskAIViewModel?
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let vm = viewModel {
                chatShell(vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(KlairTheme.background.ignoresSafeArea())
        .onAppear {
            if viewModel == nil { viewModel = AskAIViewModel(modelContext: modelContext) }
            viewModel?.loadProactiveState()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ask Klair")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(KlairTheme.textPrimary)
                Text("Chat con Gemini · datos de la app en cada mensaje")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlairTheme.textTertiary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(KlairTheme.heroGradient)
                    .frame(width: 36, height: 36)
                KlairLogo(size: 22, color: .white.opacity(0.9))
            }
            .shadow(color: KlairTheme.amethyst.opacity(0.2), radius: 8, y: 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Chat shell (messages + composer)

    private func chatShell(_ vm: AskAIViewModel) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        welcomeCard(vm)
                        proactiveReminders
                        insightBanner(vm)
                        chatMessages(vm)
                        if vm.isSending {
                            typingIndicator
                                .onAppear { SensoryManager.shared.startTypingSound() }
                                .onDisappear { SensoryManager.shared.stopTypingSound() }
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // `.interactively` can steal gestures from the composer on device; composer is outside this ScrollView anyway.
                .scrollDismissesKeyboard(.never)
                .clipped()
                .onChange(of: vm.bubbles.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: vm.isSending) { _, sending in
                    if sending {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                Divider().opacity(0.35)
                suggestedChips(vm)
                chatComposer(vm)
            }
            .background(
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            // Keep composer above the message list for hit testing (ScrollView + overlay quirks).
            .zIndex(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                .fill(KlairTheme.card)
                .shadow(color: KlairTheme.cloudShadow, radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [KlairTheme.cyan.opacity(0.35), KlairTheme.amethyst.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Proactive Reminders (Meds/Water)

    @ViewBuilder
    private var proactiveReminders: some View {
        let meds = profile?.medicationsList ?? []
        let waterProgress = profile?.waterProgress ?? 0

        if !meds.isEmpty || waterProgress < 0.6 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 12)).foregroundStyle(KlairTheme.amethyst)
                    Text("PROACTIVE REMINDERS").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                }

                if waterProgress < 0.6 {
                    reminderCard(
                        icon: "drop.fill", iconColor: KlairTheme.cyan,
                        title: "Hydration Check",
                        body: "You're at \(Int(waterProgress * 100))% of your daily goal. Dehydration can reduce HRV by ~5% and impair recovery.",
                        action: "Log Water"
                    )
                }

                if !meds.isEmpty {
                    reminderCard(
                        icon: "pill.fill", iconColor: KlairTheme.amethyst,
                        title: "Medication Reminder",
                        body: "Have you taken today's: \(meds.prefix(3).joined(separator: ", "))?",
                        action: "Mark Taken"
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private func reminderCard(icon: String, iconColor: Color, title: String, body: String, action: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(iconColor))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                Text(body).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                Button {} label: {
                    Text(action).font(.system(size: 10, weight: .bold)).foregroundStyle(iconColor)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(iconColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(KlairTheme.surfaceHigh.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .tapScale()
    }

    // MARK: - Welcome Card

    @ViewBuilder
    private func welcomeCard(_ vm: AskAIViewModel) -> some View {
        let userChats = vm.bubbles.filter { $0.role == "user" }.count
        if userChats == 0 {
            let firstName = profile?.name.split(separator: " ").first.map(String.init) ?? "there"
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(KlairTheme.amethyst.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "sparkles").font(.system(size: 16)).foregroundStyle(KlairTheme.amethyst))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello, \(firstName)").font(.system(.headline, design: .rounded)).foregroundStyle(KlairTheme.textPrimary)
                        Text("I’m Klair — type in the chat box below. I use your sleep, meals, Oura trends, labs, cycle, and energy logs.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KlairTheme.surfaceHigh.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
            .padding(.top, 4)
        }
    }

    // MARK: - Insights

    @ViewBuilder
    private func insightBanner(_ vm: AskAIViewModel) -> some View {
        if !vm.proactiveInsights.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.proactiveInsights, id: \.title) { i in insightChip(i) }
                }
            }
        }
    }

    private func insightChip(_ insight: ProactiveInsight) -> some View {
        let chipColor: Color = insight.severity == "warning" ? KlairTheme.coral : insight.severity == "info" ? KlairTheme.cyan : KlairTheme.emerald
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(chipColor).frame(width: 6, height: 6)
                Text(insight.title).font(.system(size: 10, weight: .bold)).kerning(0.4).foregroundStyle(chipColor)
            }
            Text(insight.body).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3).lineLimit(3)
        }
        .padding(12).frame(width: 200, alignment: .topLeading)
        .background(KlairTheme.surfaceHigh.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .tapScale()
    }

    // MARK: - Chat

    @ViewBuilder
    private func chatMessages(_ vm: AskAIViewModel) -> some View {
        if vm.bubbles.isEmpty {
            Text("No messages yet — say hi below.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlairTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            ForEach(vm.bubbles) { bubble in chatBubble(bubble) }
        }
    }

    private func chatBubble(_ msg: ChatBubble) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 8) }
            if !isUser {
                ZStack {
                    Circle().fill(KlairTheme.heroGradient).frame(width: 26, height: 26)
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(.white.opacity(0.95))
                }
            }
            Text(msg.text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(isUser ? .white : KlairTheme.textPrimary)
                .lineSpacing(4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    if isUser {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(KlairTheme.heroGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(KlairTheme.surfaceHigh.opacity(0.55))
                    }
                }
                .shadow(color: isUser ? KlairTheme.amethyst.opacity(0.15) : KlairTheme.cloudShadow, radius: 8, y: 3)
                .frame(maxWidth: 300, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 8) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle().fill(KlairTheme.heroGradient).frame(width: 26, height: 26)
                Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(.white.opacity(0.95))
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(KlairTheme.textTertiary).frame(width: 5, height: 5).opacity(0.3 + 0.3 * sin(Double(i) * .pi / 1.5))
                }
            }
            .padding(10)
            .background(KlairTheme.surfaceHigh.opacity(0.5))
            .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - Suggested

    @ViewBuilder
    private func suggestedChips(_ vm: AskAIViewModel) -> some View {
        if !vm.suggestedQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 11)).foregroundStyle(KlairTheme.cyan)
                    Text("QUICK ASKS")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(KlairTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.suggestedQuestions, id: \.self) { q in
                            Button { send(q, vm: vm) } label: {
                                Text(q)
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .foregroundStyle(KlairTheme.softSlate)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(KlairTheme.cyan.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .disabled(vm.isSending)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Composer (chat box input)

    @ViewBuilder
    private func chatComposer(_ vm: AskAIViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Escribe a Klair…", text: $input)
                    .font(.system(.body, design: .rounded))
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.sentences)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit { send(input, vm: vm) }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(KlairTheme.surfaceHigh.opacity(0.65))
                    )

                Button { send(input, vm: vm) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? KlairTheme.textTertiary : KlairTheme.amethyst)
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSending)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if !DemoMode.useMockRemoteServices {
                Text("Google Gemini · contexto: Oura, comidas, labs, ciclo, energía, alertas")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(KlairTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private func send(_ text: String, vm: AskAIViewModel) {
        let t = text.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
        SensoryManager.shared.mediumTap()
        input = ""
        isInputFocused = false
        vm.draft = t; Task { await vm.send(health: healthKit) }
    }
}
