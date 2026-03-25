import SwiftUI
import SwiftData

struct FluidWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat = 8
    var frequency: CGFloat = 2.5

    var animatableData: CGFloat { get { phase } set { phase = newValue } }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: 0, y: rect.height))
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relX = x / rect.width
            let y = amplitude * sin(2 * .pi * frequency * relX + phase)
            p.addLine(to: .init(x: x, y: y + rect.height * 0.2))
        }
        p.addLine(to: .init(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

struct BioProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \LabResult.date, order: .reverse) private var labResults: [LabResult]
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var age: String = ""
    @State private var calorieGoal: String = ""
    @State private var conditions: String = ""
    @State private var goals: String = ""
    @State private var meds: String = ""
    @State private var waterIntake: Double = 0
    @State private var wavePhase: CGFloat = 0
    @State private var showSaved: Bool = false
    @State private var cycleDay: String = ""
    @State private var cycleLength: String = ""
    @State private var bpSystolic: String = ""
    @State private var bpDiastolic: String = ""
    @State private var glucose: String = ""
    @State private var moodRating: Int = 0
    @State private var energyRating: Int = 0
    @State private var waist: String = ""
    @State private var hip: String = ""

    private var profile: UserProfile? { profiles.first }
    private var waterGoal: Double { profile?.dailyWaterGoalMl ?? 2500 }
    private var waterProgress: Double { waterGoal > 0 ? min(1, waterIntake / waterGoal) : 0 }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                bodyCompositionCard
                waistHipCard
                labResultsSection
                moodEnergyCard
                vitalSignsCard
                hydrationSection
                medicationCabinet
                medicalExamsSection
                personalSection
                conditionsSection
                goalsSection
                cycleSection
                ouraSection
                presentationModeSection
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .background(KlairTheme.background.ignoresSafeArea())
        .onAppear { loadProfile() }
        .overlay {
            if showSaved {
                Text("Saved").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(KlairTheme.emerald).clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity)).zIndex(1)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bio Vault")
                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                Text("Personal bio-data & goals")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
            }
            Spacer()
            ZStack {
                Circle().fill(KlairTheme.heroGradient).frame(width: 40, height: 40)
                KlairLogo(size: 22, color: .white.opacity(0.9))
            }
            .shadow(color: KlairTheme.amethyst.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.top, 12)
    }

    // MARK: - Body Composition

    @ViewBuilder
    private var bodyCompositionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                meta("BODY COMPOSITION")
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", profile?.bmi ?? 0))
                            .font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("BMI").font(.system(size: 10, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        Text(profile?.bmiCategory ?? "—")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(profile?.bmiCategory == "Normal" ? KlairTheme.emerald : KlairTheme.orange)
                    }
                    Divider().frame(height: 50)
                    VStack(spacing: 4) {
                        Text("\(profile?.weightKg ?? 0, specifier: "%.0f") kg")
                            .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("WEIGHT").font(.system(size: 10, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                    }
                    VStack(spacing: 4) {
                        Text("\(profile?.heightCm ?? 0, specifier: "%.0f") cm")
                            .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("HEIGHT").font(.system(size: 10, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                    }
                    if (profile?.bodyFatPercentage ?? 0) > 0 {
                        VStack(spacing: 4) {
                            Text("\(profile?.bodyFatPercentage ?? 0, specifier: "%.1f")%")
                                .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                            Text("BODY FAT").font(.system(size: 10, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Waist-to-Hip Ratio

    @ViewBuilder
    private var waistHipCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.stand").font(.system(size: 12)).foregroundStyle(KlairTheme.coral)
                    meta("WAIST-TO-HIP RATIO (PCOS)")
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            profileField(label: "Waist (cm)", text: $waist, icon: "ruler.fill", keyboard: .decimalPad)
                            profileField(label: "Hip (cm)", text: $hip, icon: "ruler.fill", keyboard: .decimalPad)
                        }
                    }
                }
                if let p = profile, p.waistToHipRatio > 0 {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", p.waistToHipRatio))
                                .font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                            Text("WHR").font(.system(size: 10, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        }
                        let riskColor: Color = p.whrCategory == "Low Risk" ? KlairTheme.emerald : p.whrCategory == "Moderate Risk" ? KlairTheme.orange : KlairTheme.coral
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.whrCategory).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(riskColor)
                            Text("WHR is more predictive of metabolic risk than BMI for PCOS. Target <0.80 for women.")
                                .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(2)
                        }
                        Spacer()
                    }
                    .padding(10).background(KlairTheme.surfaceHigh.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - Lab Results

    @ViewBuilder
    private var labResultsSection: some View {
        if !labResults.isEmpty {
            let categories = Dictionary(grouping: labResults) { $0.typeEnum.category }
            let sortedCategories = categories.keys.sorted()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "cross.vial.fill").font(.system(size: 12)).foregroundStyle(KlairTheme.amethyst)
                    meta("LAB RESULTS")
                }
                ForEach(sortedCategories, id: \.self) { category in
                    labCategoryCard(category: category, results: categories[category] ?? [])
                }
            }
        }
    }

    private func labCategoryCard(category: String, results: [LabResult]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(category.uppercased()).font(.system(size: 9, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                ForEach(results) { lab in
                    HStack(spacing: 10) {
                        Image(systemName: lab.typeEnum.icon).font(.system(size: 12)).foregroundStyle(lab.statusColor)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(lab.typeEnum.displayName).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: lab.value == floor(lab.value) ? "%.0f" : "%.1f", lab.value))
                                        .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(lab.statusColor)
                                    Text(lab.unit).font(.system(size: 8, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                                }
                                Text(lab.statusLabel).font(.system(size: 8, weight: .bold)).kerning(0.3)
                                    .foregroundStyle(lab.statusColor).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(lab.statusColor.opacity(0.1)).clipShape(Capsule())
                            }
                            Text("Ref: \(String(format: "%.1f", lab.referenceRangeLow))–\(String(format: "%.1f", lab.referenceRangeHigh)) \(lab.unit)")
                                .font(.system(size: 8, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                            if !lab.notes.isEmpty {
                                Text(lab.notes).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(2)
                            }
                        }
                    }
                    if lab.id != results.last?.id { Divider().foregroundStyle(KlairTheme.surfaceHigh) }
                }
            }
        }
    }

    // MARK: - Mood & Energy

    @ViewBuilder
    private var moodEnergyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("MOOD & ENERGY TODAY")
                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("MOOD").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { level in
                                let icons = ["😞", "😐", "🙂", "😊", "🤩"]
                                Button { moodRating = level; saveQuickRating() } label: {
                                    Text(icons[level - 1]).font(.system(size: level == moodRating ? 28 : 20))
                                        .opacity(level == moodRating ? 1 : 0.4)
                                        .scaleEffect(level == moodRating ? 1.15 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider().frame(height: 40)
                    VStack(spacing: 8) {
                        Text("ENERGY").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { level in
                                Button { energyRating = level; saveQuickRating() } label: {
                                    Image(systemName: level <= energyRating ? "bolt.fill" : "bolt")
                                        .font(.system(size: level == energyRating ? 20 : 16))
                                        .foregroundStyle(level <= energyRating ? KlairTheme.orange : KlairTheme.textTertiary)
                                        .scaleEffect(level == energyRating ? 1.15 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Vital Signs (BP, Glucose)

    @ViewBuilder
    private var vitalSignsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("VITAL SIGNS")
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.circle.fill").font(.system(size: 14)).foregroundStyle(KlairTheme.coral)
                            Text("BLOOD PRESSURE").font(.system(size: 9, weight: .bold)).kerning(0.6).foregroundStyle(KlairTheme.textTertiary)
                        }
                        HStack(spacing: 8) {
                            TextField("Sys", text: $bpSystolic).keyboardType(.numberPad)
                                .font(.system(.headline, design: .rounded).weight(.bold)).frame(width: 50)
                                .padding(8).background(KlairTheme.surfaceHigh.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("/").foregroundStyle(KlairTheme.textTertiary)
                            TextField("Dia", text: $bpDiastolic).keyboardType(.numberPad)
                                .font(.system(.headline, design: .rounded).weight(.bold)).frame(width: 50)
                                .padding(8).background(KlairTheme.surfaceHigh.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("mmHg").font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                        }
                        if let p = profile, p.bloodPressureSystolic > 0 {
                            let cat = p.bpCategory
                            let color: Color = cat == "Normal" ? KlairTheme.emerald : cat == "Elevated" ? KlairTheme.orange : KlairTheme.coral
                            Text(cat).font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(color)
                        }
                    }
                    Divider().frame(height: 60)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.circle.fill").font(.system(size: 14)).foregroundStyle(KlairTheme.cyan)
                            Text("GLUCOSE").font(.system(size: 9, weight: .bold)).kerning(0.6).foregroundStyle(KlairTheme.textTertiary)
                        }
                        HStack(spacing: 4) {
                            TextField("mg/dL", text: $glucose).keyboardType(.decimalPad)
                                .font(.system(.headline, design: .rounded).weight(.bold)).frame(width: 60)
                                .padding(8).background(KlairTheme.surfaceHigh.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("mg/dL").font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                        }
                        if let g = profile?.glucoseMgDl, g > 0 {
                            let color: Color = g < 100 ? KlairTheme.emerald : g < 126 ? KlairTheme.orange : KlairTheme.coral
                            Text(g < 100 ? "Normal" : g < 126 ? "Pre-diabetic" : "High")
                                .font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(color)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hydration

    @ViewBuilder
    private var hydrationSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("HYDRATION")
                ZStack {
                    RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous)
                        .fill(KlairTheme.cyan.opacity(0.04))
                        .frame(height: 80)

                    ZStack {
                        FluidWaveShape(phase: wavePhase, amplitude: 6, frequency: 3)
                            .fill(KlairTheme.cyan.opacity(0.15))
                            .frame(height: 80 * waterProgress)
                        FluidWaveShape(phase: wavePhase + 1.5, amplitude: 4, frequency: 2)
                            .fill(KlairTheme.cyan.opacity(0.2))
                            .frame(height: 80 * waterProgress)
                        FluidWaveShape(phase: wavePhase + 3, amplitude: 8, frequency: 2.5)
                            .fill(KlairTheme.cyanGradient.opacity(0.3))
                            .frame(height: 80 * waterProgress)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                    .frame(height: 80, alignment: .bottom)

                    VStack(spacing: 2) {
                        Text(String(format: "%.0f ml", waterIntake))
                            .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.cyan)
                        Text("of \(Int(waterGoal)) ml goal")
                            .font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                    }
                }
                .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { wavePhase = .pi * 2 } }
                HStack {
                    Button { withAnimation(.spring(response: 0.3)) { waterIntake = min(waterGoal, waterIntake + 250) }; saveWater(); SensoryManager.shared.success() } label: {
                        Label("+ 250 ml", systemImage: "drop.fill").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.cyan)
                            .padding(.horizontal, 16).padding(.vertical, 10).background(KlairTheme.cyan.opacity(0.08)).clipShape(Capsule())
                    }
                    Spacer()
                    Button { withAnimation(.spring(response: 0.3)) { waterIntake = 0 }; saveWater() } label: {
                        Text("Reset").font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Medication Cabinet

    @ViewBuilder
    private var medicationCabinet: some View {
        let medsList = profile?.medicationsList ?? []
        if !medsList.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    meta("MEDICATION CABINET")
                    let colors: [Color] = [KlairTheme.coral, KlairTheme.orange, KlairTheme.emerald, KlairTheme.amethyst]
                    let icons = ["pill.fill", "cross.vial.fill", "pills.fill", "pill.circle.fill"]
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Array(medsList.enumerated()), id: \.offset) { idx, med in
                            medicationTile(med, color: colors[idx % colors.count], icon: icons[idx % icons.count])
                        }
                    }
                }
            }
        }
    }

    private func medicationTile(_ name: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color.opacity(0.1)).frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color))
            Text(name).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary).lineLimit(2)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
        .cloudShadow(radius: 8, y: 3).tapScale()
    }

    // MARK: - Medical Exams

    @ViewBuilder
    private var medicalExamsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { meta("MEDICAL EXAMS"); Spacer(); Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(KlairTheme.amethyst) }
                Text("Upload blood work, lab results, or medical scans to refine Klair's AI alerts and personalized recommendations.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
                HStack(spacing: 12) {
                    uploadButton(icon: "doc.text.viewfinder", label: "Scan Document", color: KlairTheme.cyan)
                    uploadButton(icon: "photo.on.rectangle", label: "Upload Photo", color: KlairTheme.amethyst)
                }
                VStack(alignment: .leading, spacing: 8) {
                    examRow(name: "Blood Panel — March 2026", date: "Mar 12", status: "Analyzed", statusColor: KlairTheme.emerald)
                    examRow(name: "Hormone Panel", date: "Feb 28", status: "Analyzed", statusColor: KlairTheme.emerald)
                    examRow(name: "Thyroid Function", date: "Jan 15", status: "Pending", statusColor: KlairTheme.orange)
                }
            }
        }
    }

    private func uploadButton(icon: String, label: String, color: Color) -> some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
                Text(label).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(color.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func examRow(name: String, date: String, status: String, statusColor: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
                Text(date).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
            }
            Spacer()
            Text(status).font(.system(size: 9, weight: .bold)).kerning(0.5).foregroundStyle(statusColor)
                .padding(.horizontal, 8).padding(.vertical, 3).background(statusColor.opacity(0.1)).clipShape(Capsule())
        }
    }

    // MARK: - Personal Info

    @ViewBuilder
    private var personalSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("PERSONAL INFORMATION")
                profileField(label: "Name", text: $name, icon: "person.fill")
                HStack(spacing: 12) {
                    profileField(label: "Weight (kg)", text: $weight, icon: "scalemass.fill", keyboard: .decimalPad)
                    profileField(label: "Height (cm)", text: $height, icon: "ruler.fill", keyboard: .decimalPad)
                }
                HStack(spacing: 12) {
                    profileField(label: "Age", text: $age, icon: "calendar", keyboard: .numberPad)
                    profileField(label: "Calorie Goal", text: $calorieGoal, icon: "flame.fill", keyboard: .numberPad)
                }
            }
        }
    }

    private func profileField(label: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(KlairTheme.textTertiary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 9, weight: .semibold)).kerning(0.6).foregroundStyle(KlairTheme.textTertiary)
                TextField("", text: text).keyboardType(keyboard)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(KlairTheme.textPrimary)
            }
        }
        .padding(12).background(KlairTheme.surfaceHigh.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Conditions & Goals

    @ViewBuilder
    private var conditionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                meta("MEDICAL CONDITIONS")
                profileField(label: "Conditions (comma separated)", text: $conditions, icon: "heart.text.square.fill")
                profileField(label: "Medications (comma separated)", text: $meds, icon: "pill.fill")
            }
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                meta("HEALTH GOALS")
                profileField(label: "Goals (comma separated)", text: $goals, icon: "target")
            }
        }
    }

    // MARK: - Cycle Tracking

    @ViewBuilder
    private var cycleSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                meta("CYCLE TRACKING")
                HStack(spacing: 12) {
                    profileField(label: "Cycle Day", text: $cycleDay, icon: "calendar.circle.fill", keyboard: .numberPad)
                    profileField(label: "Cycle Length", text: $cycleLength, icon: "arrow.triangle.2.circlepath", keyboard: .numberPad)
                }
                if let phase = profile?.cyclePhase {
                    HStack(spacing: 8) {
                        Image(systemName: phase.icon).foregroundStyle(phase.phaseColor)
                        Text(phase.rawValue).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(phase.phaseColor)
                        Spacer()
                        Text(phase.readinessImpact).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).multilineTextAlignment(.trailing)
                    }
                    .padding(10).background(phase.phaseColor.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - Oura

    @ViewBuilder
    private var ouraSection: some View {
        GlassCard {
            HStack(spacing: 14) {
                Circle().fill(KlairTheme.emerald.opacity(0.1)).frame(width: 40, height: 40)
                    .overlay(Image(systemName: "circle.dotted").font(.system(size: 18)).foregroundStyle(KlairTheme.emerald))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Oura Ring").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                    Text(profile?.ouraConnected == true ? "Connected" : "Not connected").font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { profile?.ouraConnected ?? false }, set: { val in profile?.ouraConnected = val; try? modelContext.save() }))
                    .labelsHidden().tint(KlairTheme.emerald)
            }
        }
    }

    // MARK: - Presentation Mode

    @State private var isPresentationMode: Bool = DemoMode.presentationMode

    private var presentationModeSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Circle().fill(KlairTheme.amethyst.opacity(0.1)).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "sparkles.tv").font(.system(size: 18)).foregroundStyle(KlairTheme.amethyst))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Presentation Mode").font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("Re-seed 14-day real Oura data for demo").font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $isPresentationMode)
                        .labelsHidden().tint(KlairTheme.amethyst)
                        .onChange(of: isPresentationMode) { _, newVal in
                            DemoMode.presentationMode = newVal
                            if newVal { MockData.seedPresentationMode(context: modelContext) }
                            SensoryManager.shared.success()
                        }
                }
                if isPresentationMode {
                    Text("Real Oura Ring data + causally consistent trends active.")
                        .font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.amethyst)
                }
            }
        }
    }

    // MARK: - Save

    @ViewBuilder
    private var saveButton: some View {
        Button { save() } label: {
            Text("Save Profile").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(KlairTheme.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
                .shadow(color: KlairTheme.amethyst.opacity(0.25), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadProfile() {
        guard let p = profile else { return }
        name = p.name; weight = "\(Int(p.weightKg))"; height = "\(Int(p.heightCm))"
        age = "\(p.age)"; calorieGoal = "\(Int(p.dailyCalorieGoal))"
        conditions = p.knownConditions; goals = p.healthGoals; meds = p.medications
        waterIntake = p.waterIntakeMl
        cycleDay = "\(p.cycleDay)"; cycleLength = "\(p.cycleLength)"
        bpSystolic = p.bloodPressureSystolic > 0 ? "\(p.bloodPressureSystolic)" : ""
        bpDiastolic = p.bloodPressureDiastolic > 0 ? "\(p.bloodPressureDiastolic)" : ""
        glucose = p.glucoseMgDl > 0 ? String(format: "%.0f", p.glucoseMgDl) : ""
        moodRating = p.moodRating; energyRating = p.energyRating
        waist = p.waistCm > 0 ? String(format: "%.0f", p.waistCm) : ""
        hip = p.hipCm > 0 ? String(format: "%.0f", p.hipCm) : ""
    }

    private func save() {
        guard let p = profile else { return }
        p.name = name; p.weightKg = Double(weight) ?? p.weightKg; p.heightCm = Double(height) ?? p.heightCm
        p.age = Int(age) ?? p.age; p.dailyCalorieGoal = Double(calorieGoal) ?? p.dailyCalorieGoal
        p.knownConditions = conditions; p.healthGoals = goals; p.medications = meds
        p.waterIntakeMl = waterIntake
        p.cycleDay = Int(cycleDay) ?? p.cycleDay; p.cycleLength = Int(cycleLength) ?? p.cycleLength
        p.bloodPressureSystolic = Int(bpSystolic) ?? 0; p.bloodPressureDiastolic = Int(bpDiastolic) ?? 0
        p.glucoseMgDl = Double(glucose) ?? 0; p.moodRating = moodRating; p.energyRating = energyRating
        p.waistCm = Double(waist) ?? 0; p.hipCm = Double(hip) ?? 0
        try? modelContext.save()
        SensoryManager.shared.success()
        withAnimation(.spring(response: 0.3)) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showSaved = false } }
    }

    private func saveWater() {
        profile?.waterIntakeMl = waterIntake; try? modelContext.save()
    }

    private func saveQuickRating() {
        SensoryManager.shared.selection()
        profile?.moodRating = moodRating; profile?.energyRating = energyRating; try? modelContext.save()
    }

    private func meta(_ t: String) -> some View { Text(t).font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary) }
}
