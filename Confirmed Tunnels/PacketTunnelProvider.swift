//
//  PacketTunnelProvider.swift
//  ConfirmedTunnel
//
//  Copyright © 2018 Confirmed, Inc.. All rights reserved.
//

import NetworkExtension
import NEKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    func setupRules() -> Array<String> {
        
        let defaults = UserDefaults(suiteName: "group.com.confirmed.tunnelsMac")!
        var domains = defaults.dictionary(forKey:"whitelisted_domains") as? Dictionary<String, Any>
        
        if domains == nil {
            domains = Dictionary()
        }
        
        defaults.set(domains, forKey: "whitelisted_domains")
        defaults.synchronize()
        
        var userDomains = defaults.dictionary(forKey:"whitelisted_domains_user") as? Dictionary<String, Any>
        
        if userDomains == nil {
            userDomains = Dictionary()
        }
        
        defaults.set(userDomains, forKey: "whitelisted_domains_user")
        defaults.synchronize()
        
        var whitelistedDomains = Array<String>.init()
        
        for (key, value) in domains! {
            if (value as AnyObject).boolValue {
                var formattedKey = key
                if key.split(separator: ".").count == 1 {
                    formattedKey = "*." + key
                }
                whitelistedDomains.append(formattedKey)
            }
        }
        
        for (key, value) in userDomains! {
            if (value as AnyObject).boolValue {
                var formattedKey = key
                if key.split(separator: ".").count == 1 {
                    formattedKey = "*." + key
                }
                whitelistedDomains.append(key)
            }
        }
        
        return whitelistedDomains
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        if proxyServer != nil {
            proxyServer.stop()
        }
        proxyServer = nil
        
        
        var settings = NEPacketTunnelNetworkSettings.init(tunnelRemoteAddress: "127.0.0.1")
        var ipv4Settings = NEIPv4Settings.init(addresses: ["10.0.0.8"], subnetMasks: ["255.255.255.0"])
        settings.ipv4Settings = ipv4Settings;
        //settings.IPv4Settings = ipv4Settings;
        settings.mtu = NSNumber.init(value: 1500)
        
        var rules = setupRules()
        var proxySettings = NEProxySettings.init()
        proxySettings.httpEnabled = true;
        proxySettings.httpServer = NEProxyServer.init(address: proxyServerName, port: proxyServerPort)
        proxySettings.httpsEnabled = true;
        proxySettings.httpsServer = NEProxyServer.init(address: proxyServerName, port: proxyServerPort)
        proxySettings.excludeSimpleHostnames = false;
        //proxySettings.exceptionList = ["manuals.info.apple.com"];
        proxySettings.matchDomains = rules

        
        var proxyString = "if ("
        var counter = 0
        for string in rules {
            if counter > 0 {
                proxyString = proxyString + " || "
            }
            var sString = string.replacingOccurrences(of: "*.", with: "")
            proxyString = proxyString + "dnsDomainIs(host, \"" + sString + "\")"
            counter += 1
        }
        proxyString = proxyString + ")"
        
        proxyString = "function FindProxyForURL(url, host) { " + proxyString + " return \"PROXY 127.0.0.1:9090; DIRECT\"; return \"DIRECT\";}"
        
        if rules.count == 0 {
            proxySettings.proxyAutoConfigurationJavaScript = "function FindProxyForURL(url, host) { return \"DIRECT\";}"
        }
        else {
            proxySettings.proxyAutoConfigurationJavaScript = proxyString
            //proxySettings.proxyAutoConfigurationJavaScript = "function FindProxyForURL(url, host) { if (dnsDomainIs(host, \"ipchicken.com\")) return \"PROXY 127.0.0.1:9090\"; return \"DIRECT\";}"
        }
        
        proxySettings.autoProxyConfigurationEnabled = true
        //self.protocolConfiguration.disconnectOnSleep = true
        
        settings.proxySettings = proxySettings;
        RawSocketFactory.TunnelProvider = self
        
        self.setTunnelNetworkSettings(settings, completionHandler: { error in
            self.proxyServer = GCDHTTPProxyServer.init(address: IPAddress(fromString: "127.0.0.1"), port: Port(port: 9090))
            try? self.proxyServer.start()
            
            //self.interface = TUNInterface(packetFlow: self.packetFlow)
            
            completionHandler(nil)
        })
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if (interface != nil) {
            //interface.stop()
        }
        interface = nil
        DNSServer.currentServer = nil
        RawSocketFactory.TunnelProvider = nil
        
        proxyServer.stop()
        proxyServer = nil
        completionHandler()
        
        exit(EXIT_SUCCESS) //kill tunnel so we can start immediately
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    var proxyServerPort = 9090;
    var proxyServerName = "127.0.0.1";
    var interface: TUNInterface!
    var proxyServer: ProxyServer!
    
}

