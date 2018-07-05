const { increaseTime } = require("./utils/helpers");

const DevZenDao = artifacts.require("DevZenDao");
const DevZenDaoFactory = artifacts.require("DevZenDaoFactory");
const StdDaoToken = artifacts.require("StdDaoToken");

contract("DevZenDao", (accounts) => {

	const bossAddr = accounts[0];
	const teamMemberAddr1 = accounts[1];
	const teamMemberAddr2 = accounts[2];
	const patronAddr1 = accounts[3];

	let devZenDao;
	let devZenDaoFactory;
	let devZenToken;

	beforeEach(async () => {

		devZenDaoFactory = await DevZenDaoFactory.new(bossAddr, [teamMemberAddr1, teamMemberAddr2]);

		const devZenDaoAddr = await devZenDaoFactory.dao();
		devZenDao = DevZenDao.at(devZenDaoAddr);

		const devZenTokenAddr = await devZenDao.devZenToken();
		devZenToken = StdDaoToken.at(devZenTokenAddr);
	});

	describe("test buyTokens()", () => {

		it("on 0 value throws", async() => {
			await devZenDao.buyTokens().should.be.rejectedWith("revert");
		});

		it("on insufficient DZT amount in contract throws", async() => {
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value }).should.be.rejectedWith("revert");
		});

		it("on sufficient DZT amount transfers tokens to sender", async() => {

			await devZenDao.moveToNextEpisode().should.be.fulfilled;

			let balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 0, "should be zero because patron has not purchased tokens yet");

			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 10 * 10**18, "should be 10 because 1 token costs 0.1 ETH");
		});
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
