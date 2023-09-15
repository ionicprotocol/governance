import { task, types } from "hardhat/config";

import { Voter } from "../typechain/Voter";

enum VoterFactoryAction {
  ADD,
  REMOVE,
  REPLACE
}

const BAL8020 = "0x0000";

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

// npx hardhat gf:create-market-gauge --action 0 --gauge 0x000 --network chapel
task("voter:create-market-gauge", "create market gauge")
  .addParam("signer", "The address of the current deployer", "deployer", types.string)
  .addParam("flywheel", "The address of the flywheel deployed to the market", undefined, types.string)
  .setAction(async ({ signer, flywheel }, { ethers }) => {
    const deployer = await ethers.getNamedSigner(signer);
    const voter = (await ethers.getContract("Voter", deployer)) as Voter;

    const tx = await voter.createMarketGauge(
      BAL8020, // Lock token address
      flywheel // Flywheel Address
    );

    await tx.wait();
    console.log(`creating market gauge tx: ${tx.hash}`);
  });
