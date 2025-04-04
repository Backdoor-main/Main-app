//
//  TerminalSettingsViewController.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

class TerminalSettingsViewController: UITableViewController {
    
    private enum SettingSection: Int, CaseIterable {
        case serverSettings
        case terminalSettings
        case dangerZone
    }
    
    private enum ServerSetting: Int, CaseIterable {
        case serverURL
        case apiKey
    }
    
    private enum TerminalSetting: Int, CaseIterable {
        case fontSize
        case colorTheme
        case clearHistory
    }
    
    private enum DangerZoneSetting: Int, CaseIterable {
        case endSession
    }
    
    private let logger = Logger.shared
    private let defaults = UserDefaults.standard
    
    // Default settings
    private var serverURL: String {
        get { return defaults.string(forKey: "terminal_server_url") ?? "https://backdoor-backend.onrender.com" }
        set { defaults.set(newValue, forKey: "terminal_server_url") }
    }
    
    private var apiKey: String {
        get { return defaults.string(forKey: "terminal_api_key") ?? "your-api-key-here" }
        set { defaults.set(newValue, forKey: "terminal_api_key") }
    }
    
    private var fontSize: Int {
        get { return defaults.integer(forKey: "terminal_font_size") }
        set { defaults.set(newValue, forKey: "terminal_font_size") }
    }
    
    private var colorTheme: Int {
        get { return defaults.integer(forKey: "terminal_color_theme") }
        set { defaults.set(newValue, forKey: "terminal_color_theme") }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the table view
        title = "Terminal Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ValueCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActionCell")
        
        // Set initial default values if needed
        if fontSize == 0 {
            fontSize = 14 // Default font size
        }
        
        logger.log("Terminal settings view controller loaded", category: .ui, type: .info)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SettingSection.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingSection = SettingSection(rawValue: section) else { return 0 }
        
