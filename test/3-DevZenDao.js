const { increaseTime } = require("./utils/helpers");

const DevZenDaoFactoryTestable = artifacts.require("DevZenDaoFactoryTestable");
const DevZenDaoTestable = artifacts.require("DevZenDaoTestable");
const StdDaoToken = artifacts.require("StdDaoToken");

contract("DevZenDaoCore", (accounts) => {
	const patronAddr1 = accounts[0];
	const patronAddr2 = accounts[1];
	const hostAddr1 = accounts[2];
	const hostAddr2 = accounts[3];
	const guestAddr1 = accounts[4];
	const guestAddr2 = accounts[5];

	let devZenDaoFactoryTestable;
	let devZenDaoTestable;
	let devZenToken;
	let repToken;

	beforeEach(async () => {
		devZenDaoFactoryTestable = await DevZenDaoFactoryTestable.new();

		const devZenDaoTestableAddr = await devZenDaoFactoryTestable.dao();
		devZenDaoTestable = DevZenDaoTestable.at(devZenDaoTestableAddr);

		const devZenTokenAddr = await devZenDaoTestable.devZenToken();
		devZenToken = StdDaoToken.at(devZenTokenAddr);

		const repTokenAddr = await devZenDaoTestable.repToken();
		repToken = StdDaoToken.at(repTokenAddr);
	});

	describe("withdrawEther", () => {
		it("should withdraw ether to specified address", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			const initialBalance = web3.eth.getBalance(patronAddr1);
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			const balanceAfterTokensBought = web3.eth.getBalance(patronAddr1);
			assert.isTrue(initialBalance.toNumber() - balanceAfterTokensBought.toNumber() > value, 'patron should spend 1 ETH on tokens');

			await devZenDaoTestable.withdrawEther(patronAddr1).should.be.fulfilled;

			const balanceAfterWithdraw = web3.eth.getBalance(patronAddr1);
			assert.isTrue(balanceAfterWithdraw.toNumber() > balanceAfterTokensBought.toNumber(), '1 ETH should be withdrawn to patron');
		});
	});

	describe("selectNextHost", () => {
		it("should set next episode's host if it is not yet selected", async() => {
			await devZenDaoTestable.selectNextHost(hostAddr1).should.be.fulfilled;
			const nextEpisode = await devZenDaoTestable.nextEpisode();
			const nextShowHostIndex = 0;
			assert.equal(nextEpisode[nextShowHostIndex], hostAddr1);
		});

		it("should should throw if next episode's host is already selected", async() => {
			await devZenDaoTestable.selectNextHost(hostAddr1).should.be.fulfilled;
			await devZenDaoTestable.selectNextHost(hostAddr2).should.be.rejectedWith("revert");
		});
	});

	describe("burnGuestStake", () => {
		it("should burn guest's stake", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			const balanceBeforeBurn = await devZenToken.balanceOf(devZenDaoTestable.address);
			assert.equal(balanceBeforeBurn.toNumber(), 10 * 10**18, "on new episode 10 DZT are minted to contract");

			await devZenDaoTestable.burnGuestStake().should.be.fulfilled;

			const balanceAfterBurn = await devZenToken.balanceOf(devZenDaoTestable.address);
			assert.equal(balanceAfterBurn.toNumber(), 5 * 10**18, "burns 5 DZT at guest's stake");
		});
	});

	describe("emergency_ChangeTheGuest", () => {
		it("should throw if next show guest is not set", async() => {
			await devZenDaoTestable.emergency_ChangeTheGuest(guestAddr1).should.be.rejectedWith("revert");
		});

		it("should change next episode's guest and mark guest as updated", async() => {
			const guestHasCome = false;
			await devZenDaoTestable.moveToNextEpisode(guestHasCome).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			await devZenDaoTestable.emergency_ChangeTheGuest(guestAddr2).should.be.fulfilled;
			const nextEpisode = await devZenDaoTestable.nextEpisode();
			const nextShowGuestIndex = 1;
			const isGuestUpdatedIndex = 6;
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr2);
			assert.isTrue(nextEpisode[isGuestUpdatedIndex]);
		});
	});

	describe("moveToNextEpisode", () => {
		it("should mint DZT and DZTREP to contract", async() => {
			const dztBefore = await devZenToken.balanceOf(devZenDaoTestable.address);
			const dztRepBebore = await repToken.balanceOf(devZenDaoTestable.address);
			assert.equal(dztBefore, 0);
			assert.equal(dztRepBebore, 0);

			const guestHasCome = false;
			await devZenDaoTestable.moveToNextEpisode(guestHasCome).should.be.fulfilled;

			const params = await devZenDaoTestable.params();
			const mintTokensPerWeekAmountIndex = 0;
			const mintReputationTokensPerWeekAmount = 1;

			const dztAfter = await devZenToken.balanceOf(devZenDaoTestable.address);
			const dztRepAfter = await repToken.balanceOf(devZenDaoTestable.address);
			assert.equal(dztAfter, params[mintTokensPerWeekAmountIndex].toNumber());
			assert.equal(dztRepAfter, params[mintReputationTokensPerWeekAmount].toNumber());
		});

		it("should mint DZTREP to guest if he came", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const repBalanceBefore = await repToken.balanceOf(guestAddr1);
			assert.equal(repBalanceBefore.toNumber(), 0);

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDaoTestable.moveToNextEpisode(true).should.be.fulfilled;

			const params = await devZenDaoTestable.params();
			const repTokensRewardGuestIndex = 6;

			const repBalanceAfter = await repToken.balanceOf(guestAddr1);
			assert.equal(repBalanceAfter.toNumber(), params[repTokensRewardGuestIndex].toNumber());
		});

		it("should mint DZTREP to host", async() => {
			await devZenDaoTestable.selectNextHost(hostAddr1).should.be.fulfilled;

			const repBalanceBefore = await repToken.balanceOf(hostAddr1);
			assert.equal(repBalanceBefore.toNumber(), 0);

			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			const params = await devZenDaoTestable.params();
			const repTokensRewardHostIndex = 5;

			const repBalanceAfter = await repToken.balanceOf(hostAddr1);
			assert.equal(repBalanceAfter.toNumber(), params[repTokensRewardHostIndex].toNumber());
		});

		it("should transfer guest's stake back if initial guest has come", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const dztBalanceBefore = await devZenToken.balanceOf(guestAddr1);
			assert.equal(dztBalanceBefore.toNumber(), 0, "guest's 5 DZT were transfered to contract");

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDaoTestable.moveToNextEpisode(true).should.be.fulfilled;

			const dztBalanceAfter = await devZenToken.balanceOf(guestAddr1);
			assert.equal(dztBalanceAfter.toNumber(), 5 * 10**18, "guest's 5 DZT were tansfered back to guest");
		});

		it("should burn guest's stake if there was an emergency guest", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			// emergency, guest2 becomes the guest
			await devZenDaoTestable.emergency_ChangeTheGuest(guestAddr2).should.be.fulfilled;

			const contractBalanceBefore = await devZenToken.balanceOf(devZenDaoTestable.address);

			// 7 days passed and emergency guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDaoTestable.moveToNextEpisode(true).should.be.fulfilled;

			const params = await devZenDaoTestable.params();
			const becomeGuestStakeIndex = 4;

			const contractBalanceAfter = await devZenToken.balanceOf(devZenDaoTestable.address);
			assert.equal(contractBalanceAfter.toNumber() - contractBalanceBefore.toNumber(), params[becomeGuestStakeIndex].toNumber(), "5 DZT should be burnt");
		});
	});

	describe("runAdsInTheNextEpisode", () => {
		it("should throw if all 5 slots are not available", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;
			// post 5 ads
			for(let i = 0; i < 5; i++) {
				await devZenDaoTestable.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;
			}
			await devZenDaoTestable.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.rejectedWith("revert");
		});

		it("should throw if sender does not have enough DZT", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			await devZenDaoTestable.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.rejectedWith("revert");
		});

		it("should burn sender's tokens if sender buys an ad", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			await devZenDaoTestable.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;

			const balanceAfterPurchase = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balanceAfterPurchase.toNumber(), 8 * 10**18, "sender's balance should move from 10 to 8 DZT");
		});

		it("should add ad to the slot if sender buys an ad", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			await devZenDaoTestable.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;

			const nextEpisode = await devZenDaoTestable.nextEpisode();
			const usedSlotsIndex = 4;
			assert.equal(nextEpisode[usedSlotsIndex].toNumber(), 1, "used slots number should be increased by 1");
		});
	});

	describe("becomeTheNextShowGuest", () => {
		it("should throw if next guest is already selected", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT, allows to spend them and becomes the next guest
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;
			// guest2 buys 5 DZT, allows to spend them and wants to become the next guest
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr2 }).should.be.fulfilled;
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr2 });
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr2 }).should.be.rejectedWith("revert");
		});

		it("should throw if sender does not have enough DZT", async() => {
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.rejectedWith("revert");
		});

		it("should throw if sender has not allowed dao to put enough DZT at stake", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.rejectedWith("revert");
		});

		it("should lock tokens", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			
			let guestBalance = await devZenToken.balanceOf(guestAddr1);
			let contractBalance = await devZenToken.balanceOf(devZenDaoTestable.address);
			assert.equal(guestBalance, 5 * 10**18, "guest balance should be equal 5 DZT");
			assert.equal(contractBalance, 5 * 10**18, "contract balance should be equal to 5 DZT, 10 initial DZT - 5 bought by the guest");

			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;
			
			guestBalance = await devZenToken.balanceOf(guestAddr1);
			contractBalance = await devZenToken.balanceOf(devZenDaoTestable.address);
			assert.equal(guestBalance, 0, "guest balance should be 0 because he has put his 5 DZT at stake");
			assert.equal(contractBalance, 10 * 10**18, "contract balance should be equal to 10 DZT, 10 initial DZT - 5 bought by the guest + 5 put at stake by the guest");
		});

		it("should set next show guest", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDaoTestable.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDaoTestable.address, 5 * 10**18, { from: guestAddr1 });
			
			await devZenDaoTestable.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const nextEpisode = await devZenDaoTestable.nextEpisode();
			const nextShowGuestIndex = 1;
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr1, "guest1 should be the next show guest");
		});
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
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;

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
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			await increaseTime(60 * 60 * 24 * 7);
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because 1 week has passed");
		});

		it("should return false if 7 days have not passed", async() => {
			await devZenDaoTestable.moveToNextEpisode(false).should.be.fulfilled;
			const isOneWeekPassed = await devZenDaoTestable.isOneWeekPassed();
			assert.isFalse(isOneWeekPassed, "should be false because 1 week has not passed");
		});
	});

});