const { increaseTime } = require("./utils/helpers");

const DevZenDaoFactory = artifacts.require("DevZenDaoFactory");
const DevZenDaoAuto = artifacts.require("DevZenDaoAuto");
const DevZenDao = artifacts.require("DevZenDao");
const DaoBase = artifacts.require("DaoBase");
const IProposal = artifacts.require("IProposal");
const IVoting = artifacts.require("IVoting");

const DevZenDaoWithUnpackers = artifacts.require("DevZenDaoWithUnpackers");
const StdDaoToken = artifacts.require("StdDaoToken");

const getVoting = async(daoBase,i) => {
	let pa = await daoBase.getProposalAtIndex(i);
	let proposal = await IProposal.at(pa);
	let votingAddress = await proposal.getVoting();
	let voting = await IVoting.at(votingAddress);
	return voting;
}

const checkVoting = async(voting, yes, no, finished, isYes) => {
	const r1 = await voting.getVotingStats();
	assert.equal(r1[0].toNumber(),yes,'yes');
	assert.equal(r1[1].toNumber(),no,'no');
	assert.strictEqual(await voting.isFinished(),finished,'Voting is still not finished');
	assert.strictEqual(await voting.isYes(),isYes,'Voting is still not finished');
}

contract("DevZenDaoAuto", (accounts) => {
	
	const boss = accounts[0];
	const newBoss = accounts[1]
	const guest1 = accounts[2];
	const guest2 = accounts[3];
	const guest3 = accounts[4];
	const teamMember1 = accounts[5];
	const teamMember2 = accounts[6];
	const patron = accounts[7];

	let devZenDaoFactory;
	let devZenDao;
	let devZenToken;
	let repToken;
	let devZenAuto;
	let daoBase;

	beforeEach(async () => {
		devZenDaoFactory = await DevZenDaoFactory.new(boss, [teamMember1, teamMember2], {gas:1e13, gasPrice:0});
		devZenDao = DevZenDao.at(await devZenDaoFactory.devZenDao());
		daoBase = DaoBase.at(await devZenDaoFactory.daoBase());
		devZenToken = StdDaoToken.at(await devZenDao.devZenToken());
		repToken = StdDaoToken.at(await devZenDao.repToken());
		devZenAuto = DevZenDaoAuto.at(await devZenDaoFactory.aac());
	});

	describe("withdrawEtherAuto", () => {
		it("should withdraw ether to specified address", async() => {
			await devZenDao.moveToNextEpisode(false, {from:boss}).should.be.fulfilled;

			const initialBalance = web3.eth.getBalance(patron);
			const value = web3.toWei(1, "ether");
			await devZenDao.buyTokens({ value: value, from: patron }).should.be.fulfilled;

			const balanceAfterTokensBought = web3.eth.getBalance(patron);
			assert.isTrue(initialBalance.toNumber() - balanceAfterTokensBought.toNumber() > value, 'patron should spend 1 ETH on tokens');

			await devZenAuto.withdrawEtherAuto(patron,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);	
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);
			const balanceAfterWithdraw = web3.eth.getBalance(patron);
			assert.isTrue(balanceAfterWithdraw.toNumber() > balanceAfterTokensBought.toNumber(), '1 ETH should be withdrawn to patron');
		});
	});

	describe("selectNextHostAuto", () => {
		it("should set next episode's host if it is not yet selected", async() => {
			await devZenAuto.selectNextHostAuto(boss, {from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);	
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			const nextEpisode = await devZenDao.nextEpisode();
			const nextShowHostIndex = 0;
			assert.equal(nextEpisode[nextShowHostIndex], boss);
		});

	});

	describe("burnGuestStakeAuto", () => {
		it("should burn guest's stake", async() => {
			await devZenDao.moveToNextEpisode(false,{from:boss}).should.be.fulfilled;

			const balanceBeforeBurn = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(balanceBeforeBurn.toNumber(), 10e18, "on new episode 10 DZT are minted to contract");

			await devZenAuto.burnGuestStakeAuto({from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);	
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			const balanceAfterBurn = await devZenToken.balanceOf(devZenDao.address);
			assert.equal(balanceAfterBurn.toNumber(), 5e18, "burns 5 DZT at guest's stake");
		});
	});

	describe("changeTheGuestAuto", () => {
		it("should set the new guest", async() => {
			await devZenDao.moveToNextEpisode(false,{from:boss}).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guest1 }).should.be.fulfilled;

			const nextShowGuestIndex = 1;
			let nextEpisode = await devZenDao.nextEpisode();
			assert.equal(nextEpisode[nextShowGuestIndex], guest1, "guest1 is now guest because he has paid for it");

			// guest2 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest2 }).should.be.fulfilled;
			// guest2 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest2 });

			// manually change the guest to guest2
			await devZenAuto.changeTheGuestAuto(guest2, {from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			nextEpisode = await devZenDao.nextEpisode();
			assert.equal(nextEpisode[nextShowGuestIndex], guest2, "guest2 is now guest because he was selected manually");
		});
	
		it("should return stake to previous guest", async() => {
			await devZenDao.moveToNextEpisode(false, {from:boss}).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guest1 }).should.be.fulfilled;

			// guest2 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest2 }).should.be.fulfilled;
			// guest2 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest2 });

			const guest1BalanceBefore = await devZenToken.balanceOf(guest1);
			assert.equal(guest1BalanceBefore.toNumber(), 0, "should be 0 because guest1 bought 5 DZT and put them at stake to become a guest")

			// manually change the guest to guest2
			await devZenAuto.changeTheGuestAuto(guest2,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);	
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			const guest1BalanceAfter = await devZenToken.balanceOf(guest1);
			assert.equal(guest1BalanceAfter.toNumber(), 5e18, "should be 5 because stake is returned to guest1");
		});

		it("should not return stake to previous guest if it was an emergency guest", async() => {
			await devZenDao.moveToNextEpisode(false,{from:boss}).should.be.fulfilled;
			const value = web3.toWei("0.5", "ether");

			// guest1 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guest1 }).should.be.fulfilled;

			// host sets guest2 an emergency guest
			await devZenAuto.emergency_ChangeTheGuestAuto(guest2,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);	
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			// guest3 buys 5 DZT
			await devZenDao.buyTokens({ value: value, from: guest3 }).should.be.fulfilled;
			// guest3 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest3 });

			const balanceGuest2Before = await devZenToken.balanceOf(guest2);
			assert.equal(balanceGuest2Before.toNumber(), 0, "should be 0 because it is an emergency guest");

			// host sets "legal" guest
			await devZenAuto.changeTheGuestAuto(guest3,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,1);
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			const balanceGuest2After = await devZenToken.balanceOf(guest2);
			assert.equal(balanceGuest2After.toNumber(), 0, "should be 0 because emergency guest put nothing at stake");
		});
	});

	describe("moveToNextEpisodeAuto", () => {

		it("should mint DZTREP to guest if he came", async() => {
			await devZenAuto.moveToNextEpisodeAuto(false,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guest1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guest1 }).should.be.fulfilled;

			const repBalanceBefore = await repToken.balanceOf(guest1);
			assert.equal(repBalanceBefore.toNumber(), 0);

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDao.moveToNextEpisode(true,{from:boss}).should.be.fulfilled;

			const params = await devZenDao.params();
			const repTokensRewardGuestIndex = 6;

			const repBalanceAfter = await repToken.balanceOf(guest1);
			assert.equal(repBalanceAfter.toNumber(), params[repTokensRewardGuestIndex].toNumber());
		});
	
		it("should transfer guest's stake back if initial guest has come", async() => {
			await devZenAuto.moveToNextEpisodeAuto(false,{from:teamMember1}).should.be.fulfilled;
			voting = await getVoting(daoBase,0);
			await checkVoting(voting, 1, 0, false, false);
			await voting.vote(true,{from:teamMember2});
			await checkVoting(voting, 2, 0, true, true);

			// guest1 buys 5 DZT
			const value = web3.toWei("0.5", "ether");
			await devZenDao.buyTokens({ value: value, from: guest1 }).should.be.fulfilled;
			// guest1 allows to spend his 5 DZT
			await devZenToken.approve(devZenDao.address, 5e18, { from: guest1 });
			// guest1 becomes the next show guest
			await devZenDao.becomeTheNextShowGuest({ from: guest1 }).should.be.fulfilled;

			const dztBalanceBefore = await devZenToken.balanceOf(guest1);
			assert.equal(dztBalanceBefore.toNumber(), 0, "guest's 5 DZT were transfered to contract");

			// 7 days passed and guest came
			await increaseTime(60 * 60 * 24 * 7);
			await devZenDao.moveToNextEpisode(true,{from:boss}).should.be.fulfilled;

			const dztBalanceAfter = await devZenToken.balanceOf(guest1);
			assert.equal(dztBalanceAfter.toNumber(), 5e18, "guest's 5 DZT were tansfered back to guest");
		});
	});
});