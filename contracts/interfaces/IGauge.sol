// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGauge {
  function notifyRewardAmount(address token, uint amount) external;

  function getReward(address account) external;

  function setVoter(address _voter) external;

  function activateEmergencyMode() external;

  function stopEmergencyMode() external;
}
