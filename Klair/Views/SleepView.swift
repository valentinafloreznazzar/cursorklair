import SwiftUI
import SwiftData
import Charts

struct SleepStagePoint: Identifiable {
    var id: String { "\(day)-\(stage)" }
    let day: String; let stage: String; let hours: Double
}

struct SleepView: View {
    @Query(sort: \OuraMetrics.date, order: .reverse) private var metrics: [OuraMetrics]
    @Query(sort: \MealEntry.timestamp, order: .reverse) private var meals: [MealEntry]
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var latest: OuraMetrics? { metrics.first }
    private var stageData: [SleepStagePoint] {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return Array(metrics.prefix(7)).reversed().flatMap { m in [
            SleepStagePoint(day: fmt.string(from: m.date), stage: "Deep", hours: m.deepSleepMinutes / 60),
            SleepStagePoint(day: fmt.string(from: m.date), stage: "REM", hours: m.remSleepMinutes / 60),
            SleepStagePoint(day: fmt.string(from: m.date), stage: "Light", hours: m.lightSleepMinutes / 60),
        ]}
    }

    private var sleepConsistencyScore: Int {
        let week = Array(metrics.prefix(7))
        guard week.count >= 3 else { return 0 }
        let midpoints = week.map(\.sleepMidpointDeviation)
        let variance = midpoints.map { $0 * $0 }.reduce(0, +) / Double(midpoints.count)
        return max(0, min(100, Int(100 - variance * 200)))
    }

