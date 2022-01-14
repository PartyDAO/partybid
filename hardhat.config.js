require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('@openzeppelin/hardhat-upgrades');
const dotenv = require('dotenv');
dotenv.config();
const {verify : verifyPartybid} = require("./deploy/partybid/verify");
const {verify : verifyPartybuy} = require("./deploy/partybuy/verify")
const {verify : verifyCollection} = require("./deploy/collection-party/verify")

task("verify-partybid-contracts", "Verifies the PartyBid contracts").setAction(verifyPartybid);
task("verify-partybuy-contracts", "Verifies the PartyBuy contracts").setAction(verifyPartybuy);
task("verify-collection-contracts", "Verifies the CollectionParty contracts").setAction(verifyCollection);

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.9',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
      {
        version: '0.7.5',
        settings: {
          "optimizer": {
            "enabled": true,
            "runs": 1337
          },
          "outputSelection": {
            "*": {
              "*": [
                "evm.bytecode",
                "evm.deployedBytecode",
                "abi"
              ]
            }
          },
          "metadata": {
            "useLiteralContent": true
          },
          "libraries": {}
        },
      },
      {
        version: '0.4.11',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
      {
        version: '0.6.8',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      }
    ],
  },

  gasReporter: {
    currency: 'USD',
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },

  networks: {
    hardhat: {},
    localhost: {
      url: 'http://localhost:8545',
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
    }
  },

  mocha: {
    timeout: 150000
  }
};
