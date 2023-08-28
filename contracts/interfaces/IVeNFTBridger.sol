pragma solidity ^0.8.0;

interface IVeNFTBridger {
  function bridge(uint256 tokenId, address to, uint32 toChain) external payable;
}
