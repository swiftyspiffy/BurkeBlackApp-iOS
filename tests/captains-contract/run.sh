#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
contract_binary=$(mktemp "${TMPDIR:-/tmp}/captains-contract.XXXXXX")
trap 'rm -f "$contract_binary"' EXIT
"${SWIFTC:-swiftc}" -swift-version 5 \
  BurkeBlackApp/Models/CaptainsModels.swift \
  BurkeBlackApp/Services/CaptainsAPI.swift \
  BurkeBlackApp/Services/CaptainsStore.swift \
  BurkeBlackApp/Services/CaptainsSocket.swift \
  BurkeBlackApp/Services/EventPopupCoordinator.swift \
  BurkeBlackApp/Services/CaptainsViewModel.swift \
  BurkeBlackApp/Services/GiveawayWebSocket.swift \
  tests/captains-contract/Support.swift \
  tests/captains-contract/HTTPFixtures.swift \
  tests/captains-contract/GiveawayFixtures.swift \
  tests/captains-contract/main.swift -o "$contract_binary"
"$contract_binary"
