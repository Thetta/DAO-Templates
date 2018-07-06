const { increaseTime } = require("./utils/helpers");

const DevZenDaoFactoryTestable = artifacts.require("DevZenDaoFactoryTestable");
const DevZenDaoTestable = artifacts.require("DevZenDaoTestable");
const StdDaoToken = artifacts.require("StdDaoToken");

contract("DevZenDaoCore", (accounts) => {

	const patronAddr1 = accounts[0];

	let devZenDaoFactoryTestable;
	let devZenDaoTestable;
	let devZenToken;

	beforeEach(async () => {

		devZenDaoFactoryTestable = await DevZenDaoFactoryTestable.new();

		const devZenDaoTestableAddr = await devZenDaoFactoryTestable.dao();
		devZenDaoTestable = DevZenDaoTestable.at(devZenDaoTestableAddr);

		const devZenTokenAddr = await devZenDaoTestable.devZenToken();
		devZenToken = StdDaoToken.at(devZenTokenAddr);
	});

	describe("test buyTokens()", () => {

		it("on 0 value throws", async() => {
			await devZenDaoTestable.buyTokens().should.be.rejectedWith("revert");
		});

		it("on insufficient DZT amount in contract throws", async() => {
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value }).should.be.rejectedWith("revert");
		});

		it("on sufficient DZT amount transfers tokens to sender", async() => {

			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;

			let balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 0, "should be zero because patron has not purchased tokens yet");

			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 10 * 10**18, "should be 10 because 1 token costs 0.1 ETH");
		});
	});

	describe("test isOneWeekPassed()", () => {

		it("on the 1st episode returns true", async() => {
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because this is the 1st episode");
		});

		it("on 7 days has passed returns true", async() => {
			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;
			await increaseTime(60 * 60 * 24 * 7);
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because 1 week has passed");
		});

		it("on 7 days has not passed returns false", async() => {
			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isFalse(isOneWeekPassed, "should be false because 1 week has not passed");
		});
	});

});