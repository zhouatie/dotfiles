// Define main function (script entry)

function main(config, profileName) {
  // 1. 动态注入 TUN 排除内网路由，内网流量直通 VPN 虚拟网卡 (utun6)
  config["tun"] = config["tun"] || {};
  config["tun"]["enable"] = true;
  config["tun"]["auto-route"] = true;
  config["tun"]["auto-detect-interface"] = true;
  config["tun"]["route-exclude-address"] = [
    ...new Set([
      ...(config["tun"]["route-exclude-address"] || []),
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
      "fd00:163:163::/48",
    ]),
  ];

  // 2. 将公司内网域名排除在 Fake-IP 之外，并交由系统/VPN DNS 解析
  if (config["dns"]) {
    config["dns"]["fake-ip-filter"] = [
      ...new Set([
        ...(config["dns"]["fake-ip-filter"] || []),
        "+.netease.com",
        "+.163.com",
        "+.126.net",
        "+.ydstatic.com",
        "+.youdao.com",
      ]),
    ];
    config["dns"]["nameserver-policy"] = config["dns"]["nameserver-policy"] || {};
    config["dns"]["nameserver-policy"]["+.netease.com"] = "system";
    config["dns"]["nameserver-policy"]["+.163.com"] = "system";
    config["dns"]["nameserver-policy"]["+.126.net"] = "system";
    config["dns"]["nameserver-policy"]["+.ydstatic.com"] = "system";
    config["dns"]["nameserver-policy"]["+.youdao.com"] = "system";
  }

  return config;
}
