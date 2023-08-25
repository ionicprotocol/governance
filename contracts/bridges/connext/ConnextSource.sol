// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IVeNFTBridger} from "../../interfaces/IVeNFTBridger.sol";
import {IXERC721} from "../../interfaces/IXERC721.sol";

contract ConnextSource is IVeNFTBridger, Ownable {
    IXERC721 public immutable VE_TOKEN;
    IConnext public immutable CONNEXT;
    mapping(uint32 => address) public targets;

    error INVALID_CHAIN(uint32 chain);
    error NO_TARGET(uint32 chain);

    constructor(address _veToken, address _connext) {
        VE_TOKEN = IXERC721(_veToken);
        CONNEXT = IConnext(_connext);
    }

    function setTarget(address _target, uint32 _chain) external onlyOwner {
        targets[_chain] = _target;
    }

    function bridge(uint256 tokenId, address to, uint32 toChain) external payable override {
        address target = targets[toChain];
        if (target == address(0)) {
            revert NO_TARGET(toChain);
        }
        VE_TOKEN.burn(tokenId);
        bytes memory _callData = abi.encode(tokenId, to);
        CONNEXT.xcall(getDomainFromChain(toChain), target, address(0), msg.sender, 0, 0, _callData);
    }

    function getDomainFromChain(uint32 chain) public pure returns (uint256) {
        // mainnets
        if (chain == 1) {
            return 6648936;
        } else if (chain == 137) {
            return 1886350457;
        } else if (chain == 10) {
            return 1869640809;
        } else if (chain == 42161) {
            return 1634886255;
        } else if (chain == 100) {
            return 6778479;
        } else if (chain == 56) {
            return 6450786;
            // testnets
        } else if (chain == 5) {
            return 1735353714;
        } else if (chain == 420) {
            return 1735356532;
        } else if (chain == 80001) {
            return 9991;
        } else if (chain == 421613) {
            return 1734439522;
        } else {
            revert INVALID_CHAIN(chain);
        }
    }
}
