//
//  SettingsView.swift
//  ScheduleMIPT
//
//  Created by Яков Каюмов on 20.02.2021.
//  Copyright © 2021 Admin. All rights reserved.
//

import SwiftUI
import UIKit
import UserNotifications


struct SettingsView: View {
    
    @EnvironmentObject var userInfo: UserInfo
    
    @EnvironmentObject var schedule: Schedule
    
    @ObservedObject var observableShowBreaks: ObservableBool
    
    @State var showBreaks: Bool = UserDefaults.standard.bool(forKey: SettingsView.BREAKS_KEY)
    
    @State var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: SettingsView.NOTIFICATIONS_KEY)
    
    @State private var notifyOption = UserDefaults.standard.integer(forKey: SettingsView.NOTIFY_MINUTES_KEY)
    
    // List of notification options
    var notifyOptions = StringUtils.getMinutesLabels()
    
    // Responsible for toggling alert window
    @State private var showAccessDeniedAlert = false
    
    @State private var showDeleteAlert = false
    
    @State private var showShareSheet = false
    
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>

    var body: some View {
        NavigationView {
            Form {
                
                Section(header: Text("settings_general")) {
                    // Group number picker
                    HStack {
                        NavigationLink(destination: SearchView().environmentObject(userInfo)) {
                            HStack {
                                Text("settings_group")
                                Spacer()
                                Text(userInfo.groupNumber)
                                    .foregroundColor(Color(UIColor.systemGray))
                            }
                        }
                    }
                    
                    // Break toggle
                    HStack {
                        Toggle(isOn: $showBreaks) {
                            Text("settings_breaks")
                        }.onChange(of: showBreaks) { value in
                            
                            observableShowBreaks.value = value
                            
                            UserDefaults.standard.set(value, forKey: SettingsView.BREAKS_KEY)
                        }
                    }
                    
                }
                
                Section() {
                    // Reset button
                    Button(action: {
                        self.showDeleteAlert = true
                    }) {
                        Text("settings_reset_button")
                            .foregroundColor(Color.red)
                    }.alert(isPresented: $showDeleteAlert) {
                        deleteAlert()
                    }
                    
                    // Reset text
                    Text("settings_reset_description")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.systemGray))
                }
                
                Section(header: Text("settings_notifications")) {
                    
                    // Notification toggle
                    Toggle(isOn: $notificationsEnabled) {
                        Text("settings_notifications_enabled")
                    }.onChange(of: notificationsEnabled) { value in
                        UserDefaults.standard.set(value, forKey: SettingsView.NOTIFICATIONS_KEY)
                        if value {
                            requestPermission()
                        } else {
                            NotificationUtils.cancelNotifications()
                        }
                    }.alert(isPresented: $showAccessDeniedAlert) {
                        accessDeniedAlert()
                    }
                    
                    // Minutes picker
                    Picker(selection: $notifyOption, label: Text("settings_notifications_time")) {
                        ForEach(0 ..< notifyOptions.count) {
                            Text(self.notifyOptions[$0])
                        }
                    }
                    .onChange(of: notifyOption) { value in
                        // Update preferences
                        UserDefaults.standard.set(value, forKey: SettingsView.NOTIFY_MINUTES_KEY)
                        
                        // Update notifications
                        NotificationUtils.scheduleNotifications(key: userInfo.groupNumber, schedule: schedule)
                    }.disabled(notificationsEnabled == false)
                    
                    
                    Text("settings_notifications_description")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.systemGray))
                }
                
                Section(header: Text("settings_communication")) {
                    
                    // Share button
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Text("settings_share")
                    }
                    
                    // Write to developer button
                    Button(action: {
                        if let url = URL(string: "https://vk.com/yasha_kayumov") {
                               UIApplication.shared.open(url)
                        }
                    }) {
                        Text("settings_developer")
                    }
                    
                    // Rate button
                    Button(action: {
                        if let url = URL(string: "https://www.apple.com") {
                               UIApplication.shared.open(url)
                        }
                    }) {
                        Text("settings_rate")
                    }
                }
                
                // About section
                Section(header: Text("settings_about")) {
                    let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                    
                    // Version info
                    HStack {
                        Text("settings_version")
                        Spacer()
                        Text(version)
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                    
                    // Thanks info
                    Text("settings_thanks")
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.systemGray))
                    
                }
                
            }
            .navigationBarTitle("settings_title")
            .sheet(isPresented: $showShareSheet, content: {
                let items = [NSLocalizedString("settings_share_text", comment: ""), URL(string: "https://www.apple.com")!]
                ShareSheet(activityItems: items)
            })
        }.navigationViewStyle(StackNavigationViewStyle())
        .padding(UIDevice.current.userInterfaceIdiom == .pad ? 16 : 0)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    
    func resetSchedule() {
        let app = UIApplication.shared.delegate as! AppDelegate
        let schedule = app.schedule!
        schedule.timetable = DataUtils.loadScheduleFromAssets().timetable
        app.updateTimeTable(updatedSchedule: schedule)
    }
    
    
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                NotificationUtils.scheduleNotifications(key: userInfo.groupNumber, schedule: schedule)
            } else {
                center.getNotificationSettings { settings in
                    if settings.authorizationStatus != .authorized {
                        self.notificationsEnabled = false
                        self.showAccessDeniedAlert = true
                        UserDefaults.standard.set(self.notificationsEnabled, forKey: SettingsView.NOTIFICATIONS_KEY)
                    }
                }
            }
        }
        
    }
    
    func deleteAlert() -> Alert {
        return Alert(title: Text("dialog_title"),
              message: Text("settings_reset_dialog"),
              primaryButton: .default(Text("dialog_ok_button")) {
                self.resetSchedule()
                self.mode.wrappedValue.dismiss()
            },
              secondaryButton: .default(Text("dialog_cancel_button"))
        )
    }
    
    func accessDeniedAlert() -> Alert {
        return Alert(title: Text("settings_notifications_permission_title"),
              message: Text("settings_notifications_permission_description"),
              primaryButton: .default(Text("settings_notifications_permission_ok_button")) {
                if let appSettings = NSURL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings as URL)
                }
                self.mode.wrappedValue.dismiss()
            },
              secondaryButton: .default(Text("dialog_cancel_button"))
        )
    }
    
    // MARK: Storing data
    
    static let BREAKS_KEY = "breaks_key"
    
    static let NOTIFICATIONS_KEY = "notifications_key"
    
    static let NOTIFY_MINUTES_KEY = "notify_minutes_key"
    
    static func getMinutesBefore(option: Int) -> Int {
        switch option {
            case 0: return 1
            case 1: return 5
            default: return 10
        }
    }
    
    /**
        Creating keys and setting up default parameters
     */
    static func registerDefaults() {
        UserDefaults.standard.register(
            defaults: [
                BREAKS_KEY: false,
                NOTIFICATIONS_KEY: false,
                NOTIFY_MINUTES_KEY: 1
            ]
        )
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // nothing to do here
    }
}


struct SettingsView_Previews: PreviewProvider {
    
    static let userInfo = UserInfo(groupNumber: "Б02-824")
    
    static var previews: some View {
        SettingsView(observableShowBreaks: ObservableBool(value: false))
            .environmentObject(userInfo)
            .environmentObject((UIApplication.shared.delegate as! AppDelegate).schedule)
            .environment(\.locale, .init(identifier: "ru"))
            .preferredColorScheme(.dark)
    }
}