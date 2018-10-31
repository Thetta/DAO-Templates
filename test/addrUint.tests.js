const AddrUintTest = artifacts.require("AddrUintTest");

function repeat(N, obj) {
	var buff = [];
	for(var i=0; i<N; i++){
		buff = buff.concat(obj);
	}
	return buff;

}

contract("AddrUintTest", (accounts) => {
	const creator = accounts[0];
	let addrUintTest;
	beforeEach(async () => {
		addrUintTest = await AddrUintTest.new();
	});

	it("add 10 pairs", async () => {
		var b1 = new web3.BigNumber(await web3.eth.getBalance(creator));
		await addrUintTest.addPairs(repeat(10,creator), repeat(10,42), {gasPrice:1});
		var b2 = new web3.BigNumber(await web3.eth.getBalance(creator));
		console.log('gas usage:', b1.sub(b2).toNumber());
	});

	it("add 50 pairs", async () => {
		var b1 = new web3.BigNumber(await web3.eth.getBalance(creator));
		await addrUintTest.addPairs(repeat(50,creator), repeat(50,42), {gasPrice:1});
		var b2 = new web3.BigNumber(await web3.eth.getBalance(creator));
		console.log('gas usage:', b1.sub(b2).toNumber());
	});

	it("add 100 pairs", async () => {
		var b1 = new web3.BigNumber(await web3.eth.getBalance(creator));
		await addrUintTest.addPairs(repeat(100,creator), repeat(100,42), {gasPrice:1});
		var b2 = new web3.BigNumber(await web3.eth.getBalance(creator));
		console.log('gas usage:', b1.sub(b2).toNumber());
	});	

	// it("add 150 pairs", async () => {
	// 	await addrUintTest.addPairs(repeat(150,creator), repeat(150,42));
	// });	

	// it("add 2000 pairs", async () => {
	// 	await addrUintTest.addPairs(repeat(2000,creator), repeat(2000,42));
	// });	


	// it("add 20000 pairs", async () => {
	// 	await addrUintTest.addPairs(repeat(20000,creator), repeat(20000,42));
	// });					
});