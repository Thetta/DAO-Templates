const should = require('chai')
	.use(require('chai-as-promised'))
	.should();
	
const utf8 = require('utf8');

/**
 * Increases latest block time by duration in seconds 
 */
const increaseTime = function increaseTime (duration) {

	const id = Date.now();

	return new Promise((resolve, reject) => {
		web3.currentProvider.sendAsync({
			jsonrpc: '2.0',
			method: 'evm_increaseTime',
			params: [duration],
			id: id,
		}, err1 => {
			if (err1) return reject(err1);

			web3.currentProvider.sendAsync({
				jsonrpc: '2.0',
				method: 'evm_mine',
				id: id + 1,
			}, (err2, res) => {
				return err2 ? reject(err2) : resolve(res);
			});
		});
	});
}

function uintToBytes32(n) {
	n = Number(n).toString(16);
	while (n.length < 64) {
		n = "0" + n;
	}
	return "0x" + n;
}

function padToBytes32(n, dir='right', withPrefix=true) {
	n = n.replace('0x', '');
	while (n.length < 64) {
		if(dir == 'right') n = n + "0";
		if(dir == 'left') n = "0" + n;
	}
	return withPrefix ? "0x" + n : n;
}

function fromUtf8(str) {
	str = utf8.encode(str);
	var hex = "";
	for (var i = 0; i < str.length; i++) {
		var code = str.charCodeAt(i);
		if (code === 0) {
			break;
		}
		var n = code.toString(16);
		hex += n.length < 2 ? '0' + n : n;
	}

	return padToBytes32(hex);
};


module.exports = {
	increaseTime, 
	should,
	uintToBytes32,
	padToBytes32,
	fromUtf8
};
