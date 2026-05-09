import SwiftUI


// MARK: - Data Models

private struct Sponsor: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: String
    let color: Color
}

private struct StudioItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String?
    let purchaseUrl: String

    init(name: String, description: String, imageName: String? = nil, purchaseUrl: String) {
        self.name = name
        self.description = description
        self.imageName = imageName
        self.purchaseUrl = purchaseUrl
    }
}

private struct StudioSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [StudioItem]
}

// MARK: - Data

private let sponsors = [
    Sponsor(name: "ViewSonic", description: "ViewSonic is a leading global provider of visual display products and solutions, dedicated to delivering innovative and reliable displays for gaming, entertainment, and professional use.", url: "https://www.viewsonic.com", color: Color(red: 0.1, green: 0.14, blue: 0.49)),
    Sponsor(name: "Elgato", description: "Elgato is a world-leading provider of audiovisual technology, synonymous with quality and performance, for content creators on all video sharing platforms.", url: "https://www.elgato.com", color: Color(red: 0.11, green: 0.16, blue: 0.22)),
    Sponsor(name: "Origin PC", description: "ORIGIN PC builds custom, high-performance gaming desktops, laptops, and workstations designed to deliver the ultimate computing experience.", url: "https://www.originpc.com", color: Color(red: 0.55, green: 0.1, blue: 0.1)),
    Sponsor(name: "Wyrmwood", description: "Wyrmwood crafts premium quality gaming furniture and accessories, designed by gamers for gamers, using the finest hardwoods and materials.", url: "https://www.wyrmwoodgaming.com", color: Color(red: 0.36, green: 0.25, blue: 0.22)),
]

