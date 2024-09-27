function FindProxyForURL(url, host) {
    if (host.includes('netease.com')
            || host.includes('moyis.163.com')
            || host.includes('meety.my')) {
        return "PROXY 10.221.65.133:8899; DIRECT";
    }

    return "DIRECT";
}
