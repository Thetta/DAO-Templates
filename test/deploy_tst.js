var MyCompany = artifacts.require("./MyCompany");

contract('MyCompany', (accounts) => {
	const creator = accounts[0];
	const director = accounts[1];
	const employee = accounts[2];

	before(async() => {

	});

	beforeEach(async() => {

	});

	it('should create new MyCompany',async() => {
		let company = await MyCompany.new(creator, director, employee ,{gas: 10000000, from: creator});
	});
});
