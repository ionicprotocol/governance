// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IXERC721} from "../../interfaces/IXERC721.sol";

contract ConnextTarget is IXReceiver {
    IXERC721 public immutable VE_TOKEN;
    IConnext public immutable CONNEXT;
    mapping(uint32 => address) public sources;

    error ONLY_ORIGIN(uint32 originDomain, address originSender, address sender);

    /**
     * @notice A modifier for authenticated calls.
     * This is an important security consideration. If the target contract
     * function should be authenticated, it must check three things:
     *    1) The originating call comes from a registered origin domain.
     *    2) The originating call comes from the expected origin contract of the origin domain.
     *    3) The call to this contract comes from Connext.
     */
    modifier onlyOrigin(address _originSender, uint32 _origin) {
        address originSender = sources[_origin];
        if (originSender == address(0) || originSender != _originSender || msg.sender != address(CONNEXT)) {
            revert ONLY_ORIGIN(_origin, _originSender, msg.sender);
        }
        _;
    }

    constructor(address _veToken, address _connext) {
        VE_TOKEN = IXERC721(_veToken);
        CONNEXT = IConnext(_connext);
    }

    function setSource(address _source, uint32 _chain) external onlyOwner {
        sources[_chain] = _source;
    }

    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    ) external onlyOrigin(_originSender, _origin) returns (bytes memory) {
        (uint256 tokenId, address to) = abi.decode(_callData, (uint256, address));
        VE_TOKEN.mint(to, tokenId);
        return "";
    }
}
