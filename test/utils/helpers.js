const should = require('chai')
	.use(require('chai-as-promised'))
	.should();
	
const utf8 = require('utf8');

/**
 * Increases latest block time by duration in seconds 
 */
async function increaseTime (duration) {
	var id = Date.now();
	await web3.currentProvider.sendAsync({
		jsonrpc: '2.0',
		method: 'evm_increaseTime',
		params: [duration],
		id: id
	}, function (err) { if (err) console.log('err:', err); });
	await web3.currentProvider.sendAsync({
		jsonrpc: '2.0',
		method: 'evm_mine',
		id: id + 1
	}, function (err) { if (err) console.log('err:', err); });	
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
