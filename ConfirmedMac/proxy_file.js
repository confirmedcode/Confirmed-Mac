function FindProxyForURL(url, host) {
 
 
    return "DIRECT";
// DEFAULT RULE: All other traffic, use below proxies, in fail-over order.
    //return "PROXY 127.0.0.1:9090";
 
}
