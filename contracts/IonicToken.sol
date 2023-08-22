// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "chain-abstraction-integration/xtoken/XERC20Upgradeable.sol";

contract IonicToken is XERC20Upgradeable {
  function initializeIon() public initializer {
    string memory _name = "Ionic Token";
    string memory _symbol = "ION";

    __XERC20_init();
    __ERC20_init(_name, _symbol);
    __ERC20Permit_init(_name);
    __ProposedOwnable_init();

    _setOwner(msg.sender);
  }
}