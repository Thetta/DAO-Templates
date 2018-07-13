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
		}
    }
};