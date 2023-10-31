import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import { config as dotEnvConfig } from "dotenv";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/types/config";

import "./tasks";

dotEnvConfig();

const OVERRIDE_RPC_URL = process.env.OVERRIDE_RPC_URL || process.env.ETH_PROVIDER_URL; // Deprecated: ETH_PROVIDER_URL
const mnemonic = process.env.MNEMONIC || "test test test test test test test test test test test junk";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  paths: {
    sources: "./none",
    artifacts: "./out"
  },
  namedAccounts: {
    deployer: { default: 0 },
    alice: { default: 1 },
    bob: { default: 2 },
    rando: { default: 3 }
  },
  networks: {
    // This is the unchangeable default network which is started with `hardhat node`
    hardhat: {
      accounts: { mnemonic },
      allowUnlimitedContractSize: true,
      chainId: 1337,
      gas: 25e6,
      gasPrice: 20e10
    },
    arbitrum: {
      url: OVERRIDE_RPC_URL || `https://arb1.arbitrum.io/rpc`,
      accounts: { mnemonic },
      chainId: 42161
    },
    chapel: {
      accounts: { mnemonic },
      chainId: 97,
      url: OVERRIDE_RPC_URL || "https://data-seed-prebsc-1-s1.binance.org:8545/"
    },
    mumbai: {
      accounts: { mnemonic },
      chainId: 80001,
      url: OVERRIDE_RPC_URL || "https://rpc.ankr.com/polygon_mumbai"
    },
    arbigoerli: {
      accounts: { mnemonic },
      chainId: 421613,
      url: OVERRIDE_RPC_URL || "https://endpoints.omniatech.io/v1/arbitrum/goerli/public"
    },
    polygon: {
      url: OVERRIDE_RPC_URL || `https://polygon-mainnet.g.alchemy.com/v2/tldbE3dxJ4U5mH6aBYL3HhJAwwPWKVWw`,
      accounts: { mnemonic },
      chainId: 137
    }
  }
};

export default config;
