// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "chain-abstraction-integration/xtoken/XERC20Upgradeable.sol";

contract IonicToken is XERC20Upgradeable {

  struct AddressSlot {
    address value;
  }

  function initializeIon() public initializer {
    string memory _name = "Ionic Token";
    string memory _symbol = "ION";

    __XERC20_init();
    __ERC20_init(_name, _symbol);
    __ERC20Permit_init(_name);
    __ProposedOwnable_init();

    _setOwner(msg.sender);
  }

  function isBridge(address _bridge) external view returns (bool) {
    return _whitelistedBridges[_bridge];
  }

  function getProxyAdmin() external view returns (address) {
    return _getProxyAdmin();
  }

  function _getProxyAdmin() internal view returns (address admin) {
    bytes32 _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    AddressSlot storage adminSlot;
    assembly {
      adminSlot.slot := _ADMIN_SLOT
    }
    admin = adminSlot.value;
  }
}