private let studioSections = [
    StudioSection(title: "Lighting", items: [
        StudioItem(name: "Aputure LS 60d Focusing LED", description: "Battery-powerable daylight-balanced focusing LED with 15-45 degree spot-flood beam angle.", imageName: "equip_aputure_ls_60d", purchaseUrl: "https://amzn.to/3oPc5ef"),
        StudioItem(name: "Aputure LS 60x Bi-Color LED", description: "Battery-powerable bi-color focusing LED with custom aspherical optics.", imageName: "equip_aputure_ls_60x", purchaseUrl: "https://amzn.to/3s0GYyj"),
        StudioItem(name: "Aputure Lantern Softbox", description: "26-inch spherical design spreading light in all directions with a 270 degree beam angle.", imageName: "equip_aputure_lantern", purchaseUrl: "https://amzn.to/3rZocHr"),
        StudioItem(name: "Elgato Key Light", description: "160 premium OSRAM LEDs outputting 2800 lumens for extra-bright illumination.", imageName: "equip_elgato_key_light", purchaseUrl: "https://amzn.to/30kpXDE"),
    ]),
    StudioSection(title: "Cameras", items: [
        StudioItem(name: "Sony Alpha A6000", description: "0.06s auto-focus, BIONZ X processor and 24.3MP sensor.", imageName: "equip_sony_a6000", purchaseUrl: "https://amzn.to/31SfKiz"),
        StudioItem(name: "Logitech Brio 4K Pro Webcam", description: "Captures every detail in crisp high-resolution color with up to 90 fps.", imageName: "equip_logitech_brio", purchaseUrl: "https://amzn.to/3sTe42t"),
    ]),
    StudioSection(title: "Audio", items: [
        StudioItem(name: "RODECaster Pro II", description: "The ultimate audio production solution for streamers, podcasters, and musicians.", imageName: "equip_rodecaster_pro2", purchaseUrl: "https://www.amazon.com/dp/B0BV6NK6HW"),
        StudioItem(name: "Corsair Virtuoso Wireless Headset", description: "High-fidelity audio with memory foam earpads and Slipstream Wireless.", imageName: "equip_corsair_virtuoso", purchaseUrl: "https://amzn.to/32HNJuw"),
        StudioItem(name: "Astro A10 Gaming Headset", description: "Tuned for gaming with immersive audio and precise voice communication.", imageName: "equip_astro_a10", purchaseUrl: "https://amzn.to/3LGiRec"),
        StudioItem(name: "Audio-Technica BP894cT4 Mic", description: "Head-worn condenser microphone with cardioid polar pattern.", imageName: "equip_audio_technica_bp894ct4", purchaseUrl: "https://amzn.to/3pM9IJo"),
        StudioItem(name: "Shure GLXD4 Wireless Receiver", description: "LINKFREQ Automatic Frequency Management on 2.4 GHz band.", imageName: "equip_shure_glxd4", purchaseUrl: "https://amzn.to/3zh8f0Y"),
        StudioItem(name: "Shure GLXD1 Bodypack Transmitter", description: "Ergonomic design with reversible belt clip, 16 hours continuous use.", imageName: "equip_shure_glxd1", purchaseUrl: "https://amzn.to/3Px5YXf"),
        StudioItem(name: "Klipsch ProMedia 2.1 Bluetooth", description: "Legendary ProMedia 2.1 offering exceptional sound quality.", imageName: "equip_klipsch_speaker", purchaseUrl: "https://amzn.to/3z00ZbP"),
    ]),
    StudioSection(title: "Gaming PC Specs", items: [
        StudioItem(name: "Corsair iCUE 5000x RGB Case", description: "Stunning showpiece-worthy PC with tempered glass.", imageName: "equip_corsair_5000x", purchaseUrl: "https://bit.ly/3Nyvmgn"),
        StudioItem(name: "Intel Core i9-13900KS", description: "6.0GHz max clock, 24 cores, 32 threads.", imageName: "equip_intel_i9_13900ks", purchaseUrl: "https://www.amazon.com/dp/B0BPXCRWB2"),
        StudioItem(name: "ASUS ROG MAXIMUS Z790 Hero", description: "20-stage power solution with DDR5 and PCIe 5.0.", imageName: "equip_asus_maximus_z790", purchaseUrl: "https://www.amazon.com/dp/B0BG6M53DG"),
        StudioItem(name: "Corsair 4TB MP600 PRO XT", description: "PCIe Gen4 x4 extreme data performance.", imageName: "equip_corsair_mp600", purchaseUrl: "https://www.amazon.com/dp/B09F5XC93H"),
        StudioItem(name: "NVIDIA GeForce RTX 4090", description: "The ultimate GeForce GPU.", imageName: "equip_nvidia_rtx_4090", purchaseUrl: "https://www.amazon.com/dp/B09YD4FJ5R"),
        StudioItem(name: "Corsair RM1200x SHIFT PSU", description: "Fully modular 80 PLUS Gold with side cable interface.", imageName: "equip_rm1200x_shift", purchaseUrl: "https://www.amazon.com/dp/B0BP88MYM4"),
    ]),
    StudioSection(title: "Streaming PC Specs", items: [
        StudioItem(name: "Corsair iCUE 5000x Case", description: "Mid-tower ATX with four tempered glass panels.", imageName: "equip_origin_icue", purchaseUrl: "https://amzn.to/39QXVUR"),
        StudioItem(name: "AMD Ryzen 9 5950X", description: "World's best desktop processor speed.", imageName: "equip_amd_ryzen_9", purchaseUrl: "https://amzn.to/3lESsCY"),
        StudioItem(name: "MSI MEG X570 GODLIKE", description: "Flagship 14+4+1 phase VRM for unlimited performance.", imageName: "equip_msi_meg_godlike", purchaseUrl: "https://amzn.to/3wOhmWd"),
        StudioItem(name: "GIGABYTE RTX 4070 Ti Super", description: "16GB GDDR6X with amazingly fast frame rates.", imageName: "equip_gigabyte_4070ti_super", purchaseUrl: "https://www.amazon.com/dp/B0CSK87B4R/"),
        StudioItem(name: "Elgato 4K60 Pro MK.2 Capture", description: "4K60 HDR10 capture with ultra low latency.", imageName: "equip_elgato_4k60", purchaseUrl: "https://amzn.to/3LKQ5cu"),
        StudioItem(name: "Elgato Cam Link Pro", description: "Powerful video mixer capturing four HDMI signals.", imageName: "equip_elgato_camlink", purchaseUrl: "https://amzn.to/3Nrgz3S"),
    ]),
    StudioSection(title: "Peripherals", items: [
        StudioItem(name: "ViewSonic ELITE XG270 27\"", description: "240Hz, 1ms response with vibrant IPS color.", purchaseUrl: "https://www.amazon.com/dp/B0BCXJ7XXM"),
        StudioItem(name: "Alienware AW3225QF 32\" 4K QD-OLED", description: "4K curved panel with Dolby Vision and 240Hz.", purchaseUrl: "https://www.dell.com/en-us/shop/alienware-32-4k-qd-oled-gaming-monitor-aw3225qf/apd/210-blmq/monitors-monitor-accessories"),
        StudioItem(name: "LG OLED C1 48\"", description: "Advanced gaming with NVIDIA G-SYNC.", purchaseUrl: "https://amzn.to/3MG40SD"),
        StudioItem(name: "Corsair K100 RGB Keyboard", description: "Aluminum design with AXON Hyper-Processing.", imageName: "equip_corsair_k100_rgb", purchaseUrl: "https://amzn.to/3qFH2Rz"),
        StudioItem(name: "Corsair Scimitar RGB Mouse", description: "12 mechanical side buttons, 12000 DPI optical sensor.", imageName: "equip_corsair_scimitar", purchaseUrl: "https://amzn.to/3FJKUr7"),
        StudioItem(name: "Elgato Stream Deck", description: "15 LCD keys for unlimited studio control.", imageName: "equip_elgato_stream_deck", purchaseUrl: "https://amzn.to/3qHBZQP"),
        StudioItem(name: "HTC Vive PRO 2", description: "High fidelity VR with sub-millimeter tracking.", imageName: "equip_htc_vive_pro2", purchaseUrl: "https://amzn.to/3wEyn62"),
        StudioItem(name: "Meta Quest 2", description: "Advanced VR for gaming, social, and entertainment.", imageName: "equip_meta_quest_2", purchaseUrl: "https://amzn.to/3wDfIHQ"),
    ]),
    StudioSection(title: "Furniture", items: [
        StudioItem(name: "Wyrmwood Modular Gaming Table", description: "A new benchmark for gaming tables designed for every member of your party.", imageName: "equip_wyrmwood_table", purchaseUrl: "https://wyrmwoodgaming.com/modulargamingtable/"),
        StudioItem(name: "UPLIFT v2 80\" Standing Desk", description: "Maximize comfort and productivity with thoughtfully designed furniture.", purchaseUrl: "https://www.upliftdesk.com/uplift-v2-standing-desk-v2-or-v2-commercial/"),
        StudioItem(name: "Ikea Idasen Standing Desk", description: "A sturdy desk built to outlast years of coffee and hard work.", imageName: "equip_ikea_idasen", purchaseUrl: "https://www.ikea.com/us/en/p/idasen-desk-sit-stand-black-dark-gray-s79280998/"),
        StudioItem(name: "Herman Miller Aeron Gaming Edition", description: "The iconic Aeron customized for gamers' specific needs.", imageName: "equip_herman_aeron", purchaseUrl: "https://amzn.to/3yUZfQX"),
    ]),
    StudioSection(title: "Pirate Wall", items: [
        StudioItem(name: "Godzilla (Godzilla vs. Kong)", description: "", imageName: "equip_godzilla_sideshow", purchaseUrl: "https://www.sideshow.com/collectibles/godzilla-vs-kong-godzilla-prime-1-studio-908118"),
        StudioItem(name: "Assassin's Creed Edward Kenway", description: "", imageName: "equip_ac_edward_kenway", purchaseUrl: "https://www.amazon.com/dp/B09GRTV9JY"),
        StudioItem(name: "Decorative Gothic Dragon Skull", description: "", imageName: "equip_dragon_skull", purchaseUrl: "https://amzn.to/3yVqaw6"),
        StudioItem(name: "Melting Gold Skull", description: "", imageName: "equip_melting_skull", purchaseUrl: "https://jackofthedust.com/products/melting-gold-skull"),
        StudioItem(name: "Pete the Undead Pirate Parrot", description: "", imageName: "equip_pete_parrot", purchaseUrl: "https://amzn.to/3wEZZqC"),
        StudioItem(name: "Robert Louis Stevenson: Seven Novels", description: "", imageName: "equip_rls_novels", purchaseUrl: "https://www.amazon.com/dp/160710315X"),
        StudioItem(name: "Wooden Beer Mug", description: "", imageName: "equip_wooden_mug", purchaseUrl: "https://www.etsy.com/listing/513473306"),
        StudioItem(name: "STAR WARS Star Destroyer", description: "", imageName: "equip_star_destroyer", purchaseUrl: "https://amzn.to/3GdTbVt"),
    ]),
    StudioSection(title: "Miscellaneous", items: [
        StudioItem(name: "PSY Acoustics Wall Panels", description: "Handmade studio grade acoustic panels with customizable artwork.", imageName: "equip_acoustic_panels", purchaseUrl: "https://psyacoustics.com/"),
        StudioItem(name: "Elgato Master Mount (L)", description: "Modular rigging for camera, light, or phone.", imageName: "equip_elgato_master_mount", purchaseUrl: "https://amzn.to/38vKlpr"),
        StudioItem(name: "Nintendo Switch", description: "Single and multiplayer thrills at home.", imageName: "equip_nintendo_switch", purchaseUrl: "https://www.amazon.com/dp/B07VGRJDFY"),
        StudioItem(name: "Playstation 5", description: "Ultra-high speed SSD with 3D Audio.", imageName: "equip_playstation_5", purchaseUrl: "https://www.amazon.com/dp/B09DFCB66S"),
        StudioItem(name: "Xbox Series X", description: "The fastest, most powerful Xbox ever.", imageName: "equip_xbox_series_x", purchaseUrl: "https://www.amazon.com/dp/B08H75RTZ8"),
    ]),
]

