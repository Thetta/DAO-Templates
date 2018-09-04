const HDWalletProvider = require("truffle-hdwallet-provider");
const MNEMONIC = "old deny elevator federal rib history bird squeeze emerge list multiply success"
const INFURA_API_KEY = "915933c8c46046169e9afadaac265823"

require('dotenv').config();
// 0xf6FA662e6311d837cD3f78cf0e922e097B1326F1

module.exports = {
    networks: {
		development: {
			host: "localhost",
			port: 8555,
			network_id: "*",
			gas: 100000000
		},
		coverage: {
			host: "localhost",
			network_id: '*',
			port: 8570,
			gas: 0xfffffffffff,
			gasPrice: 0x01,
		},
		main: {
			provider: () => new HDWalletProvider(MNEMONIC, "https://mainnet.infura.io/v3/" + INFURA_API_KEY),
			network_id: 1
		},
		ropsten: {
			provider: () => new HDWalletProvider(MNEMONIC, "https://ropsten.infura.io/v3/" + INFURA_API_KEY),
			network_id: 3
		},
		kovan: {
			provider: () => new HDWalletProvider(MNEMONIC, "https://kovan.infura.io/v3/" + INFURA_API_KEY),
			network_id: 42
		},
		rinkeby: {
			provider: () => new HDWalletProvider(MNEMONIC, "https://rinkeby.infura.io/v3/" + INFURA_API_KEY),
			network_id: 4
		}
    }
};