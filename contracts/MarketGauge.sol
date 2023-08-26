// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IMarket.sol";
import "./interfaces/IFlywheel.sol";
import "./Gauge.sol";

contract MarketGauge is Gauge {
  using SafeERC20 for IERC20;

  IFlywheel public flywheel;

  function initialize(
    address _flywheel,
    address _rewardToken,
    address _ve,
    address _target,
    address _voter
  ) external initializer {
    __Gauge_init(_rewardToken, _ve, _target, _voter);
    flywheel = IFlywheel(_flywheel);
  }

  function notifyRewardAmount(address token, uint256 reward) external override nonReentrant isNotEmergency onlyVoter {
    require(token == address(rewardToken), "not rew token");
    address flywheelRewards = flywheel.flywheelRewards();
    require(flywheelRewards != address(0), "zero addr flywheel");
    rewardToken.safeTransferFrom(voter, flywheelRewards, reward);
  }

  function getReward(address _user) public override nonReentrant onlyVoter {
    flywheel.accrue(IERC20(target), _user);
    flywheel.claimRewards(_user);
  }

  function setFlywheel(IFlywheel _flywheel) external onlyOwner {
    flywheel = _flywheel;
  }
}
