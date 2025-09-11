import SwiftUI
import SwiftData

struct CompareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var selectedJourney: Journey?
    @State private var mode: Mode = .parallel
    @State private var left: ProgressPhoto?
    @State private var right: ProgressPhoto?
    @EnvironmentObject private var themeManager: ThemeManager

    enum Mode: String, CaseIterable { case parallel = "Parallel", slider = "Slider" }

    var body: some View {
        ZStack {
            // Force dark background
            Color(red: 30/255, green: 32/255, blue: 35/255)
                .ignoresSafeArea()
            
            VStack {
                Menu {
                    ForEach(journeys) { j in Button(j.name) { selectedJourney = j } }
                } label: {
                    Label(selectedJourney?.name ?? "Select Journey", systemImage: "rectangle.stack")
                        .foregroundColor(.white)
                        .padding(10).background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 12)

            Picker("", selection: $mode) {
                Text("Parallel").tag(Mode.parallel)
                Text("Slider").tag(Mode.slider)
            }
            .pickerStyle(.segmented)
            .padding()

            if let j = selectedJourney {
                ComparePicker(journey: j, left: $left, right: $right)
                if let l = left, let r = right {
                    CompareCanvas(left: l, right: r, mode: mode)
                        .padding()
                } else {
                    Text("Pick two photos").foregroundColor(.white).padding()
                }
            } else {
                Text("Select a journey").foregroundColor(.white).padding()
            }
            Spacer()
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct ComparePicker: View {
    let journey: Journey
    @Binding var left: ProgressPhoto?
    @Binding var right: ProgressPhoto?
    @Query private var photos: [ProgressPhoto]

    init(journey: Journey, left: Binding<ProgressPhoto?>, right: Binding<ProgressPhoto?>) {
        self.journey = journey
        _left = left; _right = right
        let journeyId = journey.id
        _photos = Query(filter: #Predicate<ProgressPhoto> { $0.journeyId == journeyId },
                        sort: \ProgressPhoto.date, order: .forward)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { p in
                    Thumb(localId: p.assetLocalId)
                        .overlay(alignment: .topLeading) { if p.id == left?.id { tag("L") } }
                        .overlay(alignment: .topTrailing) { if p.id == right?.id { tag("R") } }
                        .onTapGesture {
                            if left == nil { left = p }
                            else if right == nil { right = p }
                            else { left = p; right = nil }
                        }
                }
            }.padding(.horizontal, 12)
        }
    }
    func tag(_ s: String) -> some View {
        Text(s).font(.caption2.bold())
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(6)
    }
}

struct Thumb: View {
    let localId: String
    @State private var img: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.2))
            if let ui = img { Image(uiImage: ui).resizable().scaledToFill().clipped() }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { img = await PhotoStore.fetchUIImage(localId: localId, targetSize: CGSize(width: 200, height: 200)) }
    }
}

struct CompareCanvas: View {
    let left: ProgressPhoto
    let right: ProgressPhoto
    let mode: CompareView.Mode

    @State private var leftImg: UIImage?
    @State private var rightImg: UIImage?
    @State private var sliderX: CGFloat = 0.5

    var body: some View {
        ZStack {
            if let l = leftImg, let r = rightImg {
                switch mode {
                case .parallel:
                    HStack(spacing: 8) {
                        Image(uiImage: l).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                        Image(uiImage: r).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                case .slider:
                    GeometryReader { geo in
                        let w = geo.size.width
                        let cut = w * sliderX
                        Image(uiImage: l).resizable().scaledToFit()
                        Image(uiImage: r).resizable().scaledToFit()
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: cut).offset(x: -w/2)
                            }
                        Rectangle().fill(.white).frame(width: 2).position(x: cut, y: geo.size.height/2)
                    }
                    .gesture(DragGesture().onChanged { v in
                        sliderX = min(0.98, max(0.02, v.location.x / max(1, v.startLocation.x + v.translation.width)))
                    })
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else { ProgressView().frame(height: 420) }
        }
        .task {
            leftImg = await PhotoStore.fetchUIImage(localId: left.assetLocalId)
            rightImg = await PhotoStore.fetchUIImage(localId: right.assetLocalId)
        }
    }
}
