# PRD: Fitness Progress App (iOS) — v4 LOCKED

Status: **BASELINE REQUIREMENT — LOCKED**. Perubahan scope setelah ini harus dicatat sebagai revisi baru (v5, v6, dst), bukan overwrite diam-diam.

## 1. Tujuan
Aplikasi iOS pribadi untuk tracking progress fitness (lari/trail run dari Huawei Watch via Strava, gym, recovery, body metrics — manual) dengan AI assistant untuk tanya-jawab, buat jadwal, menilai hasil latihan, dan menyusun strategi race/latihan.

## 2. Sumber Data
- Lari/trail run: Huawei Watch → Strava (sudah connect) → app tarik via Strava API (polling, bukan webhook)
- Gym: manual input + template
- Recovery: manual input + template
- Body metrics (InBody): manual input + template, ATAU foto hasil timbangan InBody (OCR)

## 3. Platform & Auth
- iOS native, Swift, SwiftData (local DB, no backend)
- Login: Strava OAuth langsung (tanpa akun terpisah)

## 4. Fitur

### 4.1 Sync Strava
- GET /athlete/activities — polling saat app dibuka/refresh
- Detail: distance, pace, elevation, HR, waktu, rute (polyline)

### 4.2 Input Gym
- Manual input: exercise, set, reps, berat
- Template exercise favorit untuk input cepat
- Riwayat progress per exercise

### 4.3 Input via Gambar (OCR)
- Foto/screenshot hasil training dari Huawei Watch/Huawei Health → OCR (Apple Vision framework, on-device) → isi form otomatis → user review/koreksi sebelum save
- Dipakai juga untuk recovery (screenshot Huawei Health) dan body metrics (foto timbangan InBody)
- OCR tidak auto-trust; selalu ada langkah review manual

### 4.4 Input Recovery
- Manual input + template (atau OCR dari screenshot Huawei Health)
- Field: sleepScore, sleepDuration, hrAvg (semalam), hrv, deepSleepDuration

### 4.5 Input Body Metrics (InBody) — BARU
- Frekuensi: bulanan
- Manual input + template, ATAU foto hasil timbangan InBody → OCR
- Field: berat badan, body fat %, muscle mass, visceral fat, BMR, (field lain sesuai yang tercetak di kertas InBody — sesuaikan saat implementasi setelah lihat contoh struk asli)

### 4.6 Dashboard
- Ringkasan mingguan/bulanan: total distance, total sesi gym, trend recovery, trend body composition
- Grafik progress: pace over time, volume angkatan over time, body metrics over time (bulanan)

### 4.7 AI Assistant (DeepSeek API)
Context gabungan: Activity + GymSession + RecoveryLog + BodyMetrics.
- Tanya-jawab progress bebas
- Buat jadwal latihan (mingguan/bulanan, berdasarkan histori + goal)
- Menilai hasil latihan (bandingkan vs plan/histori, feedback)
- Strategy plan race (pacing, perlu input jarak/target waktu/elevation)
- Strategy latihan (periodization: base building, tapering, dll)
- Disclaimer di UI: AI-generated, bukan pengganti coach/dokter manusia — terutama untuk race strategy dan body metrics assessment

## 5. Backend/Infra — LOCKED
- Tanpa backend server. Local database: SwiftData
- Strava: polling (bukan webhook)
- AI: DeepSeek API (OpenAI-compatible REST), API key disimpan di Keychain (bukan plaintext)
- Trade-off yang disadari: data tidak realtime (refresh manual), API key client-side (acceptable karena app personal, tidak didistribusikan publik)

## 6. Data Model (SwiftData)
- `Activity`: id, source(strava), type, distance, duration, pace, elevation, hrAvg, hrMax, date, polyline
- `GymSession`: id, date, exercises: [Exercise]
- `Exercise`: name, sets: [SetEntry{reps, weight}]
- `RecoveryLog`: id, date, sleepScore, sleepDuration, hrAvg, hrv, deepSleepDuration, sourceImage(optional)
- `BodyMetrics`: id, date, weight, bodyFatPercent, muscleMass, visceralFat, bmr, sourceImage(optional)
- `TrainingPlan`: id, weekStart, goal(race/general), sessions: [PlannedSession]
- `RaceGoal`: id, raceDate, distance, targetTime, elevationProfile(optional)
- `StravaAuth`: accessToken, refreshToken, expiresAt
- `DeepSeekConfig`: apiKey (Keychain, bukan SwiftData plain)

## 7. Out of Scope (Fase 1)
- Sync otomatis dari Huawei Health Kit (approval developer ribet — semua recovery/body metrics tetap manual/OCR)
- Multi-user / social features
- Realtime webhook Strava

## 8. Risiko & Catatan
- OCR akurasi tidak 100%, selalu perlu review manual sebelum save
- LLM (race strategy, training strategy) bukan pengganti sport-science/medical expertise — perlu disclaimer, terutama untuk race pacing dan body composition assessment
- API key client-side exposure risk — acceptable untuk app personal, TIDAK acceptable kalau nanti didistribusikan publik (perlu proxy server saat itu)
- DeepSeek context window: histori aktivitas bisa besar seiring waktu — perlu strategi summarize/truncate context, jangan kirim seluruh histori mentah tiap chat
- Input manual 4 kategori (gym, recovery, body metrics, kadang activity kalau OCR gagal) = effort tinggi, risiko user berhenti pakai. Mitigasi: template/preset cepat, reminder notification

## 9. Catatan Implementasi Non-Requirement (tidak mengubah scope v4)
- Verifikasi 24 Sep: semua data di UI mock "Activity detail" (distance, pace, elevation, HR, splits, incl. treadmill test) berasal dari satu sumber: Strava API (activity fields + streams endpoint untuk elevation/split per km).
- HR Zones (Z1-Z5), "km-effort", "power-hike trigger" di UI mock: dihitung on-the-fly dari Strava streams (HR/altitude/distance) + HRmax/HRrest yang user set sendiri — BUKAN field data model baru, tidak ditambah ke Section 6. Kalau nanti perlu disimpan permanen, jadi revisi v5.
- Training plan & race pacing plan (contoh: "Pacing plan for SMR 30K") dipenuhi via AI Coach chat (4.7), bukan surface/kalender terpisah — sesuai keputusan awal.

## 10. Log Keputusan (locked)
- Platform: iOS native Swift
- Auth: Strava OAuth langsung
- Backend: none, SwiftData local only
- Strava sync: polling
- AI provider: DeepSeek API
- Gym/Recovery/BodyMetrics: manual + template + OCR gambar opsional
- Body metrics frequency: bulanan (InBody)
