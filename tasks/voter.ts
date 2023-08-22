import { task, types } from "hardhat/config";

import { Voter } from "../typechain/Voter";

enum VoterFactoryAction {
  ADD,
  REMOVE,
  REPLACE
}

// npx hardhat voter:factory --action 0 --gauge 0x000 --network chapel
export default task("voter:factory", "increase the max gas fees to speed up a tx")
  .addParam("action", "which action to take", 1, types.int)
  .addOptionalParam("gauge", "gauge address", undefined, types.string)
  .addOptionalParam("pos", "position value", undefined, types.int)
  .setAction(async ({ gauge, action, pos }, { ethers }) => {
    const deployer = await ethers.getNamedSigner("deployer");

    const voter = (await ethers.getContract("Voter", deployer)) as Voter;

    let tx;

    switch (action) {
      case VoterFactoryAction.ADD:
        console.log(`adding ${gauge} for voter ${voter.address}`);
        tx = await voter.addFactory(gauge);
        await tx.wait();
        break;
      case VoterFactoryAction.REMOVE:
        console.log(`removing ${gauge} at ${pos}`);
        tx = await voter.removeFactory(pos);
        await tx.wait();
        break;
      case VoterFactoryAction.REPLACE:
        console.log(`replacing ${gauge} for voter ${voter.address} at ${pos}`);
        tx = await voter.replaceFactory(gauge, pos);
        await tx.wait();
        break;
      default:
        throw new Error(`invalid action ${action}`);
    }
  });
