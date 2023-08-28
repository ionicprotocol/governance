pragma solidity ^0.8.0;

interface IXERC721 {
  function addBridge(address _bridge) external;

  function removeBridge(address _bridge) external;

  function mint(address _to, uint256 _tokenId, bytes memory _metadata) external;

  function burn(uint256 _tokenId) external returns (bytes memory _metadata);
}