private let galleryPhotos: [(label: String, imageName: String)] = [
    ("Captain's Quarters", "studio_captains_quarters"),
    ("Streaming Space", "studio_streaming_space"),
    ("Lounge", "studio_lounge"),
    ("Games & Cabinets", "studio_games_cabinets"),
    ("Games & Cabinets", "studio_games_cabinets_alt"),
    ("Tabletop Area", "studio_tabletop_area"),
]

// MARK: - Studio View

struct StudioView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        List {
            sponsorsSection
            studioTourSection
            gallerySection
            equipmentSections
        }
        .listStyle(.plain)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "helm")
                        .font(.body)
                        .foregroundStyle(PirateTheme.accentColor)
                    Text("The Captain\u{2019}s Studio")
                        .font(PirateTheme.font(size: 20))
                        .foregroundStyle(PirateTheme.accentColor)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoIndex != nil },
            set: { if !$0 { selectedPhotoIndex = nil } }
        )) {
            GalleryPagerView(
                photos: galleryPhotos,
                initialIndex: selectedPhotoIndex ?? 0,
                onDismiss: { selectedPhotoIndex = nil }
            )
        }
    }

    // MARK: - Sponsors

    private var sponsorsSection: some View {
        Section {
            Text("Sponsors")
                .font(PirateTheme.font(size: 22))
                .foregroundStyle(PirateTheme.accentColor)
                .listRowBackground(Color.clear)

            ForEach(sponsors) { sponsor in
                SponsorCardView(sponsor: sponsor)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Studio Tour

    private var studioTourSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("Streaming in Style")
                    .font(PirateTheme.font(size: 26))
                    .foregroundStyle(.primary)

                Text("Follow Captain BurkeBlack as he gives a tour of his NEW pirate studio!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link(destination: URL(string: "https://www.youtube.com/watch?v=nZlZl131rdA")!) {
                    ZStack {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/nZlZl131rdA/hqdefault.jpg")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.red.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Gallery

    private var gallerySection: some View {
        Section {
            Text("The Captain\u{2019}s Quarters")
                .font(PirateTheme.font(size: 22))
                .foregroundStyle(PirateTheme.accentColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(galleryPhotos.enumerated()), id: \.element.imageName) { index, photo in
                        Button { selectedPhotoIndex = index } label: {
                            ZStack(alignment: .bottom) {
                                Image(photo.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 280, height: 210)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.7)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .frame(maxHeight: .infinity, alignment: .bottom)

                                Text(photo.label)
                                    .font(PirateTheme.font(size: 16))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 280, height: 210)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
        }
    }

    // MARK: - Equipment

    private var equipmentSections: some View {
        Section {
            Text("The Captain\u{2019}s Gear")
                .font(PirateTheme.font(size: 22))
                .foregroundStyle(PirateTheme.accentColor)

            ForEach(studioSections) { section in
                EquipmentSectionView(section: section)
            }
        }
    }
}

// MARK: - Equipment Section (collapsible)

private struct EquipmentSectionView: View {
    let section: StudioSection
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(section.items) { item in
                StudioItemRow(item: item)
            }
        } label: {
            Text(section.title)
                .font(PirateTheme.font(size: 18))
                .foregroundStyle(PirateTheme.accentColor)
        }
    }
}



// MARK: - Sponsor Card

private struct SponsorCardView: View {
    let sponsor: Sponsor
    @State private var expanded = false // sponsors collapsed by default

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(sponsor.name)
                        .font(PirateTheme.font(size: 20))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding(14)
                .background(sponsor.color)
                .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 10))
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sponsor.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Link(destination: URL(string: sponsor.url)!) {
                        Text("Learn more at: \(sponsor.url)")
                            .font(.caption)
                            .foregroundStyle(PirateTheme.accentColor)
                    }
                }
                .padding(14)
                .background(sponsor.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

// MARK: - Studio Item Row

private struct StudioItemRow: View {
    let item: StudioItem

    var body: some View {
        HStack(spacing: 12) {
            if let imageName = item.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }

                Link(destination: URL(string: item.purchaseUrl)!) {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.caption2)
                        Text("Find It Here!")
                            .font(PirateTheme.font(size: 13))
                    }
                    .foregroundStyle(PirateTheme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PirateTheme.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Gallery Pager (fullscreen swipeable)

private struct GalleryPagerView: View {
    let photos: [(label: String, imageName: String)]
    let initialIndex: Int
    let onDismiss: () -> Void
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.imageName) { index, photo in
                    Image(photo.imageName)
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            // Label at bottom
            VStack {
                Spacer()
                Text(photos[currentIndex].label)
                    .font(PirateTheme.font(size: 18))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 4)
                    .padding(.bottom, 40)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            appLog("Studio: view appeared")
            currentIndex = initialIndex }
    }
}
