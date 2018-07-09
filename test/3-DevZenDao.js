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

	describe("buyTokens", () => {
		it("should throw if msg.value = 0", async() => {
			await devZenDaoTestable.buyTokens().should.be.rejectedWith("revert");
		});

		it("should throw if there is an insufficient DZT amount in contract", async() => {
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value }).should.be.rejectedWith("revert");
		});

		it("should transfer tokens to sender if there is a sufficient DZT amount", async() => {
			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;

			let balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 0, "should be zero because patron has not purchased tokens yet");

			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 10 * 10**18, "should be 10 because 1 token costs 0.1 ETH");
		});
	});

	describe("isOneWeekPassed", () => {
		it("should return true if this is the 1st episode", async() => {
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because this is the 1st episode");
		});

		it("should return true if 7 days have passed", async() => {
			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;
			await increaseTime(60 * 60 * 24 * 7);
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because 1 week has passed");
		});

		it("should return false if 7 days have not passed", async() => {
			await devZenDaoTestable.moveToNextEpisode().should.be.fulfilled;
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isFalse(isOneWeekPassed, "should be false because 1 week has not passed");
		});
	});

});