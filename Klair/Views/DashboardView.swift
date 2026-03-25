import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var profiles: [UserProfile]
    @State private var viewModel: DashboardViewModel?
    @State private var trendRange: TrendRange = .weekly

    private var profile: UserProfile? { profiles.first }

    enum TrendRange: String, CaseIterable { case weekly = "7D", monthly = "30D" }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let vm = viewModel {
                    headerSection(vm)
                    quickEnergySelector
                    quoteCard(vm)
                    energyHero(vm)
                    stressCard(vm)
                    scoreRingsCard(vm)
                    readinessContributorsCard(vm)
                    hydrationWidget(vm)
                    bioNarrativeCard(vm)
                    metricsStrip(vm)
                    trendChart(vm)
                    correlationWidget(vm)
                    weeklySummaryCard(vm)
                    alertEngineSection(vm)
                    actionableAlerts(vm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .background(KlairTheme.background.ignoresSafeArea())
        .onAppear {
            if viewModel == nil {
                let vm = DashboardViewModel(modelContext: modelContext)
                viewModel = vm; vm.load(health: healthKit)
            } else { viewModel?.load(health: healthKit) }
        }
        .refreshable { viewModel?.refreshFromStore(); await viewModel?.syncOuraFromCloud() }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ vm: DashboardViewModel) -> some View {
        HStack(alignment: .center) {
            Text(greetingText)
                .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
            Spacer()
            Button { Task { await viewModel?.syncOuraFromCloud() } } label: {
                Group {
                    if vm.isSyncingOura { ProgressView().tint(KlairTheme.cyan) }
                    else { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 13, weight: .semibold)) }
                }
                .frame(width: 36, height: 36).background(KlairTheme.card).clipShape(Circle()).cloudShadow(radius: 10, y: 4)
            }
            .tint(KlairTheme.cyan)
        }
        .padding(.top, 12)
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        return "\(h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"), Marta"
    }

    // MARK: - Quick Energy Selector

    @ViewBuilder
    private var quickEnergySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW IS YOUR ENERGY?").font(.system(size: 10, weight: .bold)).kerning(1.2).foregroundStyle(KlairTheme.textTertiary)
            HStack(spacing: 12) {
                energyButton(icon: "battery.25percent", label: "Low", value: 1, color: KlairTheme.coral)
                energyButton(icon: "battery.50percent", label: "Steady", value: 3, color: KlairTheme.cyan)
                energyButton(icon: "battery.100percent", label: "Peak", value: 5, color: KlairTheme.emerald)
                Divider().frame(height: 40)
                sickDayButton
            }
        }
    }

    private func energyButton(icon: String, label: String, value: Int, color: Color) -> some View {
        let isSelected = profile?.energyRating == value
        return Button {
            SensoryManager.shared.selection()
            profile?.energyRating = value
            try? modelContext.save()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(isSelected ? .white : color)
                Text(label).font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(isSelected ? .white : KlairTheme.textTertiary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(isSelected ? color : color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sickDayButton: some View {
        let isSick = profile?.energyRating == 0
        return Button {
            SensoryManager.shared.alertPulse()
            profile?.energyRating = isSick ? 3 : 0
            try? modelContext.save()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isSick ? "checkmark.circle.fill" : "cross.circle").font(.system(size: 20)).foregroundStyle(isSick ? .white : Color(hex: "C4841D"))
                Text(isSick ? "Active" : "Sick Day").font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(isSick ? .white : Color(hex: "C4841D"))
            }
            .frame(width: 60).padding(.vertical, 12)
            .background(isSick ? Color(hex: "C4841D") : Color(hex: "FFF3DC"))
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inspirational Quote

    @ViewBuilder
    private func quoteCard(_ vm: DashboardViewModel) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(KlairTheme.amethyst.opacity(0.4)).frame(width: 3)
            Text("\u{201C}\(vm.inspirationalQuote)\u{201D}")
                .font(.system(.subheadline, design: .serif).italic()).foregroundStyle(KlairTheme.textSecondary).lineSpacing(5)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Energy Hero

    @ViewBuilder
    private func energyHero(_ vm: DashboardViewModel) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                .fill(KlairTheme.heroGradient).frame(height: 190)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 90, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.06))
                        .offset(x: 15, y: -8)
                        .parallax(magnitude: 12)
                }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 10))
                    Text("DAILY ENERGY").font(.system(size: 10, weight: .bold)).kerning(1.2)
                }.foregroundStyle(.white.opacity(0.6))
                Text("\(vm.todayReadiness)").font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(vm.dailyInsight).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(.white.opacity(0.8)).lineSpacing(3).lineLimit(2)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .shadow(color: KlairTheme.amethyst.opacity(0.25), radius: 24, y: 12)
        .tapScale()
    }

    // MARK: - Stress Continuum

    @ViewBuilder
    private func stressCard(_ vm: DashboardViewModel) -> some View {
        let level = vm.stressInsight.level
        let color: Color = level == "Elevated" ? KlairTheme.coral : level == "Moderate" ? KlairTheme.orange : KlairTheme.emerald
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg").font(.system(size: 13)).foregroundStyle(color)
                        meta("STRESS · HRV-BASED")
                    }
                    Spacer()
                    Text(level.uppercased()).font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.1)).clipShape(Capsule())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(KlairTheme.surfaceHigh.opacity(0.4))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [KlairTheme.emerald, KlairTheme.orange, KlairTheme.coral], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, vm.stressScore / 100))
                    }
                }
                .frame(height: 8)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score").font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
                        Text("\(Int(vm.stressScore))").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration").font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
                        Text("\(Int(vm.stressDurationMinutes))m").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                    }
                    Spacer()
                }

                Text(vm.stressInsight.description)
                    .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
            }
        }
    }

    // MARK: - Score Rings

    @ViewBuilder
    private func scoreRingsCard(_ vm: DashboardViewModel) -> some View {
        GlassCard {
            HStack(spacing: 0) {
                Spacer()
                ScoreRing(score: vm.todayReadiness, label: "Ready", color: KlairTheme.scoreColor(vm.todayReadiness))
                Spacer()
                ScoreRing(score: vm.todaySleep, label: "Sleep", color: KlairTheme.scoreColor(vm.todaySleep))
                Spacer()
                ScoreRing(score: Int(vm.todayHRV), maxScore: 80, label: "HRV", color: KlairTheme.cyan)
                Spacer()
            }
        }
    }

    // MARK: - Readiness Contributors

    @ViewBuilder
    private func readinessContributorsCard(_ vm: DashboardViewModel) -> some View {
        if !vm.readinessContributors.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    meta("READINESS CONTRIBUTORS")
                    ForEach(vm.readinessContributors, id: \.key) { key, value in
                        let label = key.replacingOccurrences(of: "_", with: " ").capitalized
                        let color = contributorColor(value)
                        HStack(spacing: 10) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
                            Spacer()
                            Text(value.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(color)
                        }
                    }
                }
            }
        }
    }

    private func contributorColor(_ value: String) -> Color {
        switch value {
        case "optimal": return KlairTheme.emerald
        case "good", "restored": return KlairTheme.cyan
        case "fair", "normal": return KlairTheme.orange
        default: return KlairTheme.coral
        }
    }

    // MARK: - Hydration Widget

    @ViewBuilder
    private func hydrationWidget(_ vm: DashboardViewModel) -> some View {
        if vm.waterGoalMl > 0 {
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(KlairTheme.cyan.opacity(0.15), lineWidth: 4).frame(width: 50, height: 50)
                        Circle().trim(from: 0, to: vm.waterProgress)
                            .stroke(KlairTheme.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 50, height: 50)
                        Image(systemName: "drop.fill").font(.system(size: 14)).foregroundStyle(KlairTheme.cyan)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HYDRATION").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        Text("\(Int(vm.waterIntakeMl)) / \(Int(vm.waterGoalMl)) ml")
                            .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        if vm.waterProgress < 0.5 {
                            Text("Below target — may reduce HRV ~5%")
                                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.coral)
                        }
                    }
                    Spacer()
                    Text("\(Int(vm.waterProgress * 100))%")
                        .font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.cyan)
                }
            }
        }
    }

    // MARK: - Bio-Narrative

    @ViewBuilder
    private func bioNarrativeCard(_ vm: DashboardViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 14)).foregroundStyle(KlairTheme.amethyst)
                    meta("BIO-NARRATIVE")
                }
                Text(vm.dailyNarrative).font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(4)
            }
        }
    }

    // MARK: - Metrics Strip

    @ViewBuilder
    private func metricsStrip(_ vm: DashboardViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                metricPill(icon: "figure.walk", value: "\(vm.todaySteps)", label: "STEPS", color: KlairTheme.cyan)
                metricPill(icon: "flame.fill", value: "\(Int(vm.todayActiveCalories))", label: "MOVE", color: KlairTheme.orange)
                metricPill(icon: "heart.fill", value: "\(Int(vm.restingHeartRate))", label: "RHR", color: KlairTheme.coral)
                metricPill(icon: "lungs.fill", value: String(format: "%.1f", vm.respiratoryRate), label: "RESP", color: KlairTheme.cyan)
                metricPill(icon: "o2.circle.fill", value: String(format: "%.0f%%", vm.spo2), label: "SpO2", color: KlairTheme.emerald)
                metricPill(icon: "thermometer.medium", value: "\(vm.temperatureDeviation >= 0 ? "+" : "")\(String(format: "%.1f", vm.temperatureDeviation))°", label: "TEMP", color: KlairTheme.amethyst)
            }
            .padding(.horizontal, 2)
        }
    }

    private func metricPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            Text(value).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
            Text(label).font(.system(size: 8, weight: .semibold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
        }
        .frame(width: 72).padding(.vertical, 14)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4)
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private func trendChart(_ vm: DashboardViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    meta("TRENDS")
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(TrendRange.allCases, id: \.rawValue) { range in
                            Button { withAnimation(.spring(response: 0.3)) { trendRange = range } } label: {
                                Text(range.rawValue).font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(trendRange == range ? .white : KlairTheme.textTertiary)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(trendRange == range ? KlairTheme.cyan : .clear).clipShape(Capsule())
                            }
                        }
                    }
                    .background(KlairTheme.surfaceHigh.opacity(0.5)).clipShape(Capsule())
                }
                Chart {
                    ForEach(vm.chartPoints) { p in
                        AreaMark(x: .value("Day", p.label), y: .value("HRV", p.hrvValue))
                            .foregroundStyle(LinearGradient(colors: [KlairTheme.cyan.opacity(0.2), KlairTheme.cyan.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", p.label), y: .value("HRV", p.hrvValue))
                            .foregroundStyle(KlairTheme.cyan).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                            .symbol { Circle().fill(KlairTheme.cyan).frame(width: 6) }
                        BarMark(x: .value("Day", p.label), y: .value("Sugar", min(50, p.sugarIntake / 3)))
                            .foregroundStyle(KlairTheme.orange.opacity(0.2)).cornerRadius(4)
                        if p.lateNightCalories > 0 {
                            PointMark(x: .value("Day", p.label), y: .value("Late", 2))
                                .foregroundStyle(KlairTheme.coral)
                                .symbolSize(20)
                        }
                    }
                }
                .chartYScale(domain: 0...55)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) } }
                .chartYAxis(.hidden)
                .frame(height: 140)

                HStack(spacing: 16) {
                    legendDot(KlairTheme.cyan, "HRV"); legendDot(KlairTheme.orange, "Glycemic"); legendDot(KlairTheme.coral, "Late meal")
                }
            }
        }
    }

    private func legendDot(_ c: Color, _ l: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 5, height: 5); Text(l).font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) }
    }

    // MARK: - Weekly Summary

    @ViewBuilder
    private func weeklySummaryCard(_ vm: DashboardViewModel) -> some View {
        if let ws = vm.weekSummary {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    meta("WEEKLY SUMMARY")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        summaryMetric(label: "Avg Readiness", value: "\(ws.avgReadiness)", color: KlairTheme.scoreColor(ws.avgReadiness))
                        summaryMetric(label: "Avg Sleep", value: "\(ws.avgSleep)", color: KlairTheme.scoreColor(ws.avgSleep))
                        summaryMetric(label: "Avg HRV", value: String(format: "%.0f", ws.avgHRV), color: KlairTheme.cyan)
                        summaryMetric(label: "Avg RHR", value: String(format: "%.0f", ws.avgRHR), color: KlairTheme.coral)
                        summaryMetric(label: "Resp Rate", value: String(format: "%.1f", ws.avgRespiratoryRate), color: KlairTheme.cyan)
                        summaryMetric(label: "SpO2", value: String(format: "%.0f%%", ws.avgSpO2), color: KlairTheme.emerald)
                    }
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 12)).foregroundStyle(KlairTheme.emerald)
                            Text("Best: \(ws.bestDay)").font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textSecondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 12)).foregroundStyle(KlairTheme.coral)
                            Text("Worst: \(ws.worstDay)").font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textSecondary)
                        }
                        Spacer()
                        Text("\(ws.totalSteps) steps").font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textTertiary)
                    }
                }
            }
        }
    }

    private func summaryMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pearson Correlation Widget

    @ViewBuilder
    private func correlationWidget(_ vm: DashboardViewModel) -> some View {
        if !vm.correlations.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.dots.scatter").font(.system(size: 13)).foregroundStyle(KlairTheme.amethyst)
                        meta("CORRELATIONS (PEARSON r)")
                    }
                    ForEach(vm.correlations.prefix(4)) { c in
                        HStack(spacing: 10) {
                            Image(systemName: c.icon).font(.system(size: 14)).foregroundStyle(correlationColor(c.rValue))
                                .frame(width: 28, height: 28).background(correlationColor(c.rValue).opacity(0.1)).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(c.label).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                                    Text("r = \(String(format: "%+.2f", c.rValue))").font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(correlationColor(c.rValue))
                                        .padding(.horizontal, 6).padding(.vertical, 2).background(correlationColor(c.rValue).opacity(0.1)).clipShape(Capsule())
                                }
                                Text(c.description).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary).lineSpacing(2)
                            }
                            Spacer()
                            rBar(c.rValue)
                        }
                    }
                    Text("Based on \(vm.correlations.first?.n ?? 0) data points").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                }
            }
        }
    }

    private func rBar(_ r: Double) -> some View {
        let w: CGFloat = 40
        return ZStack(alignment: r >= 0 ? .leading : .trailing) {
            RoundedRectangle(cornerRadius: 2).fill(KlairTheme.surfaceHigh.opacity(0.3)).frame(width: w, height: 6)
            RoundedRectangle(cornerRadius: 2).fill(correlationColor(r)).frame(width: w * min(1, abs(r)), height: 6)
        }
    }

    private func correlationColor(_ r: Double) -> Color {
        let ar = abs(r)
        if ar >= 0.5 { return r > 0 ? KlairTheme.emerald : KlairTheme.coral }
        if ar >= 0.25 { return KlairTheme.orange }
        return KlairTheme.textTertiary
    }

    // MARK: - Alert Engine (11-Rule System)

    @ViewBuilder
    private func alertEngineSection(_ vm: DashboardViewModel) -> some View {
        if !vm.healthAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered").font(.system(size: 13)).foregroundStyle(KlairTheme.coral)
                    meta("HEALTH INTELLIGENCE")
                }
                .onAppear { if vm.healthAlerts.contains(where: { $0.severity == .critical }) { SensoryManager.shared.alertPulse() } }
                ForEach(vm.healthAlerts.prefix(5)) { alert in
                    let color = alertSeverityColor(alert.severity)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Circle().fill(color.opacity(0.12)).frame(width: 30, height: 30)
                                .overlay(Image(systemName: alert.icon).font(.system(size: 13)).foregroundStyle(color))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                                Text(severityLabel(alert.severity)).font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(color)
                            }
                            Spacer()
                        }
                        Text(alert.message).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                        if let hint = alert.actionHint {
                            HStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill").font(.system(size: 9)).foregroundStyle(KlairTheme.cyan)
                                Text(hint).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.cyan)
                            }
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(KlairTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous).stroke(color.opacity(0.15), lineWidth: 1))
                    .cloudShadow(radius: 12, y: 4).tapScale()
                }
            }
        }
    }

    private func alertSeverityColor(_ s: HealthAlert.Severity) -> Color {
        switch s { case .critical: return KlairTheme.coral; case .warning: return KlairTheme.orange; case .info: return KlairTheme.cyan }
    }

    private func severityLabel(_ s: HealthAlert.Severity) -> String {
        switch s { case .critical: return "CRITICAL"; case .warning: return "WARNING"; case .info: return "INFO" }
    }

    // MARK: - Contextual Insights

    @ViewBuilder
    private func actionableAlerts(_ vm: DashboardViewModel) -> some View {
        if !vm.proactiveInsights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                meta("CONTEXTUAL INSIGHTS")
                ForEach(Array(vm.proactiveInsights.prefix(3).enumerated()), id: \.offset) { idx, txt in
                    let colors: [Color] = [KlairTheme.coral, KlairTheme.orange, KlairTheme.amethyst]
                    let icons = ["exclamationmark.triangle.fill", "flame.fill", "brain.head.profile.fill"]
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(colors[idx % colors.count].opacity(0.12)).frame(width: 30, height: 30)
                            .overlay(Image(systemName: icons[idx % icons.count]).font(.system(size: 13)).foregroundStyle(colors[idx % colors.count]))
                        Text(txt).font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(KlairTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous).stroke(colors[idx % colors.count].opacity(0.1), lineWidth: 1))
                    .cloudShadow(radius: 12, y: 4).tapScale()
                }
            }
        }
    }

    private func meta(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary)
    }
}
