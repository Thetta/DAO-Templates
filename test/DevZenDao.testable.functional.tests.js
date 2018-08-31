const { increaseTime } = require("./utils/helpers");

const DevZenDaoFactory = artifacts.require("DevZenDaoFactory");
const DevZenDaoFactoryTestable = artifacts.require("DevZenDaoFactoryTestable");
const DevZenDaoTestable = artifacts.require("DevZenDaoTestable");

const DevZenDao = artifacts.require("DevZenDao");
const StdDaoToken = artifacts.require("StdDaoToken");

contract("DevZenDaoCore", (accounts) => {
	const patronAddr1 = accounts[0];
	const patronAddr2 = accounts[1];
	const hostAddr1 = accounts[2];
	const hostAddr2 = accounts[3];
	const guestAddr1 = accounts[4];
	const guestAddr2 = accounts[5];
	const guestAddr3 = accounts[6];
	const teamMemberAddr1 = accounts[7];
	const teamMemberAddr2 = accounts[8];

	let devZenDaoFactory;
	let devZenDao;
	let devZenToken;
	let repToken;

	beforeEach(async () => {
		devZenDaoFactory = await DevZenDaoFactoryTestable.new(hostAddr1, [teamMemberAddr1, teamMemberAddr2], {gas:1e13, gasPrice:0});

		const devZenDaoAddr = await devZenDaoFactory.devZenDao();
		devZenDao = DevZenDaoTestable.at(devZenDaoAddr);

		const devZenTokenAddr = await devZenDao.devZenToken();
		devZenToken = StdDaoToken.at(devZenTokenAddr);

		const repTokenAddr = await devZenDao.repToken();
		repToken = StdDaoToken.at(repTokenAddr);
	});

	describe("withdrawEther", () => {
		it("should withdraw ether to specified address", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			const initialBalance = web3.eth.getBalance(patronAddr1);
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			const balanceAfterTokensBought = web3.eth.getBalance(patronAddr1);
			assert.isTrue(initialBalance.toNumber() - balanceAfterTokensBought.toNumber() > value, 'patron should spend 1 ETH on tokens');

			await devZenDao.withdrawEther(patronAddr1).should.be.fulfilled;

			const balanceAfterWithdraw = web3.eth.getBalance(patronAddr1);
			assert.isTrue(balanceAfterWithdraw.toNumber() > balanceAfterTokensBought.toNumber(), '1 ETH should be withdrawn to patron');
		});
	});

	describe("selectNextHost", () => {
		it("should set next episode's host if it is not yet selected", async() => {
			await devZenDao.selectNextHost(hostAddr1).should.be.fulfilled;
			const nextEpisode = await devZenDao.nextEpisode();
			const nextShowHostIndex = 0;
			assert.equal(nextEpisode[nextShowHostIndex], hostAddr1);
		});

		it("should should throw if next episode's host is already selected", async() => {
			await devZenDao.selectNextHost(hostAddr1).should.be.fulfilled;
			await devZenDao.selectNextHost(hostAddr2).should.be.rejectedWith("revert");
		});
	});

	describe("burnGuestStake", () => {
		it("should burn guest's stake", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			const balanceBeforeBurn = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(balanceBeforeBurn.toNumber(), 10e18, "on new episode 10 DZT are minted to contract");

			await devZenDao.burnGuestStake().should.be.fulfilled;

			const balanceAfterBurn = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(balanceAfterBurn.toNumber(), 5e18, "burns 5 DZT at guest's stake");
		});
	});

	describe("changeTheGuest", () => {
		it("should throw if next guest is not selected", async() => {
			await devZenDao.changeTheGuest(guestAddr1).should.be.rejectedWith("revert");
		});

		it("should set the new guest", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const nextShowGuestIndex = 1;
			let nextEpisode = await devZenDao.nextEpisode();
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr1, "guest1 is now guest because he has paid for it");

			// guest2 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr2 }).should.be.fulfilled;
			// guest2 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr2 });

			// manually change the guest to guest2
			await devZenDao.changeTheGuest(guestAddr2).should.be.fulfilled;

			nextEpisode = await devZenDao.nextEpisode();
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr2, "guest2 is now guest because he was selected manually");
		});

		it("should return stake to previous guest", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			// guest2 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr2 }).should.be.fulfilled;
			// guest2 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr2 });

			const guest1BalanceBefore = await devZenToken.balanceOf(guestAddr1);
			assert.equal(guest1BalanceBefore.toNumber(), 0, "should be 0 because guest1 bought 5 DZT and put them at stake to become a guest")

			// manually change the guest to guest2
			await devZenDao.changeTheGuest(guestAddr2).should.be.fulfilled;

			const guest1BalanceAfter = await devZenToken.balanceOf(guestAddr1);
			assert.equal(guest1BalanceAfter.toNumber(), 5e18, "should be 5 because stake is returned to guest1");
		});

		it("should not return stake to previous guest if it was an emergency guest", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			// host sets guest2 an emergency guest
			await devZenDao.emergency_ChangeTheGuest(guestAddr2).should.be.fulfilled;

			// guest3 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guestAddr3 }).should.be.fulfilled;
			// guest3 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr3 });

			const balanceGuest2Before = await devZenToken.balanceOf(guestAddr2);
			assert.equal(balanceGuest2Before.toNumber(), 0, "should be 0 because it is an emergency guest");

			// host sets "legal" guest
			await devZenDao.changeTheGuest(guestAddr3).should.be.fulfilled;

			const balanceGuest2After = await devZenToken.balanceOf(guestAddr2);
			assert.equal(balanceGuest2After.toNumber(), 0, "should be 0 because emergency guest put nothing at stake");
		});
	});

	describe("emergency_ChangeTheGuest", () => {
		it("should throw if next show guest is not set", async() => {
			await devZenDao.emergency_ChangeTheGuest(guestAddr1).should.be.rejectedWith("revert");
		});

		it("should change next episode's guest and mark guest as updated", async() => {
			const guestHasCome = false;
			await devZenDao.moveToNextEpisode(guestHasCome).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			await devZenDao.emergency_ChangeTheGuest(guestAddr2).should.be.fulfilled;
			const nextEpisode = await devZenDao.nextEpisode();
			const nextShowGuestIndex = 1;
			const isGuestUpdatedIndex = 6;
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr2);
			assert.isTrue(nextEpisode[isGuestUpdatedIndex]);
		});
	});

	describe("moveToNextEpisode", () => {
		it("should mint DZT and DZTREP to contract", async() => {
			const dztBefore = await devZenToken.balanceOf(devZenDao.address);
			const dztRepBebore = await repToken.balanceOf(devZenDao.address);
			assert.equal(dztBefore, 0);
			assert.equal(dztRepBebore, 0);

			const guestHasCome = false;
			await devZenDao.moveToNextEpisode(guestHasCome).should.be.fulfilled;

			const params = await devZenDao.params();
			const mintTokensPerWeekAmountIndex = 0;
			const mintReputationTokensPerWeekAmount = 1;

			const dztAfter = await devZenToken.balanceOf(devZenDao.address);
			const dztRepAfter = await repToken.balanceOf(devZenDao.address);
			assert.equal(dztAfter, params[mintTokensPerWeekAmountIndex].toNumber());
			assert.equal(dztRepAfter, params[mintReputationTokensPerWeekAmount].toNumber());
		});

		it("should mint DZTREP to guest if he came", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const repBalanceBefore = await repToken.balanceOf(guestAddr1);
			assert.equal(repBalanceBefore.toNumber(), 0);

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDao.moveToNextEpisode(true).should.be.fulfilled;

			const params = await devZenDao.params();
			const repTokensRewardGuestIndex = 6;

			const repBalanceAfter = await repToken.balanceOf(guestAddr1);
			assert.equal(repBalanceAfter.toNumber(), params[repTokensRewardGuestIndex].toNumber());
		});

		it("should mint DZTREP to host", async() => {
			await devZenDao.selectNextHost(hostAddr1).should.be.fulfilled;

			const repBalanceBefore = await repToken.balanceOf(hostAddr1);
			assert.equal(repBalanceBefore.toNumber(), 0);

			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			const params = await devZenDao.params();
			const repTokensRewardHostIndex = 5;

			const repBalanceAfter = await repToken.balanceOf(hostAddr1);
			assert.equal(repBalanceAfter.toNumber(), params[repTokensRewardHostIndex].toNumber());
		});

		it("should transfer guest's stake back if initial guest has come", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const dztBalanceBefore = await devZenToken.balanceOf(guestAddr1);
			assert.equal(dztBalanceBefore.toNumber(), 0, "guest's 5 DZT were transfered to contract");

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDao.moveToNextEpisode(true).should.be.fulfilled;

			const dztBalanceAfter = await devZenToken.balanceOf(guestAddr1);
			assert.equal(dztBalanceAfter.toNumber(), 5e18, "guest's 5 DZT were tansfered back to guest");
		});

		it("should burn guest's stake if there was an emergency guest", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			// emergency, guest2 becomes the guest
			await devZenDao.emergency_ChangeTheGuest(guestAddr2).should.be.fulfilled;

			const contractBalanceBefore = await devZenToken.balanceOf(devZenDao.address);

			// 7 days passed and emergency guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDao.moveToNextEpisode(true).should.be.fulfilled;

			const params = await devZenDao.params();
			const becomeGuestStakeIndex = 4;

			const contractBalanceAfter = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(contractBalanceAfter.toNumber() - contractBalanceBefore.toNumber(), params[becomeGuestStakeIndex].toNumber(), "5 DZT should be burnt");
		});
	});

	describe("runAdsInTheNextEpisode", () => {
		it("should throw if all 5 slots are not available", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;
			// post 5 ads
			for(let i = 0; i < 5; i++) {
				await devZenDao.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;
			}
			await devZenDao.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.rejectedWith("revert");
		});

		it("should throw if sender does not have enough DZT", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			await devZenDao.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.rejectedWith("revert");
		});

		it("should burn sender's tokens if sender buys an ad", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			await devZenDao.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;

			const balanceAfterPurchase = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balanceAfterPurchase.toNumber(), 8e18, "sender's balance should move from 10 to 8 DZT");
		});

		it("should add ad to the slot if sender buys an ad", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// buy 10 DZT
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			await devZenDao.runAdsInTheNextEpisode("ANY_TEXT", {from: patronAddr1}).should.be.fulfilled;

			const nextEpisode = await devZenDao.nextEpisode();
			const usedSlotsIndex = 4;
			assert.equal(nextEpisode[usedSlotsIndex].toNumber(), 1, "used slots number should be increased by 1");
		});
	});

	describe("becomeTheNextShowGuest", () => {
		it("should throw if next guest is already selected", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT, allows to spend them and becomes the next guest
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;
			// guest2 buys 5 DZT, allows to spend them and wants to become the next guest
			await devZenDao.buyTokens({ value: value, from: guestAddr2 }).should.be.fulfilled;
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr2 });
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr2 }).should.be.rejectedWith("revert");
		});
	});

	describe("buyTokens", () => {
		it("should throw if msg.value = 0", async() => {
			await devZenDao.buyTokens().should.be.rejectedWith("revert");
		});

		it("should throw if there is an insufficient DZT amount in contract", async() => {
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value }).should.be.rejectedWith("revert");
		});

		it("should transfer tokens to sender if there is a sufficient DZT amount", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;

			let balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 0, "should be zero because patron has not purchased tokens yet");

			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patronAddr1 }).should.be.fulfilled;

			balancePatron1 = await devZenToken.balanceOf(patronAddr1);
			assert.equal(balancePatron1.toNumber(), 10e18, "should be 10 because 1 token costs 0.1 ETH");
		});
	});

	describe("isOneWeekPassed", () => {
		it("should return true if this is the 1st episode", async() => {
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because this is the 1st episode");
		});

		it("should return true if 7 days have passed", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			await increaseTime(60 * 60 * 24 * 7);
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isTrue(isOneWeekPassed, "should be true because 1 week has passed");
		});

		it("should return false if 7 days have not passed", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			const isOneWeekPassed = await devZenDao.isOneWeekPassed();
			assert.isFalse(isOneWeekPassed, "should be false because 1 week has not passed");
		});
	});

	describe("setGuest", () => {
		it("should throw if sender does not have enough DZT", async() => {
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.rejectedWith("revert");
		});

		it("should throw if sender has not allowed dao to put enough DZT at stake", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.rejectedWith("revert");
		});

		it("should lock tokens", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			
			let guestBalance = await devZenToken.balanceOf(guestAddr1);
			let contractBalance = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(guestBalance, 5e18, "guest balance should be equal 5 DZT");
			assert.equal(contractBalance, 5e18, "contract balance should be equal to 5 DZT, 10 initial DZT - 5 bought by the guest");

			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;
			
			guestBalance = await devZenToken.balanceOf(guestAddr1);
			contractBalance = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(guestBalance, 0, "guest balance should be 0 because he has put his 5 DZT at stake");
			assert.equal(contractBalance, 10e18, "contract balance should be equal to 10 DZT, 10 initial DZT - 5 bought by the guest + 5 put at stake by the guest");
		});

		it("should set next show guest", async() => {
			await devZenDao.moveToNextEpisode(false).should.be.fulfilled;
			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guestAddr1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guestAddr1 });
			
			await devZenDao.becomeTheNextShowGuest({ from: guestAddr1 }).should.be.fulfilled;

			const nextEpisode = await devZenDao.nextEpisode();
			const nextShowGuestIndex = 1;
			assert.equal(nextEpisode[nextShowGuestIndex], guestAddr1, "guest1 should be the next show guest");
		});
	});

});