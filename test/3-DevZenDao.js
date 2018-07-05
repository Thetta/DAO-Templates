const { increaseTime } = require("./utils/helpers");

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

	describe("test isOneWeekPassed()", () => {

		it("on the 1st episode returns true", async() => {
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because this is the 1st episode");
		});

		it("on 7 days has passed returns true", async() => {
			await devZenDao.moveToNextEpisode().should.be.fulfilled;
			await increaseTime(60 * 60 * 24 * 7);
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because 1 week has passed");
		});

		it("on 7 days has not passed returns false", async() => {
			await devZenDao.moveToNextEpisode().should.be.fulfilled;
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isFalse(isOneWeekPassed, "should be false because 1 week has not passed");
		});

	});

});
