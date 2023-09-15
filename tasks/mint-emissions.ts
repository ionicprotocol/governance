import { task, types } from "hardhat/config";

import { IonicToken } from "../typechain";

task("mint:emissions")
  .addParam("amount", "in wei (multiplied by 1e18)", "0", types.int)
  .setAction(async ({ amount }, { ethers, getNamedAccounts, getChainId }) => {
    const ARBI_ID = 42161;
    const chainid = parseInt(await getChainId());
    console.log("chainId: ", chainid);
    if (chainid != ARBI_ID) throw new Error(`emissions cannot be minted for other chains, other than Arbitrum`);
    const { deployer } = await getNamedAccounts();
    console.log("deployer: ", deployer);

    const ion = (await ethers.getContract("IonicToken")) as IonicToken;

    let tx;
    tx = await ion.mint(deployer, amount);
    console.log(`waiting for tx`, tx.hash);
    await tx.wait();
    console.log(`minted ${amount} of ION`);
  });
