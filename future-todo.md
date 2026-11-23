# future-todo

- WWW::Hetzner and WWW::req are not installed. hcli personalities and any Robot call stay untested until Todd says to install those ports or to load the sibling trees with -I. No cpan.
- grok-market needs Hetzner::Robot and calls server_market_search / total_results / items_per_page, which lib/Hetzner/Robot.pm does not provide. Decide whether to delete the sketch or rewrite it against a real module.
- No official Hetzner sandbox. Third-party Robot mock is nl2go/hetzner-robot-api-mock (user robot, password secret). The old Cloud mock (LKDevelopment/hetzner-cloud-api-mock) is archived. Neither is set up here.
- Revamp scope waits on Todd's next instructions.
