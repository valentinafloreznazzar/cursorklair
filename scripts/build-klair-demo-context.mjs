/**
 * Builds klair-demo-context.json from the same numeric seeds as Klair/MockData/MockData.swift
 * (Oura sleep export + derived readiness/HRV/stress; activity days; meal patterns).
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT = path.join(__dirname, '..')

function isoNoonDaysAgo(off) {
  const d = new Date()
  d.setUTCHours(12, 0, 0, 0)
  d.setUTCDate(d.getUTCDate() - off)
  return d.toISOString()
}

function mealTs(dayOff, h, m) {
  const d = new Date()
  d.setUTCHours(12, 0, 0, 0)
  d.setUTCDate(d.getUTCDate() - dayOff)
  d.setUTCHours(h, m, 0, 0)
  return d.toISOString()
}

// MockData.swift realSleep + derived
const realSleep = [
  [0, 80, 450, 96, 86, 267, 40],
  [1, 88, 503, 104, 98, 301, 23],
  [2, 93, 507, 115, 123, 268, 12],
  [3, 93, 514, 96, 110, 307, 17],
  [4, 78, 420, 65, 95, 260, 25],
  [5, 80, 428, 90, 119, 218, 18],
  [6, 65, 381, 39, 83, 258, 9],
  [7, 85, 454, 67, 107, 279, 15],
  [8, 87, 468, 110, 98, 260, 28],
  [9, 82, 474, 79, 107, 287, 20],
  [10, 91, 481, 89, 116, 276, 18],
  [11, 80, 386, 66, 74, 245, 16],
  [12, 76, 333, 85, 66, 182, 17],
  [13, 76, 365, 92, 90, 183, 18],
]

const derived = [
  [76, 34, 57, 0.32, 86, 18, false, 15.2, 97, 42, 25, 0.1],
  [83, 40, 54, 0.28, 91, 22, false, 15.0, 98, 28, 12, -0.1],
  [90, 47, 52, 0.24, 95, 28, false, 14.8, 98, 15, 5, 0.0],
  [88, 45, 53, 0.18, 94, 26, false, 14.9, 97, 18, 8, 0.05],
  [71, 31, 59, 0.1, 85, 17, false, 15.4, 97, 48, 30, 0.2],
  [73, 33, 58, 0.05, 87, 19, false, 15.3, 97, 38, 22, 0.15],
  [58, 24, 62, -0.02, 78, 12, true, 15.8, 96, 78, 55, 0.4],
  [80, 38, 55, -0.05, 89, 21, false, 15.1, 98, 35, 18, -0.1],
  [82, 39, 55, -0.08, 88, 23, false, 14.9, 98, 30, 14, -0.15],
  [78, 36, 56, -0.1, 87, 20, false, 15.0, 97, 32, 16, 0.0],
  [85, 42, 54, -0.12, 90, 24, false, 14.8, 98, 22, 10, -0.05],
  [74, 34, 57, -0.15, 84, 18, false, 15.2, 97, 40, 24, 0.1],
  [68, 29, 60, -0.18, 81, 15, true, 15.5, 96, 55, 35, 0.25],
  [72, 32, 58, -0.2, 83, 17, false, 15.3, 97, 45, 28, 0.2],
]

const readinessContribSets = [
  {
    previous_night_activity: 'optimal',
    sleep_balance: 'good',
    body_temperature: 'normal',
    hrv_balance: 'restored',
    recovery_index: 'good',
    resting_heart_rate: 'optimal',
  },
  {
    previous_night_activity: 'high',
    sleep_balance: 'fair',
    body_temperature: 'elevated',
    hrv_balance: 'strained',
    recovery_index: 'fair',
    resting_heart_rate: 'elevated',
  },
  {
    previous_night_activity: 'optimal',
    sleep_balance: 'good',
    body_temperature: 'normal',
    hrv_balance: 'good',
    recovery_index: 'optimal',
    resting_heart_rate: 'good',
  },
  {
    previous_night_activity: 'low',
    sleep_balance: 'optimal',
    body_temperature: 'normal',
    hrv_balance: 'restored',
    recovery_index: 'good',
    resting_heart_rate: 'optimal',
  },
  {
    previous_night_activity: 'moderate',
    sleep_balance: 'fair',
    body_temperature: 'slightly_elevated',
    hrv_balance: 'fair',
    recovery_index: 'fair',
    resting_heart_rate: 'normal',
  },
]

const recentOura = realSleep.map((row, i) => {
  const [off, ss, tot, deep, rem, light, lat] = row
  const d = derived[i]
  return {
    date: isoNoonDaysAgo(off),
    readiness: d[0],
    sleep: ss,
    hrv: d[1],
    remMinutes: rem,
    deepMinutes: deep,
    lightMinutes: light,
    totalMinutes: tot,
    sleepEfficiency: d[4],
    sleepLatency: lat,
    temperatureDeviation: d[3],
    restingHeartRate: d[2],
    hrvDaytimeLow: d[5],
    stressFlag: d[6],
    respiratoryRate: d[7],
    spo2: d[8],
    stressScore: d[9],
    stressDurationMin: d[10],
    sleepMidpointDeviation: d[11],
    readinessContributors: { ...readinessContribSets[i % readinessContribSets.length] },
  }
})

const acts = [
  [0, 'HIIT', 5200, 310, 25, 18, 38.8, 380, 350, 'maintaining'],
  [1, 'Running', 7000, 420, 18, 28, 39.1, 360, 345, 'maintaining'],
  [2, 'Strength', 7500, 380, 12, 35, 38.5, 340, 340, 'maintaining'],
  [3, 'Cycling', 8100, 450, 20, 32, 39.4, 355, 338, 'maintaining'],
  [4, 'Yoga', 5800, 220, 0, 40, 38.2, 310, 335, 'maintaining'],
  [5, 'Walking', 6200, 260, 0, 22, 38.0, 290, 330, 'maintaining'],
  [6, 'Rest', 3800, 140, 0, 0, 37.8, 250, 325, 'recovery'],
  [7, 'HIIT', 9200, 520, 32, 22, 39.6, 420, 320, 'overreaching'],
  [8, 'Pilates', 6500, 280, 5, 35, 38.5, 330, 318, 'maintaining'],
  [9, 'Running', 7800, 400, 16, 25, 39.0, 345, 315, 'maintaining'],
  [10, 'Strength', 8400, 440, 10, 38, 38.7, 350, 310, 'maintaining'],
  [11, 'Yoga', 7200, 250, 0, 42, 38.3, 300, 308, 'maintaining'],
  [12, 'Rest', 5400, 180, 0, 0, 38.0, 260, 305, 'recovery'],
  [13, 'Walking', 6800, 290, 0, 20, 38.1, 280, 300, 'maintaining'],
]

const recentActivity = acts.map(([off, wt, steps, cal, hi, med, vo2, acu, chr, st]) => ({
  date: isoNoonDaysAgo(off),
  steps,
  activeCalories: cal,
  workoutType: wt,
  highIntensityMinutes: hi,
  mediumIntensityMinutes: med,
  vo2Max: vo2,
  trainingLoadAcute: acu / 100,
  trainingLoadChronic: chr / 100,
  trainingLoadStatus: st,
}))

// Meal templates per day offset (matches MockData dayMealMap spirit)
const M = (h, m, cal, p, c, f, title, hg, ln, gl, caff, alc) => ({
  hour: h,
  minute: m,
  calories: cal,
  protein: p,
  carbs: c,
  fat: f,
  mealTitle: title,
  isHighGlycemic: hg,
  isLateNight: ln,
  glycemicLoad: gl,
  caffeineMg: caff,
  alcoholUnits: alc,
  fiber: 6,
  sugar: 8,
  notes: '',
  micronutrientsJSON: null,
})

const dayMeals = {
  0: [
    M(8, 0, 380, 22, 40, 14, 'Overnight oats with chia & berries', false, false, 16, 0, 0),
    M(12, 30, 560, 34, 48, 20, 'Mediterranean bowl with falafel', false, false, 24, 0, 0),
    M(16, 0, 45, 1, 0, 0, 'Espresso', false, false, 0, 95, 0),
    M(19, 45, 680, 36, 58, 26, 'Grilled chicken with roasted veg', false, false, 28, 0, 0),
  ],
  1: [
    M(8, 10, 420, 22, 48, 16, 'Greek yogurt & mixed berries', false, false, 22, 0, 0),
    M(12, 30, 580, 35, 52, 22, 'Grilled chicken & quinoa bowl', false, false, 28, 0, 0),
    M(16, 0, 45, 1, 0, 0, 'Espresso', false, false, 0, 95, 0),
    M(19, 30, 650, 38, 55, 24, 'Salmon with roasted vegetables', false, false, 26, 0, 0),
  ],
  6: [
    M(9, 0, 380, 12, 58, 14, 'Pancakes with maple syrup', true, false, 45, 0, 0),
    M(13, 0, 710, 22, 78, 32, 'Burger with fries', true, false, 55, 0, 0),
    M(16, 0, 45, 1, 0, 0, 'Espresso', false, false, 0, 95, 0),
    M(20, 0, 580, 30, 52, 20, 'Chicken stir-fry with noodles', false, false, 32, 0, 0),
  ],
  7: [
    M(7, 30, 350, 20, 42, 12, 'Oatmeal with walnuts & banana', false, false, 18, 0, 0),
    M(12, 0, 620, 32, 58, 20, 'Turkey wrap with avocado', false, false, 30, 0, 0),
    M(15, 30, 90, 1, 0, 0, 'Double espresso', false, false, 0, 190, 0),
    M(19, 0, 550, 28, 48, 22, 'Stir-fry with brown rice', false, false, 28, 0, 0),
    M(22, 15, 420, 14, 62, 16, 'Late-night pasta & wine', true, true, 52, 0, 1.5),
  ],
}

function defaultDayMeals() {
  return dayMeals[1]
}

const recentMeals = []
for (let offset = 0; offset < 14; offset++) {
  const list = dayMeals[offset] || defaultDayMeals()
  for (const sp of list) {
    recentMeals.push({
      timestamp: mealTs(offset, sp.hour, sp.minute),
      mealTitle: sp.mealTitle,
      calories: sp.calories,
      protein: sp.protein,
      carbs: sp.carbs,
      fat: sp.fat,
      fiber: sp.fiber,
      sugar: sp.sugar,
      caffeineMg: sp.caffeineMg,
      alcoholUnits: sp.alcoholUnits,
      glycemicLoad: sp.glycemicLoad,
      notes: sp.notes,
      micronutrientsJSON: sp.micronutrientsJSON,
      isHighGlycemic: sp.isHighGlycemic,
      isLateNight: sp.isLateNight,
    })
  }
}
recentMeals.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))

const payload = {
  user: {
    name: 'Marta García',
    age: 32,
    weightKg: 62.5,
    heightCm: 168,
    bmi: 22.1,
    bodyFatPercentage: 24,
    waistCm: 72,
    hipCm: 98,
    waistToHipRatio: 0.73,
    dailyCalorieGoal: 1950,
    bmr: 1380,
    menstruationTrackingEnabled: true,
    knownConditions: 'PCOS (diagnosed), mild anemia — low ferritin',
    healthGoals: 'Better sleep, stable energy, iron repletion',
    medications: 'Metformin 500mg, iron supplement',
    cycleDay: 22,
    cycleLength: 28,
    cyclePhase: 'luteal',
    bloodPressure: '118/76',
    bpCategory: 'Normal',
    glucoseMgDl: 92,
    waterIntakeMl: 1200,
    waterGoalMl: 2500,
    moodRating: 7,
    energyRating: 3,
  },
  recentMeals,
  recentOura,
  recentActivity,
  healthKitWorkouts: [
    { name: 'Pilates', start: mealTs(0, 17, 0), durationMinutes: 55, kcal: 210 },
    { name: 'HIIT', start: mealTs(1, 7, 30), durationMinutes: 38, kcal: 320 },
  ],
  healthKitMenstrual: [{ date: isoNoonDaysAgo(1), flow: 'Light' }],
  energyActivities: [
    {
      timestamp: mealTs(0, 17, 55),
      type: 'exercise',
      intensity: 'medium',
      effect: 'withdrawal',
      context: 'Evening Pilates',
      energyDelta: -3,
      hrvChange: -4.2,
    },
    {
      timestamp: mealTs(1, 9, 0),
      type: 'social',
      intensity: 'low',
      effect: 'deposit',
      context: 'Walk with coffee',
      energyDelta: 4,
      hrvChange: 1.1,
    },
  ],
  labResults: [
    { date: isoNoonDaysAgo(24), testType: 'Ferritin', value: 18, unit: 'ng/mL', status: 'Low', notes: 'Below optimal for athletes' },
    { date: isoNoonDaysAgo(24), testType: 'HbA1c', value: 5.3, unit: '%', status: 'Normal', notes: '' },
    { date: isoNoonDaysAgo(60), testType: 'Vitamin D', value: 28, unit: 'ng/mL', status: 'Low', notes: '' },
  ],
  cycleSymptoms: [
    { date: isoNoonDaysAgo(0), cycleDay: 22, phase: 'luteal', pmsSeverity: 4, topSymptoms: 'bloating:moderate, fatigue:mild' },
  ],
  energyBattery: {
    selfReportedEnergy1to10: 3,
    selfReportedMood1to10: 7,
    recentDepositsCount: 4,
    recentWithdrawalsCount: 2,
    lastDepositSummary: 'Walk with coffee (+4)',
    lastWithdrawalSummary: 'Evening Pilates (-3)',
  },
  healthAlerts: [
    { title: 'Hydration below target', message: 'Intake ~48% of goal; mild dehydration can reduce HRV.', severity: 'warning' },
    { title: 'Late glycemic load', message: 'Late high-GL meals correlate with lower sleep efficiency in your 7d data.', severity: 'info' },
    { title: 'Luteal phase', message: 'Elevated progesterone may raise temperature and affect HRV — expected variation.', severity: 'info' },
  ],
  correlations: [
    { label: 'Late meals vs sleep efficiency', r: -0.41, description: 'Later calories correlate with lower sleep efficiency this week.' },
    { label: 'HRV vs evening training', r: -0.28, description: 'Evening sessions modestly associated with lower same-night HRV.' },
    { label: 'Steps vs readiness', r: 0.35, description: 'Higher step days trend with next-day readiness.' },
  ],
  chefRecipes: [
    {
      title: 'Iron-rich lentil bowl',
      calories: 520,
      protein: 32,
      carbs: 58,
      fat: 16,
      why: 'Supports ferritin repletion with vitamin C from tomatoes; steady carbs for PCOS.',
      ingredients: ['Red lentils', 'Kale', 'Cherry tomatoes', 'Olive oil', 'Lemon'],
    },
    {
      title: 'Baked salmon & greens',
      calories: 480,
      protein: 38,
      carbs: 22,
      fat: 24,
      why: 'Omega-3 and protein without high glycemic load for luteal phase.',
      ingredients: ['Salmon fillet', 'Asparagus', 'Spinach', 'Dill'],
    },
    {
      title: 'Greek yogurt parfait',
      calories: 340,
      protein: 24,
      carbs: 38,
      fat: 12,
      why: 'Protein-forward snack; berries add polyphenols with moderate sugar.',
      ingredients: ['Greek yogurt', 'Berries', 'Chia', 'Walnuts'],
    },
  ],
  webCopy: {
    dailyInsight: 'Recovery is trending up vs your rough patch 3 nights ago — keep hydration and meal timing steady.',
    inspirationalQuote: 'Small, steady rhythms beat heroic sprints when your nervous system is listening.',
    bioNarrative:
      'Your Oura ring shows a luteal-phase temperature lift with HRV still in a workable band. Late meals on high-training days line up with the nights your deep sleep dipped — worth watching timing more than volume.',
    stressDescription:
      'HRV daytime low and stress score suggest sympathetic load after evening training; breathwork before bed may help.',
  },
}

const out = path.join(ROOT, 'klair-demo-context.json')
fs.writeFileSync(out, JSON.stringify(payload, null, 2))
console.log('Wrote', out, 'meals', recentMeals.length, 'oura', recentOura.length)
