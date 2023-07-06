import 'hardhat-typechain'
import 'hardhat-gas-reporter'

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import 'hardhat-interface-generator'
import * as dotenv from 'dotenv'
dotenv.config()

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      loggingEnabled: true,
      // chainId: 1337,
      forking: {
        url: `${process.env.MAINNET_RPC_URL}`,
      },
      accounts: [
        {
          privateKey: `${process.env.PRIVATE_KEY_1}`,
          balance: '10000000000000000000000'
        },
        {
          privateKey: `${process.env.PRIVATE_KEY_2}`,
          balance: '10000000000000000000000'
        },
        {
          privateKey: `${process.env.PRIVATE_KEY_3}`,
          balance: '10000000000000000000000'
        },
      ],
    },

    mainnet: {
      url: `${process.env.MAINNET_RPC_URL}`,
      // accounts: [
      //   `${process.env.PRIVATE_KEY_1}`,
      //   `${process.env.PRIVATE_KEY_2}`,
      // ],
    },
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com/`,
      accounts: [
        `${process.env.PRIVATE_KEY_1}`,
        `${process.env.PRIVATE_KEY_2}`,
        `${process.env.PRIVATE_KEY_3}`,
      ],
    },
    sepolia: {
      url: ``,
      accounts: [
        `${process.env.PRIVATE_KEY_1}`,
        `${process.env.PRIVATE_KEY_2}`,
        `${process.env.PRIVATE_KEY_3}`,
      ],
    },
    goerli: {
      url: ``,
      accounts: [
        `${process.env.PRIVATE_KEY_1}`,
        `${process.env.PRIVATE_KEY_2}`,
        `${process.env.PRIVATE_KEY_3}`,
      ],
    }
    // polygon: {
    //   url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // ropsten: {
    //   url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // rinkeby: {
    //   url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // goerli: {
    //   url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // kovan: {
    //   url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // arbitrumRinkeby: {
    //   url: `https://arbitrum-rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // arbitrum: {
    //   url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // optimismKovan: {
    //   url: `https://optimism-kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // optimism: {
    //   url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    // },
    // bnb: {
    //   url: `https://bsc-dataseed.binance.org/`,
    // },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: 'none',
      },
    },
  },
  plugins: [
    'hardhat-gas-reporter'
  ],
  gasReporter: {
    currency: 'USD',
    enabled: true,
    excludeContracts: []
  },
}