    var body: some View {
        ZStack {
            KlairTheme.background.ignoresSafeArea()

            SleepParticleCanvas(particleCount: 25)
                .opacity(0.35)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    sleepHeroCard
                    vitalsRow
                    stagesChart
                    todayBreakdown
                    sleepConsistency
                    sleepDebtCard
                    circadianAlignmentCard
                    sleepCorrelation
                    wisdomSection
                    meditationsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
        .onAppear { SensoryManager.shared.startPinkNoise() }
        .onDisappear { SensoryManager.shared.stopPinkNoise() }
    }

    private var header: some View {
        HStack {
            Text("Restorative Rest")
                .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
            Spacer()
            KlairLogo(size: 28, color: KlairTheme.indigo.opacity(0.5))
        }
        .padding(.top, 12)
    }

    // MARK: - Sleep Hero Card

    @ViewBuilder
    private var sleepHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                .fill(KlairTheme.sleepGradient)
                .frame(height: 180)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "moon.stars.fill").font(.system(size: 80, weight: .ultraLight)).foregroundStyle(.white.opacity(0.06)).offset(x: 15, y: -5).parallax(magnitude: 10)
                }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SLEEP SCORE").font(.system(size: 10, weight: .bold)).kerning(1.2).foregroundStyle(.white.opacity(0.6))
                    Text("\(latest?.sleepScore ?? 0)")
                        .font(.system(size: 52, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(String(format: "%.1fh total · %d%% efficiency · %.0fm latency", (latest?.totalSleepMinutes ?? 0) / 60, Int(latest?.sleepEfficiency ?? 0), latest?.sleepLatencyMinutes ?? 0))
                        .font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                ScoreRing(score: latest?.sleepScore ?? 0, label: "", color: .white.opacity(0.8), size: 64).padding(.bottom, 8)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .shadow(color: KlairTheme.indigo.opacity(0.2), radius: 24, y: 12)
        .tapScale()
    }

    // MARK: - Vitals (Real data: latency, respiratory rate, SpO2, REM%, Deep%)

    @ViewBuilder
    private var vitalsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                vitalCard(icon: "clock.fill", value: String(format: "%.0f", latest?.sleepLatencyMinutes ?? 0), unit: "min", note: "Latency", color: KlairTheme.orange)
                vitalCard(icon: "lungs.fill", value: String(format: "%.1f", latest?.respiratoryRate ?? 0), unit: "/min", note: "Resp Rate", color: KlairTheme.cyan)
                vitalCard(icon: "o2.circle.fill", value: String(format: "%.0f", latest?.spo2Percentage ?? 0), unit: "%", note: "SpO2", color: KlairTheme.emerald)
                vitalCard(icon: "brain.fill", value: String(format: "%.0f", latest?.remPercentage ?? 0), unit: "%", note: "REM", color: KlairTheme.amethyst)
                vitalCard(icon: "moon.fill", value: String(format: "%.0f", latest?.deepPercentage ?? 0), unit: "%", note: "Deep", color: KlairTheme.indigo)
            }
            .padding(.horizontal, 2)
        }
    }

    private func vitalCard(icon: String, value: String, unit: String, note: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                Text(unit).font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
            }
            Text(note).font(.system(size: 8, weight: .semibold)).kerning(0.5).foregroundStyle(KlairTheme.textTertiary)
        }
        .frame(width: 72).padding(.vertical, 12)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4)
    }

    // MARK: - Stages Chart

    @ViewBuilder
    private var stagesChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                meta("SLEEP STAGES · 7 DAYS")
                Chart(stageData) { pt in
                    BarMark(x: .value("Day", pt.day), y: .value("Hours", pt.hours))
                        .foregroundStyle(by: .value("Stage", pt.stage))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    "Deep": LinearGradient(colors: [KlairTheme.indigo, KlairTheme.indigo.opacity(0.7)], startPoint: .bottom, endPoint: .top),
                    "REM": LinearGradient(colors: [KlairTheme.amethyst, KlairTheme.amethyst.opacity(0.6)], startPoint: .bottom, endPoint: .top),
                    "Light": LinearGradient(colors: [KlairTheme.surfaceHigh, KlairTheme.surfaceHigh.opacity(0.5)], startPoint: .bottom, endPoint: .top),
                ])
                .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) } }
                .chartYAxis(.hidden)
                .frame(height: 170)
                HStack(spacing: 14) {
                    legendDot(KlairTheme.indigo, "Deep"); legendDot(KlairTheme.amethyst, "REM"); legendDot(KlairTheme.surfaceHigh, "Light")
                }
            }
        }
    }

    private func legendDot(_ c: Color, _ l: String) -> some View {
        HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10); Text(l).font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) }
    }

    // MARK: - Breakdown

    @ViewBuilder
    private var todayBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("TONIGHT'S BREAKDOWN")
                stageBar("REM", min: latest?.remSleepMinutes ?? 0, total: latest?.totalSleepMinutes ?? 1, color: KlairTheme.amethyst)
                stageBar("Deep", min: latest?.deepSleepMinutes ?? 0, total: latest?.totalSleepMinutes ?? 1, color: KlairTheme.indigo)
                stageBar("Light", min: latest?.lightSleepMinutes ?? 0, total: latest?.totalSleepMinutes ?? 1, color: KlairTheme.cyan.opacity(0.4))
            }
        }
    }

    private func stageBar(_ label: String, min: Double, total: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textSecondary).frame(width: 38, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [color.opacity(0.5), color], startPoint: .leading, endPoint: .trailing)).frame(width: total > 0 ? geo.size.width * (min / total) : 0)
                }
            }
            .frame(height: 10)
            Text(String(format: "%.1fh", min / 60)).font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textTertiary).frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Sleep Consistency

    @ViewBuilder
    private var sleepConsistency: some View {
        GlassCard {
            HStack(spacing: 16) {
                ScoreRing(score: sleepConsistencyScore, label: "", color: KlairTheme.indigo, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP CONSISTENCY").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                    Text(sleepConsistencyScore >= 80 ? "Excellent — your bedtime is regular" : sleepConsistencyScore >= 50 ? "Fair — some variation in sleep timing" : "Irregular — try a consistent bedtime")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                }
                Spacer()
            }
        }
    }

    // MARK: - Sleep Debt

    private var sleepDebtHours: Double {
        let goal = profile?.sleepGoalHours ?? 7.5
        let week = Array(metrics.prefix(7))
        guard !week.isEmpty else { return 0 }
        var debt: Double = 0
        for m in week {
            let slept = m.totalSleepMinutes / 60
            debt += max(0, goal - slept)
        }
        return debt
    }

    @ViewBuilder
    private var sleepDebtCard: some View {
        let debt = sleepDebtHours
        let goal = profile?.sleepGoalHours ?? 7.5
        GlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(debt > 5 ? KlairTheme.coral.opacity(0.1) : debt > 2 ? KlairTheme.orange.opacity(0.1) : KlairTheme.emerald.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "bed.double.fill").font(.system(size: 18))
                        .foregroundStyle(debt > 5 ? KlairTheme.coral : debt > 2 ? KlairTheme.orange : KlairTheme.emerald)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP DEBT (7-DAY)").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", debt)).font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(debt > 5 ? KlairTheme.coral : debt > 2 ? KlairTheme.orange : KlairTheme.emerald)
                        Text("hours").font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                    }
                    let avgSlept = metrics.prefix(7).isEmpty ? 0 : metrics.prefix(7).map { $0.totalSleepMinutes / 60 }.reduce(0, +) / Double(metrics.prefix(7).count)
                    Text(String(format: "Avg %.1fh / %.1fh goal", avgSlept, goal))
                        .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary)
                    if debt > 5 {
                        Text("Significant sleep debt impairs insulin sensitivity by up to 30%")
                            .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.coral).lineSpacing(2)
                    } else if debt > 2 {
                        Text("Moderate debt — prioritize 8h tonight to recover")
                            .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.orange)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Circadian Alignment

    private var circadianScore: Int {
        let week = Array(metrics.prefix(7))
        guard week.count >= 3 else { return 0 }
        let deviations = week.map { abs($0.sleepMidpointDeviation) }
        let avgDev = deviations.reduce(0, +) / Double(deviations.count)
        return max(0, min(100, Int(100 - avgDev * 100)))
    }

    @ViewBuilder
    private var circadianAlignmentCard: some View {
        let score = circadianScore
        GlassCard {
            HStack(spacing: 16) {
                ScoreRing(score: score, label: "", color: KlairTheme.cyan, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("CIRCADIAN ALIGNMENT").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                    Text(score >= 80 ? "Strong rhythm — sleep and wake times are consistent"
                         : score >= 50 ? "Moderate social jet lag detected — weekday/weekend mismatch"
                         : "Irregular circadian rhythm — this impairs melatonin production")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    if score < 60 {
                        Text("Social jet lag >1h reduces next-day readiness by ~10 points")
                            .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.orange)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Correlation

    @ViewBuilder
    private var sleepCorrelation: some View {
        let lateMeals = meals.filter(\.isLateNight).prefix(3)
        let caffeineLate = meals.filter { $0.hasCaffeine && Calendar.current.component(.hour, from: $0.timestamp) >= 14 }.prefix(3)
        if !lateMeals.isEmpty || !caffeineLate.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(KlairTheme.coral)
                        meta("SLEEP DISRUPTORS")
                        Spacer()
                    }
                    if !lateMeals.isEmpty {
                        Text("Late meals reduced REM sleep ~15%. Moving last meal before 9 PM could add ~20 min restorative sleep.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }
                    if !caffeineLate.isEmpty {
                        Text("Afternoon caffeine detected (\(Int(caffeineLate.first?.caffeineMg ?? 0))mg). Caffeine after 2 PM can delay sleep onset by 20+ minutes.")
                            .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                    }
                }
            }
        }
    }

    // MARK: - Sleep Wisdom

    @ViewBuilder
    private var wisdomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            meta("SLEEP WISDOM")
            wisdomCard(icon: "moon.zzz", title: "Consistency", body: "Keep bedtime within 30 min each night for up to 12% better efficiency.", color: KlairTheme.indigo)
            wisdomCard(icon: "thermometer.snowflake", title: "Cool Room", body: "65–68°F promotes deeper sleep via natural core temperature drop.", color: KlairTheme.cyan)
            if (latest?.deepPercentage ?? 0) < 18 {
                wisdomCard(icon: "figure.yoga", title: "Boost Deep Sleep", body: "Evening stretching and screen-free time 60 min before bed helps.", color: KlairTheme.amethyst)
            }
            if (latest?.respiratoryRate ?? 0) > 17 {
                wisdomCard(icon: "lungs.fill", title: "Respiratory Rate Elevated", body: "Your breathing rate is slightly higher than optimal. Consider a nasal breathing exercise before bed.", color: KlairTheme.orange)
            }
        }
    }

    private func wisdomCard(icon: String, title: String, body: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color.opacity(0.1)).frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                Text(body).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4)
        .tapScale()
    }

    // MARK: - Meditations

    @ViewBuilder
    private var meditationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            meta("QUICK MEDITATIONS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    meditationCard(icon: "wind", title: "Breathing", subtitle: "4-7-8 technique", duration: "5 min", imageKeywords: "sunrise,morning,landscape,serene")
                    meditationCard(icon: "leaf.fill", title: "Body Scan", subtitle: "Progressive relaxation", duration: "10 min", imageKeywords: "forest,zen,calm,nature")
                    meditationCard(icon: "moon.stars.fill", title: "Sleep Story", subtitle: "Guided drift-off", duration: "15 min", imageKeywords: "night,sky,stars,peaceful")
                    meditationCard(icon: "waveform.path", title: "Sound Bath", subtitle: "Binaural beats", duration: "20 min", imageKeywords: "ocean,waves,meditation,tranquil")
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    private func meditationCard(icon: String, title: String, subtitle: String, duration: String, imageKeywords: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                WellnessImage(keywords: imageKeywords, height: 90, cornerRadius: 14)
                    .frame(width: 156)
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    Text(duration).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.ultraThinMaterial).clipShape(Capsule())
                .padding(8)
            }
            Text(title).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
            Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
        }
        .frame(width: 156).padding(12)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4)
        .tapScale()
        .carouselEffect()
    }

    private func meta(_ t: String) -> some View { Text(t).font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary) }
}
