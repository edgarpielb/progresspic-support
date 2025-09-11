import SwiftUI
import SwiftData
import PhotosUI

private let accent = Color(red: 0.24, green: 0.85, blue: 0.80)

struct JourneysView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showNew = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Force dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(journeys) { j in JourneyCard(journey: j) }
                        Button {
                            showNew = true
                        } label: {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Add Journey")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                )
                                .frame(height: 120)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120) // Space for custom tab bar
                .scrollContentBackground(.hidden)
            }
            .background(Color(red: 30/255, green: 32/255, blue: 35/255))
            .navigationTitle("Journeys")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .sheet(isPresented: $showNew) { NewJourneySheet() }
    }
}

struct JourneyCard: View {
    @Environment(\.modelContext) private var ctx
    @Query private var photos: [ProgressPhoto]
    let journey: Journey

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId })
    }

    var body: some View {
        NavigationLink {
            JourneyDetailView(journey: journey)
        } label: {
            HStack(spacing: 16) {
                CoverThumb(localId: journey.coverAssetLocalId ?? photos.first?.assetLocalId)
                VStack(alignment: .leading, spacing: 6) {
                    Text(journey.name).font(.title3.bold())
                    Text("\(photos.count) photos · Started \(journey.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06)))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

struct CoverThumb: View {
    @State private var img: UIImage?
    var localId: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.2))
            if let ui = img {
                Image(uiImage: ui).resizable().scaledToFill().clipped()
            } else {
                Image(systemName: "camera").font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            if let id = localId { img = await PhotoStore.fetchUIImage(localId: id, targetSize: CGSize(width: 160, height: 160)) }
        }
    }
}

struct NewJourneySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var saveToCameraRoll = true
    @State private var reminderTimes: [DateComponents] = []
    @State private var timeDraft: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("My new journey", text: $name) }
                Section("Reminders") {
                    ForEach(Array(reminderTimes.enumerated()), id: \.offset) { idx, comps in
                        HStack {
                            Text("\(String(format: "%02d", comps.hour ?? 0)):\(String(format: "%02d", comps.minute ?? 0))")
                            Spacer()
                            Button(role: .destructive) { reminderTimes.remove(at: idx) } label: { Image(systemName: "trash") }
                        }
                    }
                    DatePicker("Add time", selection: $timeDraft, displayedComponents: .hourAndMinute)
                    Button("Add") {
                        let cal = Calendar.current
                        let comps = cal.dateComponents([.hour, .minute], from: timeDraft)
                        reminderTimes.append(comps)
                    }
                }
                Section {
                    Toggle("Save photos to camera roll", isOn: $saveToCameraRoll)
                }
            }
            .navigationTitle("New Journey")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let j = Journey(name: name.isEmpty ? "My Journey" : name,
                                        saveToCameraRoll: saveToCameraRoll,
                                        reminderTimes: reminderTimes)
                        ctx.insert(j)
                        Task { _ = await ReminderManager.requestPermission(); ReminderManager.schedule(for: j) }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct JourneyDetailView: View {
    @Environment(\.modelContext) private var ctx
    let journey: Journey
    @Query private var photos: [ProgressPhoto]
    @State private var showImporter = false
    @State private var importSelection = [PhotosPickerItem]()

    init(journey: Journey) {
        self.journey = journey
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                        sort: \ProgressPhoto.date, order: .reverse)
    }

    var columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink { CameraHostView(journey: journey) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.15))
                        Image(systemName: "camera").font(.title)
                            .foregroundStyle(.secondary)
                    }.frame(height: 120)
                }
                ForEach(photos) { p in
                    PhotoTile(localId: p.assetLocalId, date: p.date)
                }
            }
            .padding(16)
            .padding(.bottom, 120)
        }
        .navigationTitle(journey.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                PhotosPicker(selection: $importSelection, maxSelectionCount: 30, matching: .images) {
                    Image(systemName: "square.and.arrow.down").font(.body)
                }
            }
        }
        .onChange(of: importSelection) { 
            Task { await importFromLibrary() } 
        }
    }

    func importFromLibrary() async {
        guard await PhotoStore.requestAuthorization() else { return }
        for item in importSelection {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                // Save to Photos to get a PHAsset id (and keep creation date if present)
                let id = try? await PhotoStore.saveToLibrary(ui)
                guard let localId = id, !localId.isEmpty else { continue }
                // Warn on duplicates (same localId)
                if photos.contains(where: { $0.assetLocalId == localId }) {
                    // present a light inline warning – left as is for brevity
                    continue
                }
                let date = PhotoStore.creationDate(for: localId) ?? Date()
                let pp = ProgressPhoto(journeyId: journey.id, date: date, assetLocalId: localId, isFrontCamera: true)
                ctx.insert(pp)
                if journey.coverAssetLocalId == nil { journey.coverAssetLocalId = localId }
            }
        }
        importSelection = []
    }
}

struct PhotoTile: View {
    let localId: String
    let date: Date
    @State private var img: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.18))
            if let ui = img {
                Image(uiImage: ui).resizable().scaledToFill().clipped()
            }
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.bold())
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(6)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task { img = await PhotoStore.fetchUIImage(localId: localId, targetSize: CGSize(width: 320, height: 320)) }
    }
}
