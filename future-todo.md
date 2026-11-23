# future-todo

- WWW::Hetzner and WWW::req are not installed. hcli personalities and any Robot call stay untested until Todd says to install those ports or to load the sibling trees with -I. No cpan.
- grok-market needs Hetzner::Robot and calls server_market_search / total_results / items_per_page, which lib/Hetzner/Robot.pm does not provide. Decide whether to delete the sketch or rewrite it against a real module.
- No official Hetzner sandbox. Third-party Robot mock is nl2go/hetzner-robot-api-mock (user robot, password secret). The old Cloud mock (LKDevelopment/hetzner-cloud-api-mock) is archived. Neither is set up here.
- hcli -p servers is broken against current WWW::Hetzner: ip and get were removed in p5-WWW-Hetzner 17c1a7c. vget plus IPv6-only servers (no server_ip) still need a formatter. Gateway is on the subnet list, not server.ip.
- hcli -p traffic still sends a 2017 range and no ip or subnet. API returns 400.
- Revamp scope waits on Todd's next instructions.
