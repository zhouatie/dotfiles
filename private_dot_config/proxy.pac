function FindProxyForURL(url, host) {
    if (host.includes('netease.com')
            || host.includes('moyis.163.com')
            || host.includes('meety.my')) {
        return "PROXY 10.221.72.69:8899; DIRECT";
    }

    return "DIRECT";
}
