import * as dotenv from "dotenv";
import * as tdly from "@tenderly/hardhat-tenderly";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

dotenv.config();
// tdly.setup({ automaticVerifications: true });


export default {
    // defaultNetwork: "tenderly",
    networks: {
        hardhat: {
        },
        tenderly: {
            url: `${process.env.TENDERLY_RPC_URL}`,
            accounts: [`${process.env.PRIVATE_KEY_DEPLOY}`]
        },
        base: {
            url: `${process.env.BASE_RPC_URL}`,
            accounts: [`${process.env.PRIVATE_KEY_DEPLOY}`]
        },
        morph_testnet: {
            url: `https://rpc-quicknode-holesky.morphl2.io`,
            accounts: [`${process.env.PRIVATE_KEY_DEPLOY}`]
        },
        morph: {
            url: `https://rpc-quicknode.morphl2.io`,
            accounts: [`${process.env.PRIVATE_KEY_DEPLOY}`]
        }
    },
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            },
            viaIR: true,
        }
    },
    etherscan: {
        apiKey: {
            morph: "dodo",
            morph_testnet: "dodo",
        },
        customChains: [
            {
                network: "morph",
                chainId: 2818,
                urls: {
                    apiURL: "https://explorer-api.morphl2.io/api?",
                    browserURL: "https://explorer.morphl2.io",
                },
            },
            {
                network: "morph_testnet",
                chainId: 2810,
                urls: {
                  apiURL: 'https://explorer-api-holesky.morphl2.io/api? ',
                  browserURL: 'https://explorer-holesky.morphl2.io/',
                },
            },
        ]
    },
    tenderly: {
        username: "velodrome-finance",
        project: "v2",
        privateVerification: false
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    typechain: {
        outDir: "artifacts/types",
        target: "ethers-v5"
    }
};