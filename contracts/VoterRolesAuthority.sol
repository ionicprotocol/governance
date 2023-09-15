// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./factories/GaugeFactory.sol";

import { RolesAuthority, Authority } from "solmate/auth/authorities/RolesAuthority.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract VoterRolesAuthority is RolesAuthority, Initializable {
  constructor() RolesAuthority(address(0), Authority(address(0))) {
    _disableInitializers();
  }

  uint8 public VOTER_ROLE = 1;

  modifier onlyOwner() virtual {
    require(msg.sender == owner, "UNAUTHORIZED");

    _;
  }

  function initialize(address _owner) public initializer {
    owner = _owner;
    authority = this;
  }

  function configureRoles(address _gaugesFactory) external onlyOwner {
    setRoleCapability(VOTER_ROLE, _gaugesFactory, GaugeFactory.createMarketGauge.selector, true);
    setRoleCapability(VOTER_ROLE, _gaugesFactory, GaugeFactory.createPairGauge.selector, true);
  }

  function configureVoterPermissions(address _voter) external onlyOwner {
    setUserRole(_voter, VOTER_ROLE, true);
  }
}
