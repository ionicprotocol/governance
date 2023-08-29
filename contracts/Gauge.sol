// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IGauge.sol";

interface IRewarder {
  function onReward(address user, address recipient, uint256 userBalance) external;
}

abstract contract Gauge is ReentrancyGuardUpgradeable, OwnableUpgradeable, IGauge {
  using SafeERC20 for IERC20;

  bool public emergency;

  IERC20 public rewardToken;

  // used in the inheriting contracts
  address public target;

  // TODO unused?
  address public ve;
  address public voter;

  event RewardAdded(uint256 reward);
  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event Harvest(address indexed user, uint256 reward);

  event ClaimFees(address indexed from, uint256 fees);
  event EmergencyActivated(address indexed gauge, uint256 timestamp);
  event EmergencyDeactivated(address indexed gauge, uint256 timestamp);

  modifier onlyVoter() {
    require(msg.sender == voter, "Caller is not Voter contract");
    _;
  }

  modifier isNotEmergency() {
    require(emergency == false, "emergency");
    _;
  }

  constructor() {
    _disableInitializers();
  }

  function __Gauge_init(address _rewardToken, address _ve, address _target, address _voter) internal onlyInitializing {
    __Ownable_init();
    __ReentrancyGuard_init();

    rewardToken = IERC20(_rewardToken); // main reward
    ve = _ve; // vested
    target = _target; // gauge target address
    voter = _voter; // distro address (voter)

    emergency = false; // emergency flag
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    ONLY OWNER
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  ///@notice set voter address (should be voter)
  function setVoter(address _voter) external onlyOwner {
    require(_voter != address(0), "zero addr");
    require(_voter != voter, "same addr");
    voter = _voter;
  }

  function activateEmergencyMode() external onlyOwner {
    require(emergency == false, "emergency");
    emergency = true;
    emit EmergencyActivated(address(this), block.timestamp);
  }

  function stopEmergencyMode() external onlyOwner {
    require(emergency == true, "emergency");

    emergency = false;
    emit EmergencyDeactivated(address(this), block.timestamp);
  }

  /// @dev Receive rewards from voter
  function notifyRewardAmount(address token, uint256 reward) external virtual;
}
