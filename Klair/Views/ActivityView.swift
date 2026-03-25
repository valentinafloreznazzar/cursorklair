import SwiftUI
import SwiftData
import Charts

struct ActivityView: View {
    @Query(sort: \OuraActivityDay.date, order: .reverse) private var activities: [OuraActivityDay]
    @Query(sort: \OuraMetrics.date, order: .reverse) private var metrics: [OuraMetrics]
    @Query(sort: \EnergyActivity.timestamp, order: .reverse) private var energyLogs: [EnergyActivity]
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleSymptom.date, order: .reverse) private var cycleSymptoms: [CycleSymptom]
    @Environment(\.modelContext) private var modelContext

    @State private var showLogSheet = false

    private var profile: UserProfile? { profiles.first }
    private var today: OuraActivityDay? { activities.first }
    private var latest: OuraMetrics? { metrics.first }
    private var isSickDay: Bool { profile?.energyRating == 0 }

    private var todayEnergy: [EnergyActivity] {
        let cal = Calendar.current
        return energyLogs.filter { cal.isDateInToday($0.timestamp) }
    }

    private var batteryLevel: Int {
        let base = 50
        let delta = todayEnergy.map(\.energyDelta).reduce(0, +)
        return max(0, min(100, base + delta))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                if isSickDay { recoveryModeBanner }
                energyBattery
                energyFlowTimeline
                correlationInsights
                if !isSickDay {
                    recoveryRecommendation
                    metricsRow
                    todayWorkoutCard
                    vo2MaxCard
                    trainingLoadCard
                }
                recentWorkouts
                menstrualFlowSection
                symptomTrackerCard
                hormonalIntelligence
                cycleEnergyChart
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .background((isSickDay ? Color(hex: "F5E6D3") : KlairTheme.background).ignoresSafeArea())
        .sheet(isPresented: $showLogSheet) { EnergyLogSheet(modelContext: modelContext) }
    }

    private var header: some View {
        HStack {
            Text(isSickDay ? "Recovery Mode" : "Movement & Recovery")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(isSickDay ? Color(hex: "8B6914") : KlairTheme.textPrimary)
            Spacer()
            Button { showLogSheet = true } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundStyle(KlairTheme.cyan)
            }
            KlairLogo(size: 28, color: KlairTheme.orange.opacity(0.5))
        }
        .padding(.top, 12)
    }

    // MARK: - Recovery Mode Banner

    @ViewBuilder
    private var recoveryModeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bed.double.fill").font(.system(size: 22)).foregroundStyle(Color(hex: "C4841D"))
            VStack(alignment: .leading, spacing: 3) {
                Text("RECOVERY MODE ACTIVE").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(Color(hex: "8B6914"))
                Text("Step and activity goals are hidden. Focus on rest, hydration, and gentle recovery.")
                    .font(.system(.caption2, design: .rounded)).foregroundStyle(Color(hex: "A67C2E")).lineSpacing(3)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFF3DC"))
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous).stroke(Color(hex: "E8D5A0"), lineWidth: 1))
    }

    // MARK: - Energy Battery

    @ViewBuilder
    private var energyBattery: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    meta("ENERGY BATTERY")
                    Spacer()
                    Text("\(batteryLevel)%").font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(batteryColor)
                }

                HStack(spacing: 16) {
                    // Vertical battery
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(KlairTheme.surfaceHigh.opacity(0.4))
                            .frame(width: 44, height: 140)

                        // Layered segments
                        VStack(spacing: 0) {
                            ForEach(Array(todayEnergy.reversed().enumerated()), id: \.offset) { _, entry in
                                let height = max(3, CGFloat(abs(entry.energyDelta)) / 100 * 140)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(entry.isDeposit ? KlairTheme.cyan.opacity(0.6) : KlairTheme.orange.opacity(0.7))
                                    .frame(width: 36, height: height)
                            }
                        }
                        .frame(width: 44, height: min(140, CGFloat(batteryLevel) / 100 * 140), alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        // Battery fill overlay
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [batteryColor.opacity(0.15), batteryColor.opacity(0.05)],
                                    startPoint: .bottom, endPoint: .top
                                )
                            )
                            .frame(width: 44, height: CGFloat(batteryLevel) / 100 * 140)

                        // Battery cap
                        VStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(KlairTheme.surfaceHigh)
                                .frame(width: 18, height: 6)
                            Spacer()
                        }
                        .frame(height: 146)
                    }
                    .frame(width: 44, height: 146)

                    // Deposit / Withdrawal summary
                    VStack(alignment: .leading, spacing: 12) {
                        let deposits = todayEnergy.filter(\.isDeposit)
                        let withdrawals = todayEnergy.filter { !$0.isDeposit }
                        let totalDeposit = deposits.map(\.energyDelta).reduce(0, +)
                        let totalWithdraw = abs(withdrawals.map(\.energyDelta).reduce(0, +))

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 16)).foregroundStyle(KlairTheme.cyan)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("+\(totalDeposit) DEPOSITS").font(.system(size: 10, weight: .bold)).kerning(0.5).foregroundStyle(KlairTheme.cyan)
                                Text("\(deposits.count) activities").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 16)).foregroundStyle(KlairTheme.orange)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("-\(totalWithdraw) WITHDRAWALS").font(.system(size: 10, weight: .bold)).kerning(0.5).foregroundStyle(KlairTheme.orange)
                                Text("\(withdrawals.count) activities").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                            }
                        }

                        Divider()

                        Text(batteryInsight)
                            .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }
                }
            }
        }
    }

    private var batteryColor: Color {
        if batteryLevel >= 70 { return KlairTheme.emerald }
        if batteryLevel >= 40 { return KlairTheme.cyan }
        if batteryLevel >= 20 { return KlairTheme.orange }
        return KlairTheme.coral
    }

    private var batteryInsight: String {
        if batteryLevel >= 75 { return "Strong energy reserves. Good day for challenging tasks or workouts." }
        if batteryLevel >= 50 { return "Moderate energy. Balance demanding activities with short breaks." }
        if batteryLevel >= 25 { return "Energy running low. Prioritize recovery activities." }
        return "Energy depleted. Consider rest, a nature walk, or gentle stretching."
    }

    // MARK: - Energy Flow Timeline

    @ViewBuilder
    private var energyFlowTimeline: some View {
        if !todayEnergy.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                meta("TODAY'S ENERGY FLOW")
                ForEach(todayEnergy) { entry in
                    HStack(spacing: 12) {
                        // Timeline dot
                        ZStack {
                            Circle().fill(entry.effectColor.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: entry.typeIcon).font(.system(size: 14)).foregroundStyle(entry.effectColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.context).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary).lineLimit(1)
                                Spacer()
                                Text(entry.isDeposit ? "+\(entry.energyDelta)" : "\(entry.energyDelta)")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(entry.effectColor)
                            }
                            HStack(spacing: 8) {
                                Text(entry.timeString).font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                                Text(entry.intensityEnum.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .bold)).kerning(0.5)
                                    .foregroundStyle(entry.intensityEnum.color)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(entry.intensityEnum.color.opacity(0.1)).clipShape(Capsule())
                                if entry.linkedHRVChange != 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "heart.fill").font(.system(size: 7))
                                        Text("HRV \(entry.linkedHRVChange > 0 ? "+" : "")\(String(format: "%.1f", entry.linkedHRVChange))")
                                            .font(.system(size: 8, weight: .semibold))
                                    }
                                    .foregroundStyle(entry.linkedHRVChange > 0 ? KlairTheme.emerald : KlairTheme.coral)
                                }
                            }
                        }
                    }
                    .padding(12).background(KlairTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                    .cloudShadow(radius: 10, y: 4)
                    .onAppear {
                        if entry.isDeposit { SensoryManager.shared.lightTap() }
                        else { SensoryManager.shared.heavyTap() }
                    }
                    .tapScale()
                }
            }
        }
    }

    // MARK: - Correlation Insights

    @ViewBuilder
    private var correlationInsights: some View {
        let highWithdrawals = energyLogs.prefix(14).filter { !$0.isDeposit && $0.intensityEnum == .high }
        if !highWithdrawals.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile.fill").font(.system(size: 13)).foregroundStyle(KlairTheme.amethyst)
                        meta("LIFE-CONTEXT × OURA")
                    }
                    ForEach(Array(highWithdrawals.prefix(3).enumerated()), id: \.offset) { _, entry in
                        let hrvPct = abs(Int(entry.linkedHRVChange / (latest?.hrv ?? 30) * 100))
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: entry.typeIcon).font(.system(size: 12)).foregroundStyle(KlairTheme.coral)
                            Text("Marta, that \(entry.context.lowercased()) caused a \(hrvPct)% drop in your HRV — logged as a 'High-Intensity Withdrawal'. Take it easy today.")
                                .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metrics Row

    @ViewBuilder
    private var metricsRow: some View {
        HStack(spacing: 12) {
            activityMetric(icon: "figure.walk", value: "\(today?.steps ?? 0)", label: "STEPS", color: KlairTheme.cyan)
            activityMetric(icon: "flame.fill", value: "\(Int(today?.activeCalories ?? 0))", label: "KCAL", color: KlairTheme.orange)
            activityMetric(icon: "timer", value: "\(Int(today?.totalActiveMinutes ?? 0))", label: "MIN", color: KlairTheme.emerald)
        }
    }

    private func activityMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
            Text(label).font(.system(size: 8, weight: .semibold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 16, y: 6).tapScale()
    }

    // MARK: - Today Workout

    @ViewBuilder
    private var todayWorkoutCard: some View {
        if let t = today, !t.workoutType.isEmpty {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                    .fill(KlairTheme.energyGradient).frame(height: 150)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: workoutIcon(t.workoutType)).font(.system(size: 70, weight: .ultraLight)).foregroundStyle(.white.opacity(0.08)).offset(x: 10, y: -5).parallax(magnitude: 10)
                    }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TODAY'S SESSION").font(.system(size: 10, weight: .bold)).kerning(1.2).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(t.intensityLevel.uppercased()).font(.system(size: 9, weight: .bold)).kerning(0.5).padding(.horizontal, 8).padding(.vertical, 4).foregroundStyle(.white).background(.white.opacity(0.15)).clipShape(Capsule())
                    }
                    Text(t.workoutType).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    HStack(spacing: 20) {
                        workoutStat("High", "\(Int(t.highIntensityMinutes))m")
                        workoutStat("Moderate", "\(Int(t.mediumIntensityMinutes))m")
                        workoutStat("Calories", "\(Int(t.activeCalories))")
                    }
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
            .shadow(color: KlairTheme.orange.opacity(0.2), radius: 20, y: 10).tapScale()
        }
    }

    private func workoutStat(_ label: String, _ val: String) -> some View {
        VStack(spacing: 2) {
            Text(val).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 8, weight: .semibold)).kerning(0.6).foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - VO2 Max

    @ViewBuilder
    private var vo2MaxCard: some View {
        if let vo2 = today?.vo2Max, vo2 > 0 {
            GlassCard {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(KlairTheme.cyan.opacity(0.1)).frame(width: 50, height: 50)
                        Image(systemName: "lungs.fill").font(.system(size: 20)).foregroundStyle(KlairTheme.cyan)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VO2 MAX").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", vo2)).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                            Text("ml/kg/min").font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                        }
                        Text(vo2FitnessLevel(vo2)).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.cyan)
                    }
                    Spacer()
                    ScoreRing(score: min(100, Int(vo2 * 2)), label: "", color: KlairTheme.cyan, size: 48)
                }
            }
        }
    }

    private func vo2FitnessLevel(_ vo2: Double) -> String {
        if vo2 >= 45 { return "Excellent cardio fitness" }
        if vo2 >= 38 { return "Good cardio fitness" }
        if vo2 >= 30 { return "Average cardio fitness" }
        return "Below average — consider more aerobic work"
    }

    // MARK: - Training Load

    @ViewBuilder
    private var trainingLoadCard: some View {
        if let t = today, t.trainingLoadChronic > 0 {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    meta("TRAINING LOAD")
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Acute").font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
                            Text("\(Int(t.trainingLoadAcute))").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chronic").font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
                            Text("\(Int(t.trainingLoadChronic))").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.cyan)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ratio").font(.system(size: 9, weight: .semibold)).foregroundStyle(KlairTheme.textTertiary)
                            Text(String(format: "%.2f", t.trainingLoadRatio)).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        }
                        Spacer()
                        let statusColor: Color = t.trainingLoadStatus == "Overreaching" ? KlairTheme.coral : t.trainingLoadStatus == "Productive" ? KlairTheme.emerald : KlairTheme.orange
                        Text(t.trainingLoadStatus.uppercased()).font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(statusColor)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(statusColor.opacity(0.1)).clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Recovery Recommendation Engine

    @ViewBuilder
    private var recoveryRecommendation: some View {
        if let t = today, let m = latest {
            let ratio = t.trainingLoadRatio
            let hrv = m.hrv
            let avgHRV = metrics.prefix(7).isEmpty ? hrv : metrics.prefix(7).map(\.hrv).reduce(0, +) / Double(metrics.prefix(7).count)
            let hrvTrend = hrv - avgHRV
            let readiness = m.readinessScore
            let phase = profile?.cyclePhase ?? .follicular

            let (icon, title, advice, color) = recoveryAdvice(ratio: ratio, hrvTrend: hrvTrend, readiness: readiness, phase: phase)

            GlassCard {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                        Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RECOVERY ENGINE").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                            Spacer()
                            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).kerning(0.5)
                                .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(color.opacity(0.1)).clipShape(Capsule())
                        }
                        Text(advice).font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                        HStack(spacing: 12) {
                            miniStat("HRV", String(format: "%.0f", hrv), hrvTrend >= 0 ? KlairTheme.emerald : KlairTheme.orange)
                            miniStat("A:C", String(format: "%.2f", ratio), ratio > 1.3 ? KlairTheme.coral : KlairTheme.emerald)
                            miniStat("Ready", "\(readiness)", readiness >= 70 ? KlairTheme.emerald : KlairTheme.orange)
                        }
                    }
                }
            }
        }
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(color)
            Text(label).font(.system(size: 7, weight: .semibold)).kerning(0.5).foregroundStyle(KlairTheme.textTertiary)
        }
    }

    private func recoveryAdvice(ratio: Double, hrvTrend: Double, readiness: Int, phase: CyclePhase) -> (String, String, String, Color) {
        if readiness < 60 || (hrvTrend < -5 && ratio > 1.2) {
            return ("bed.double.fill", "Rest Day",
                    "Your HRV is trending down (\(String(format: "%+.0f", hrvTrend)) from 7-day avg) and readiness is low. Skip intense training — gentle yoga, walking, or stretching only.",
                    KlairTheme.coral)
        }
        if ratio > 1.4 {
            return ("exclamationmark.triangle.fill", "Overreaching",
                    "Acute load exceeds chronic by \(Int((ratio - 1) * 100))%. High injury risk. Limit to Zone 2 cardio or active recovery today.",
                    KlairTheme.orange)
        }
        if phase == .menstrual || phase == .luteal {
            let phaseNote = phase == .menstrual
                ? "Menstrual phase — iron loss and lower energy are expected. Focus on iron-rich meals and moderate exercise."
                : "Luteal phase — progesterone raises temp and may lower HRV. Moderate intensity recommended."
            return ("leaf.fill", "Phase-Adapted",
                    phaseNote + " Your readiness of \(readiness) supports moderate activity.",
                    KlairTheme.orange)
        }
        if readiness >= 80 && hrvTrend >= 0 {
            return ("bolt.fill", "Peak Performance",
                    "Excellent readiness (\(readiness)) with positive HRV trend (+\(String(format: "%.0f", hrvTrend))). Great day for HIIT, heavy lifts, or competitive efforts.",
                    KlairTheme.emerald)
        }
        return ("figure.run", "Train Smart",
                "Moderate readiness supports steady-state training. Zone 2 cardio or strength at RPE 6–7 recommended. Monitor how you feel mid-session.",
                KlairTheme.cyan)
    }

    // MARK: - Cycle Symptom Tracker

    @ViewBuilder
    private var symptomTrackerCard: some View {
        let todaySymptom = cycleSymptoms.first
        if let sym = todaySymptom {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.clipboard").font(.system(size: 12)).foregroundStyle(KlairTheme.coral)
                        meta("CYCLE SYMPTOMS · DAY \(sym.cycleDay)")
                        Spacer()
                        Text(sym.pmsSeverityLabel.uppercased()).font(.system(size: 9, weight: .bold)).kerning(0.5)
                            .foregroundStyle(sym.pmsSeverityColor).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(sym.pmsSeverityColor.opacity(0.1)).clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        ScoreRing(score: min(100, sym.pmsSeverityScore * 4), label: "", color: sym.pmsSeverityColor, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PMS Score: \(sym.pmsSeverityScore)/32").font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                            if sym.topSymptoms.isEmpty {
                                Text("No significant symptoms today").font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.emerald)
                            } else {
                                HStack(spacing: 6) {
                                    ForEach(sym.topSymptoms, id: \.name) { s in
                                        HStack(spacing: 3) {
                                            Image(systemName: CycleSymptom.symptomIcons[s.name] ?? "circle.fill").font(.system(size: 8)).foregroundStyle(sym.pmsSeverityColor)
                                            Text(s.name).font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textSecondary)
                                        }
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(sym.pmsSeverityColor.opacity(0.06)).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    if sym.phase == "Luteal" && sym.pmsSeverityScore > 10 {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 10)).foregroundStyle(KlairTheme.orange)
                            Text("Elevated PMS symptoms. Consider magnesium (400mg), reduce sodium, and prioritize sleep. Track patterns over 3 cycles to assess treatment efficacy.")
                                .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Workouts

    @ViewBuilder
    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            meta("RECENT WORKOUTS")
            ForEach(Array(activities.prefix(5).enumerated()), id: \.offset) { _, act in
                HStack(spacing: 12) {
                    Circle().fill(KlairTheme.orange.opacity(0.1)).frame(width: 36, height: 36)
                        .overlay(Image(systemName: workoutIcon(act.workoutType)).font(.system(size: 14)).foregroundStyle(KlairTheme.orange))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(act.workoutType.isEmpty ? "Rest Day" : act.workoutType).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("\(act.steps) steps · \(Int(act.activeCalories)) kcal").font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                    }
                    Spacer()
                    Text(dayLabel(act.date)).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textTertiary)
                }
                .padding(12).background(KlairTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                .cloudShadow(radius: 10, y: 4).tapScale()
            }
        }
    }

    private func workoutIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "hiit": return "bolt.fill"; case "strength": return "dumbbell.fill"; case "running": return "figure.run"
        case "yoga": return "figure.yoga"; case "walking": return "figure.walk"; case "cycling": return "bicycle"
        default: return "leaf.fill"
        }
    }
    private func dayLabel(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date) }

    // MARK: - Menstrual Flow

    @ViewBuilder
    private var menstrualFlowSection: some View {
        if let flow = profile?.lastMenstrualFlow, !flow.isEmpty {
            GlassCard {
                HStack(spacing: 12) {
                    Circle().fill(KlairTheme.coral.opacity(0.1)).frame(width: 36, height: 36)
                        .overlay(Image(systemName: "drop.fill").font(.system(size: 16)).foregroundStyle(KlairTheme.coral))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MENSTRUAL FLOW").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        Text("Last recorded: \(flow)")
                            .font(.system(.subheadline, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
                        Text("Day \(profile?.cycleDay ?? 0) of \(profile?.cycleLength ?? 28)")
                            .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Hormonal Intelligence

    @ViewBuilder
    private var hormonalIntelligence: some View {
        let phase = profile?.cyclePhase ?? .follicular
        let day = profile?.cycleDay ?? 1
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    meta("HORMONAL INTELLIGENCE"); Spacer()
                    statusPill(phase.rawValue.uppercased(), phase.phaseColor)
                }
                HStack(spacing: 4) {
                    ForEach(0..<28, id: \.self) { d in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(d + 1 == day ? KlairTheme.textPrimary : CyclePhase.from(day: d + 1, cycleLength: 28).phaseColor.opacity(0.3))
                            .frame(height: d + 1 == day ? 20 : 8)
                    }
                }.frame(height: 20)
                HStack(spacing: 14) {
                    phaseLabel("Menstrual", KlairTheme.coral); phaseLabel("Follicular", KlairTheme.emerald)
                    phaseLabel("Ovulatory", KlairTheme.cyan); phaseLabel("Luteal", KlairTheme.orange)
                }
                Divider().foregroundStyle(KlairTheme.surfaceHigh)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        infoChip(icon: "bolt.fill", value: phase.energyLevel, label: "ENERGY", color: KlairTheme.orange)
                        infoChip(icon: "thermometer.medium", value: "\(latest?.temperatureDeviation ?? 0 >= 0 ? "+" : "")\(String(format: "%.1f", latest?.temperatureDeviation ?? 0))°", label: "TEMP", color: KlairTheme.coral)
                        infoChip(icon: "heart.fill", value: "\(Int(latest?.restingHeartRate ?? 0))", label: "RHR", color: KlairTheme.amethyst)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NUTRITION NEEDS").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        Text(nutritionForPhase(phase)).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }.padding(12).background(KlairTheme.emerald.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRAINING CAPACITY").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        Text(phase.recommendedWorkout).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
                        Text(phase.readinessImpact).font(.system(size: 10, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }.padding(12).background(KlairTheme.orange.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func nutritionForPhase(_ phase: CyclePhase) -> String {
        switch phase {
        case .menstrual: return "Prioritize iron-rich foods (lentils, spinach, red meat). Add Vitamin C to boost absorption. Magnesium helps with cramps."
        case .follicular: return "Rising estrogen supports muscle growth. Increase lean protein and complex carbs. Great time for calorie surplus."
        case .ovulation: return "Peak metabolism — eat nutrient-dense but moderate calories. Zinc and B vitamins support hormonal peak."
        case .luteal: return "Progesterone increases cravings. Focus on magnesium-rich foods, healthy fats, and fiber to stabilize blood sugar."
        }
    }

    private func infoChip(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 8, weight: .semibold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                Text(value).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
            }
        }
    }
    private func phaseLabel(_ l: String, _ c: Color) -> some View {
        HStack(spacing: 3) { Circle().fill(c).frame(width: 5, height: 5); Text(l).font(.system(size: 8, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) }
    }

    // MARK: - Energy Chart

    @ViewBuilder
    private var cycleEnergyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                meta("READINESS × ACTIVITY")
                Chart {
                    ForEach(Array(zip(metrics.prefix(7), activities.prefix(7))).reversed(), id: \.0.date) { m, a in
                        let fmt = DateFormatter(); let _ = fmt.dateFormat = "EEE"
                        AreaMark(x: .value("Day", fmt.string(from: m.date)), y: .value("Readiness", Double(m.readinessScore)))
                            .foregroundStyle(LinearGradient(colors: [KlairTheme.cyan.opacity(0.15), KlairTheme.cyan.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", fmt.string(from: m.date)), y: .value("Readiness", Double(m.readinessScore)))
                            .foregroundStyle(KlairTheme.cyan).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                            .symbol { Circle().fill(KlairTheme.cyan).frame(width: 5) }
                        BarMark(x: .value("Day", fmt.string(from: m.date)), y: .value("Steps", Double(a.steps) / 200))
                            .foregroundStyle(KlairTheme.orange.opacity(0.2)).cornerRadius(3)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(KlairTheme.textTertiary) } }
                .chartYAxis(.hidden).frame(height: 140)
            }
        }
    }

    private func meta(_ t: String) -> some View { Text(t).font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary) }
    private func statusPill(_ t: String, _ c: Color) -> some View { Text(t).font(.system(size: 9, weight: .bold)).kerning(0.5).padding(.horizontal, 8).padding(.vertical, 4).foregroundStyle(c).background(c.opacity(0.1)).clipShape(Capsule()) }
}

// MARK: - Energy Log Sheet

struct EnergyLogSheet: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ActivityType = .workout
    @State private var selectedIntensity: IntensityLevel = .medium
    @State private var selectedEffect: EnergyEffect = .deposit
    @State private var context: String = ""
    @State private var energyDelta: Double = 15

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVITY TYPE").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(ActivityType.allCases, id: \.rawValue) { type in
                                Button { selectedType = type } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon).font(.system(size: 18))
                                        Text(type.label).font(.system(size: 9, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(selectedType == type ? .white : KlairTheme.textSecondary)
                                    .background(selectedType == type ? KlairTheme.cyan : KlairTheme.surfaceHigh.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ENERGY EFFECT").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        HStack(spacing: 12) {
                            ForEach(EnergyEffect.allCases, id: \.rawValue) { effect in
                                Button { selectedEffect = effect } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: effect.icon).font(.system(size: 14))
                                        Text(effect.rawValue.capitalized).font(.system(.caption, design: .rounded).weight(.bold))
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(selectedEffect == effect ? .white : KlairTheme.textSecondary)
                                    .background(selectedEffect == effect ? (effect == .deposit ? KlairTheme.cyan : KlairTheme.orange) : KlairTheme.surfaceHigh.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("INTENSITY").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        HStack(spacing: 12) {
                            ForEach(IntensityLevel.allCases, id: \.rawValue) { level in
                                Button { selectedIntensity = level } label: {
                                    Text(level.rawValue.capitalized)
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .foregroundStyle(selectedIntensity == level ? .white : KlairTheme.textSecondary)
                                        .background(selectedIntensity == level ? level.color : KlairTheme.surfaceHigh.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONTEXT").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        TextField("e.g., Pilates Class, Rock Concert", text: $context)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(12).background(KlairTheme.surfaceHigh.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("ENERGY IMPACT").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                            Spacer()
                            Text("\(selectedEffect == .deposit ? "+" : "-")\(Int(energyDelta))")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(selectedEffect == .deposit ? KlairTheme.cyan : KlairTheme.orange)
                        }
                        Slider(value: $energyDelta, in: 5...50, step: 5)
                            .tint(selectedEffect == .deposit ? KlairTheme.cyan : KlairTheme.orange)
                    }
                }
                .padding(20)
            }
            .background(KlairTheme.background)
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .fontWeight(.bold)
                        .disabled(context.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func saveEntry() {
        let delta = selectedEffect == .deposit ? Int(energyDelta) : -Int(energyDelta)
        let entry = EnergyActivity(
            timestamp: Date(),
            activityType: selectedType.rawValue,
            intensity: selectedIntensity.rawValue,
            energyEffect: selectedEffect.rawValue,
            context: context.trimmingCharacters(in: .whitespaces),
            energyDelta: delta,
            linkedHRVChange: 0
        )
        modelContext.insert(entry)
        try? modelContext.save()

        if selectedEffect == .deposit {
            SensoryManager.shared.success()
        } else {
            SensoryManager.shared.alertPulse()
        }
        dismiss()
    }
}
