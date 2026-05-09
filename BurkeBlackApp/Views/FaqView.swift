import SwiftUI


private struct FaqItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct FaqSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [FaqItem]
}

private let faqSections = [
    FaqSection(title: "About Burke", items: [
        FaqItem(question: "Who is BurkeBlack?", answer: "Burke is an avid gamer and nerd who loves comic books, sci-fi and fantasy movies, everything gaming, and making people laugh."),
        FaqItem(question: "Business Contact Email", answer: "burkeblack@fenixdown.co"),
        FaqItem(question: "When is Burke's birthday?", answer: "July 7th, 1979"),
        FaqItem(question: "Where does Burke live?", answer: "Indiana, USA"),
        FaqItem(question: "Who does Burke live with?", answer: "Burke currently lives with his father, better known as Dadmiral (Radlit1), and his mother."),
        FaqItem(question: "What does Burke do for work?", answer: "Burke is a full-time streamer (and pirate)."),
        FaqItem(question: "Is Burke single, taken or married?", answer: "Burke is married to the sea."),
        FaqItem(question: "Is Burke standing while gaming?", answer: "Yes, Burke does stand while gaming. He stands for 4 hours, sits for 2 hours, and then stands for another 4 hours. He uses a fatigue pad to avoid any leg and back pains. He uses the UPLIFT V2 Standing Desk (72x30 inch)"),
        FaqItem(question: "Where did Burke get that hat?", answer: "To get your own infamous pirate hat, visit the Swedish clothing company Longnose Leather"),
        FaqItem(question: "Where did Burke get that mug?", answer: "To get your own stainless steel handcrafted mug, search Amazon for Design Toscano JQ8967 Skullduggery Mug Beer"),
    ]),
    FaqSection(title: "About The Crew", items: [
        FaqItem(question: "Who are the Pirates?", answer: "The Pirates are YOU, the crew of our mighty ship, The Dirty Skull. The community evolved from \"The Black Crew\" created during GTA V's launch, adopting pirate-themed rank titles like Corsairs and Buccaneers."),
        FaqItem(question: "What is The Dirty Skull?", answer: "The Dirty Skull is the name of our mighty ship, on the seas of Twitch. Members can join via the Discord community."),
        FaqItem(question: "Who is The Late Shift?", answer: "The Late Shift is a team of streamers, including BurkeBlack. Team members include CletusBueford, CrReaM, and GassyMexican. It represents both the streaming team and their combined communities."),
        FaqItem(question: "Who are the administrators?", answer: "Head Moderator: jstubbles manages moderators. Community Manager: BleuBelladonna handles organization. Tech Manager: swiftyspiffy oversees the Kraken Bot, website, and extension."),
        FaqItem(question: "Who are the moderators?", answer: "The moderation team includes jstubbles, BleuBelladonna, swiftyspiffy, A_p_p_l_e_s, Acebravo69, Xorshasia, and many more dedicated crew members."),
    ]),
    FaqSection(title: "About The Stream", items: [
        FaqItem(question: "What is Burke's streaming schedule?", answer: "Burke streams Monday through to Saturday, starting at 10PM EST and ending at 8AM EST. Sunday is Burke's shore leave. Times and dates are subject to change."),
        FaqItem(question: "When did Burke start streaming?", answer: "June 29th, 2013"),
        FaqItem(question: "When did Burke get his sub button?", answer: "July 7th, 2014"),
        FaqItem(question: "What type of games does Burke usually stream?", answer: "Burke is a variety streamer, so he will play just about any game out there."),
        FaqItem(question: "Who made Burke's art?", answer: "Multiple artists contributed, including Casy Nuf (emotes), JouJouet (extension backgrounds), Jstubbles (overlays, animations, alerts), Lorgarn (scene elements), SenzuArts/SaucyArts (animated emotes), Shticky (emotes), Twosenseless (badges, headers, alerts), and Venalis (film work)."),
        FaqItem(question: "Who made Burke's website?", answer: "The website was put together by Bennyfits, with additional items added by swiftyspiffy and BleuBelladonna."),
        FaqItem(question: "Who made Burke's custom bot, The_Kraken_Bot?", answer: "swiftyspiffy is the mastermind behind the channel bot."),
    ]),
    FaqSection(title: "Burke's Booty Extension", items: [
        FaqItem(question: "What are Extensions?", answer: "Extensions are programmable, interactive overlays and panels, which help broadcasters interact with viewers through features like heat maps, real-time overlays, mini-games, and leaderboards."),
        FaqItem(question: "What is Burke's Booty Extension?", answer: "An interactive panel extension developed by swiftyspiffy for twitch.tv/burkeblack. Features include claiming/entering giveaways, purchasing soundbyte credits with bits, redeeming prizes, sending soundbytes, submitting feedback, and viewing doubloons/soundbyte credits."),
        FaqItem(question: "How do I access Burke's Booty Extension?", answer: "Located in the panel below the video player. Grant permissions by clicking the \"Grant Permissions\" icon (desktop) or clicking the \"BB\" logo and authenticating (mobile)."),
    ]),
    FaqSection(title: "Subscription", items: [
        FaqItem(question: "Pirates (Tier 1) - $4.99/month", answer: "60 Channel Emotes + 5 Animated Emotes, ad-free viewing, and access to game servers. Resub benefits include 50 Doubloons and 5 Soundbyte Credits."),
        FaqItem(question: "Swashbucklers (Tier 2) - $9.99/month", answer: "Includes all Tier 1 benefits plus 5 Exclusive Tier 2 Emotes and higher multipliers."),
        FaqItem(question: "Corsairs (Tier 3) - $24.99/month", answer: "Premium tier with 5 Exclusive Tier 3 Emotes and 2x Channel Points multiplier."),
        FaqItem(question: "Prime Gaming - Free with Amazon Prime", answer: "Same base benefits as Tier 1 with additional gaming benefits."),
    ]),
    FaqSection(title: "Giveaways", items: [
        FaqItem(question: "How do I submit a giveaway?", answer: "Access Burke's Booty Extension, click the present icon for \"Giveaway Submission Form,\" and complete the form with details. A moderator must manually run it afterward. Desktop only."),
        FaqItem(question: "How do I enter a giveaway?", answer: "When a giveaway is live, locate Burke's Booty Extension and click the \"Enter Giveaway\" button to participate."),
        FaqItem(question: "How do I claim a giveaway?", answer: "After a giveaway ends, locate Burke's Booty Extension and click the \"Claim\" button. Only the winner can access this button."),
        FaqItem(question: "How do I redeem a giveaway?", answer: "Click the trophy icon (\"Giveaway Wins\"), find your most recent win, and copy the key/code/link to redeem it elsewhere."),
    ]),
    FaqSection(title: "Doubloons", items: [
        FaqItem(question: "What are Doubloons?", answer: "Doubloons are our custom currency system, used to reward viewers for watching the stream and subscribing."),
        FaqItem(question: "What are Doubloons for?", answer: "Doubloon amounts are used as entry requirements to gain access to community game servers and large giveaways."),
        FaqItem(question: "How do I earn more doubloons?", answer: "Earn doubloons through various stream activities including watching the stream and subscribing. Rates are subject to change."),
    ]),
    FaqSection(title: "Soundbytes", items: [
        FaqItem(question: "What are Soundbytes?", answer: "A soundbyte is a short clip of speech or music extracted from a longer piece of audio, often used to encourage funny moments, dancing and jump scares."),
        FaqItem(question: "How do I send a soundbyte?", answer: "Click the music note icon on Burke's Booty Extension. Search or select a soundbyte, optionally listen, then click \"Send.\""),
        FaqItem(question: "What are Soundbyte Credits?", answer: "Soundbyte Credits are the currency used to send a soundbyte. Earn through stream activities or purchase with bits."),
    ]),
    FaqSection(title: "Channel Points", items: [
        FaqItem(question: "What are Channel Points?", answer: "Channel Points is a customizable points program that lets streamers reward members of their community with perks."),
        FaqItem(question: "What are Gold Coins?", answer: "Gold Coins is the custom name BurkeBlack uses for the Channel Points system."),
        FaqItem(question: "How do I earn more gold coins?", answer: "Earn Channel Points through various stream activities including watching, chatting, and follow streaks."),
    ]),
]

// MARK: - FAQ View

struct FaqView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(faqSections) { section in
                FaqSectionView(section: section)
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appLog("FAQ: appeared") }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
    }
}

// MARK: - FAQ Section

private struct FaqSectionView: View {
    let section: FaqSection
    @State private var expanded = false

    var body: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(section.title)
                        .font(PirateTheme.font(size: 18))
                        .foregroundStyle(PirateTheme.accentColor)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.5))
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(section.items) { item in
                    FaqItemView(item: item)
                }
            }
        }
    }
}

// MARK: - FAQ Item

private struct FaqItemView: View {
    let item: FaqItem
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text("\u{2693}")
                        .font(.caption)
                        .foregroundStyle(PirateTheme.accentColor.opacity(0.6))
                    Text(item.question)
                        .font(PirateTheme.font(size: 15))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                if expanded {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(.leading, 24)
                        .padding(.top, 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
