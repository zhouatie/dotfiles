function FindProxyForURL(url, host) {
    if (host.includes('netease.com')
            || host.includes('moyis.163.com')
            || host.includes('meety.my')) {
        return "PROXY 127.0.0.1:8899; DIRECT";
    }

    return "DIRECT";
}
