//
//  SideMenuTVC.swift
//  SideMenuProto
//
//  Created by Eric Turner
//  Copyright © 2017 Silent Circle, Inc. All rights reserved.
//

import UIKit


class SideMenuTVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    let VIBE_CELL_ID = "VIBE_CELL_ID"
    let kMenuPlistName = "SideMenu"
    let kBuildInfoName = "BuildInfo"
    let kBuildInfoReleaseTitle = "Silent Phone"
    let kHideSpeak = NSLocalizedString("hide", comment: "hide")
    let kShowSpeak = NSLocalizedString("show", comment: "show")
    let kBuildInfoSpeak = NSLocalizedString("build info details", comment: "build info details")
    
    var datasource = [[String:AnyObject]]()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: SCSProfileHeaderView!
    @IBOutlet weak var btBuildInfo:    UIButton!
    @IBOutlet weak var lbBuildVersion: UILabel!
    @IBOutlet weak var lbBuildBranch:  UILabel!
    @IBOutlet weak var lbBuildSubmods: UILabel!
    @IBOutlet var buildInfoHeightConstraint: NSLayoutConstraint!
    var buildInfoInitialHeight = CGFloat(0.0)
    var isDebugBuild: Bool {
        get {
           return SCFileManager .isDebugBuild();
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        datasource = SCFileManager.object(fromMainBundle: kMenuPlistName, type: "plist", error: nil) as! [[String:AnyObject]]
        setupBuildInfo()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSCSPSideMenuWillAppear), object: self, userInfo: nil)
        
        // Update header view status
        headerView.prepareToShow()
        
        updateBuildInfoViewAccessibility()

        if let ip = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: ip, animated: true)
        }
        
        // this will be non-nil if a blur effect is applied
        if tableView.backgroundView == nil {
            print("Side-menu tableView.backgroundView is NIL unexpectedly")
        }        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSCSPSideMenuDidAppear), object: self, userInfo: nil)
        
        if (headerView.accountIsOnline == false) {
            headerView.updateUserStatus()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSCSPSideMenuWillDisappear), object: self, userInfo: nil)
        
        headerView.stopShowing()
        if (buildInfoOpen()) {
            toggleShowBuildDetails()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSCSPSideMenuDidDisappear), object: self, userInfo: nil)
    }
    
    //MARK: - Build Info
    func setupBuildInfo() {
        // Store initial (collapsed) height
        buildInfoInitialHeight = buildInfoHeightConstraint.constant
        
        // clear potential IB string
        lbBuildVersion.text = "Silent Phone (build N/A)"
        lbBuildBranch.text  = nil; 
        lbBuildSubmods.text = nil;
        
        if (isDebugBuild) {
            if let info = (SCFileManager.debugBuildDict()) {
                
                let count = info[kCurrent_branch_count] as? String ?? "0"
                
                if var ver = info[kApp_version] as? String {
                    ver = ver + " (" + count + ")"                    
                    lbBuildVersion.text = ver
                    lbBuildVersion.accessibilityLabel = NSLocalizedString("version", comment: "build version") + " " + ver
                }
                
                if let branch = info[kCurrent_branch] as? String, let hash = info[kCurrent_short_hash] as? String { 
                    lbBuildBranch.text = branch + " " + hash
                    lbBuildBranch.accessibilityLabel = NSLocalizedString("branch", comment: "branch") + branch + " " + hash
                }
                
                var strSubs = ""
                if let arr = info[kSubmodules] as? [[String:String]] {
                    for subDict in arr {
                        strSubs += (subDict[kSubmod_short_branch] ?? "")
                        strSubs += " "  + (subDict[kSubmod_short_hash] ?? "")
                        if let details = subDict[kSubmod_branch_details] {
                            strSubs += "\n\t" + details
                        }
                        // next submod line
                        if subDict != arr.last! {
                            strSubs += "\n"
                        }
                    }
                    lbBuildSubmods.text = strSubs
                }                
            }
        } else {            
            if let info = SCFileManager.releaseBuildDict() {
                
                let count = info[kBuild_count] as? String ?? "0"
                
                if var ver = info[kApp_version] as? String {
                    ver = "v" + ver + " (" + count + ")"
                    
                    // Swap labels for release build:
                    // Set title on upper label and
                    // ver/build string on lower label (not hidden label)
                    lbBuildVersion.text = kBuildInfoReleaseTitle
                    lbBuildBranch.text = ver
                    lbBuildBranch.accessibilityLabel = NSLocalizedString("version", comment: "build version") + " " + ver
                }
            }
        }        
    }
    
    @IBAction func toggleShowBuildDetails() {
        if ( !isDebugBuild ) {
            return
        }
        
        let height = (buildInfoOpen()) ? buildInfoInitialHeight : view.frame.height * 0.4
        UIView.animate(withDuration: 0.3, animations: {
            self.buildInfoHeightConstraint.constant = height
        }, completion: {
            (value: Bool) in
            self.updateBuildInfoViewAccessibility()
        })
    }
    
    func updateBuildInfoViewAccessibility() {
        let speak = (buildInfoOpen() ? kHideSpeak : kShowSpeak) + " " + kBuildInfoSpeak
        btBuildInfo.accessibilityLabel = speak
    }
    
    func buildInfoOpen() -> Bool {
        return (buildInfoHeightConstraint.constant != buildInfoInitialHeight)
    }
    
    
    //MARK: - TableView DataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let secDict = datasource[section]
        return secDict["section_title"] as! String?
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let secDict = datasource[section] 
        return secDict["items"]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VIBE_CELL_ID, for: indexPath)
        let itemDict = dataAtIndexPath(indexPath)
        cell.textLabel?.text = itemDict["title"] as! String?
        cell.detailTextLabel?.text = itemDict["detail_title"] as? String ?? ""
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (buildInfoOpen()) {
            toggleShowBuildDetails()
        }
        
        let itemDict = dataAtIndexPath(indexPath)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSCSideMenuSelectionNotification), object: self, userInfo: itemDict)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //MARK: - TableView Utilities
    fileprivate func dataAtIndexPath(_ ip: IndexPath) -> [String:AnyObject] {
        let secDict = datasource[ip.section] as [String:AnyObject]
        let secItems = secDict["items"] as! [[String:AnyObject]]
        return secItems[ip.row] 
    }
    
    fileprivate func presentViewController(name: String) {
        let sb = UIStoryboard.init(name: "Main", bundle: nil)
        self.navigationController?.pushViewController(sb.instantiateViewController(withIdentifier: name), animated: true)
    }

}
