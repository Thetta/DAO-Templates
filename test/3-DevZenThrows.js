const DevZenDao = artifacts.require("DevZenDao");
const DevZenDaoFactory = artifacts.require("DevZenDaoFactory");

contract("DevZenDao", (accounts) => {

	const bossAddr = accounts[0];
	const teamMemberAddr1 = accounts[1];
	const teamMemberAddr2 = accounts[2];

	let devZenDao;
	let devZenDaoFactory;

	beforeEach(async () => {

		devZenDaoFactory = await DevZenDaoFactory.new(bossAddr, [teamMemberAddr1, teamMemberAddr2]);

		const devZenDaoAddr = await devZenDaoFactory.dao();
		devZenDao = DevZenDao.at(devZenDaoAddr);
	});

	describe("test func()", () => {

		it("test1", async() => {

		});

	});

});