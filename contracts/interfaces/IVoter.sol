// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVoter {
  function _ve() external view returns (address);

  function gauges(address _pair) external view returns (address);

  function isGauge(address _gauge) external view returns (bool);

  function targetForGauge(address _gauge) external view returns (address);

  function minter() external view returns (address);

  function notifyRewardAmount(uint amount) external;

  function distributeAll() external;

  function usedWeights(uint id) external view returns (uint);

  function lastVoted(uint id) external view returns (uint);

  function targetVote(uint id, uint _index) external view returns (address _pair);

  function votes(uint id, address _target) external view returns (uint votes);

  function targetVoteLength(uint tokenId) external view returns (uint);
}