        switch settingSection {
        case .serverSettings:
            return ServerSetting.allCases.count
        case .terminalSettings:
            return TerminalSetting.allCases.count
        case .dangerZone:
            return DangerZoneSetting.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let settingSection = SettingSection(rawValue: section) else { return nil }
        
        switch settingSection {
        case .serverSettings:
            return "Server Configuration"
        case .terminalSettings:
            return "Terminal Preferences"
        case .dangerZone:
            return "Danger Zone"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingSection(rawValue: indexPath.section) else {
            return tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        switch section {
        case .serverSettings:
            return serverSettingsCell(for: indexPath)
        case .terminalSettings:
            return terminalSettingsCell(for: indexPath)
        case .dangerZone:
            return dangerZoneCell(for: indexPath)
        }
    }
    
    private func serverSettingsCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath)
        guard let setting = ServerSetting(rawValue: indexPath.row) else { return cell }
        
        switch setting {
        case .serverURL:
            cell.textLabel?.text = "Server URL"
            cell.detailTextLabel?.text = serverURL
            cell.accessoryType = .disclosureIndicator
        case .apiKey:
            cell.textLabel?.text = "API Key"
            cell.detailTextLabel?.text = "••••••••••••" // Mask the actual key
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    private func terminalSettingsCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell", for: indexPath)
        guard let setting = TerminalSetting(rawValue: indexPath.row) else { return cell }
        
        switch setting {
        case .fontSize:
            cell.textLabel?.text = "Font Size"
            cell.detailTextLabel?.text = "\(fontSize)pt"
            cell.accessoryType = .disclosureIndicator
        case .colorTheme:
            cell.textLabel?.text = "Color Theme"
            let themes = ["Default", "Light", "Dark", "Solarized"]
            cell.detailTextLabel?.text = themes[min(colorTheme, themes.count - 1)]
            cell.accessoryType = .disclosureIndicator
        case .clearHistory:
            cell.textLabel?.text = "Clear Command History"
            cell.textLabel?.textColor = .systemRed
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    private func dangerZoneCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath)
        guard let setting = DangerZoneSetting(rawValue: indexPath.row) else { return cell }
        
        switch setting {
        case .endSession:
            cell.textLabel?.text = "End Current Session"
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.textAlignment = .center
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = SettingSection(rawValue: indexPath.section) else { return }
        
        switch section {
        case .serverSettings:
            handleServerSettingTap(indexPath.row)
        case .terminalSettings:
            handleTerminalSettingTap(indexPath.row)
        case .dangerZone:
            handleDangerZoneTap(indexPath.row)
        }
    }
    
    private func handleServerSettingTap(_ row: Int) {
        guard let setting = ServerSetting(rawValue: row) else { return }
        
        switch setting {
        case .serverURL:
            promptForServerURL()
        case .apiKey:
            promptForAPIKey()
        }
    }
    
    private func handleTerminalSettingTap(_ row: Int) {
        guard let setting = TerminalSetting(rawValue: row) else { return }
        
        switch setting {
        case .fontSize:
            showFontSizePicker()
        case .colorTheme:
            showColorThemePicker()
        case .clearHistory:
            confirmClearHistory()
        }
    }
    
    private func handleDangerZoneTap(_ row: Int) {
        guard let setting = DangerZoneSetting(rawValue: row) else { return }
        
        switch setting {
        case .endSession:
            confirmEndSession()
        }
    }
    
    // MARK: - Settings Handlers
    
    private func promptForServerURL() {
        let alert = UIAlertController(title: "Server URL", message: "Enter the terminal server URL", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = self.serverURL
            textField.placeholder = "https://example.com"
            textField.keyboardType = .URL
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let url = alert.textFields?.first?.text, !url.isEmpty {
                self.serverURL = url
                self.tableView.reloadData()
                self.logger.log("Updated terminal server URL", category: .settings, type: .info)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func promptForAPIKey() {
        let alert = UIAlertController(title: "API Key", message: "Enter your API key for the terminal server", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = self.apiKey
            textField.placeholder = "your-api-key"
            textField.isSecureTextEntry = true
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let key = alert.textFields?.first?.text, !key.isEmpty {
                self.apiKey = key
                self.tableView.reloadData()
                self.logger.log("Updated terminal API key", category: .settings, type: .info)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showFontSizePicker() {
        let fontSizes = [10, 12, 14, 16, 18, 20, 24]
        let alert = UIAlertController(title: "Font Size", message: nil, preferredStyle: .actionSheet)
        
        for size in fontSizes {
            let action = UIAlertAction(title: "\(size)pt", style: .default) { _ in
                self.fontSize = size
                self.tableView.reloadData()
                self.logger.log("Updated terminal font size to \(size)pt", category: .settings, type: .info)
            }
            if size == self.fontSize {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = tableView.rectForRow(at: IndexPath(row: TerminalSetting.fontSize.rawValue, section: SettingSection.terminalSettings.rawValue))
        }
        
        present(alert, animated: true)
    }
    
    private func showColorThemePicker() {
        let themes = ["Default", "Light", "Dark", "Solarized"]
        let alert = UIAlertController(title: "Color Theme", message: nil, preferredStyle: .actionSheet)
        
        for (index, theme) in themes.enumerated() {
            let action = UIAlertAction(title: theme, style: .default) { _ in
                self.colorTheme = index
                self.tableView.reloadData()
                self.logger.log("Updated terminal color theme to \(theme)", category: .settings, type: .info)
            }
            if index == self.colorTheme {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = tableView
            popoverController.sourceRect = tableView.rectForRow(at: IndexPath(row: TerminalSetting.colorTheme.rawValue, section: SettingSection.terminalSettings.rawValue))
        }
        
        present(alert, animated: true)
    }
    
    private func confirmClearHistory() {
        let alert = UIAlertController(
            title: "Clear Command History",
            message: "Are you sure you want to clear your terminal command history? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            let history = CommandHistory()
            history.clearHistory()
            history.saveHistory()
            
            self.logger.log("Cleared terminal command history", category: .settings, type: .info)
            
            let successAlert = UIAlertController(
                title: "History Cleared",
                message: "Your terminal command history has been cleared.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func confirmEndSession() {
        let alert = UIAlertController(
            title: "End Current Session",
            message: "Are you sure you want to end your current terminal session?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Session", style: .destructive) { _ in
            TerminalService.shared.endSession { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.logger.log("Terminal session ended successfully", category: .settings, type: .info)
                        let successAlert = UIAlertController(
                            title: "Session Ended",
                            message: "Your terminal session has been terminated successfully.",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(successAlert, animated: true)
                        
                    case .failure(let error):
                        self.logger.log("Failed to end terminal session: \(error.localizedDescription)", category: .settings, type: .error)
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to end session: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}
