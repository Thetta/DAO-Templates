const moment = require("moment");
const { increaseTime } = require("./utils/helpers");

const Daico = artifacts.require("DaicoTestable");
const MintableToken = artifacts.require("MintableToken");

contract("Daico", (accounts) => {

	const evercityMemberAddress = accounts[0];
	const projectOwnerAddress = accounts[1];
	const inverstorAddress = accounts[2];
	const inverstorAddress2 = accounts[3];
	const inverstorAddress3 = accounts[4];
	const inverstorAddress4 = accounts[5];

	const VOTING_TYPE_RELEASE_TAP = 0;
	const VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM = 1;
	const VOTING_TYPE_CHANGE_ROADMAP = 2;
	const VOTING_TYPE_CHANGE_ROADMAP_DECREASED_QUORUM = 3;
	const VOTING_TYPE_TERMINATE_PROJECT = 4;
	const VOTING_TYPE_TERMINATE_PROJECT_DECREASED_QUORUM = 5;

	const VOTING_RESULT_ACCEPT = 0;
	const VOTING_RESULT_DECLINE = 1;
	const VOTING_RESULT_QUORUM_NOT_REACHED = 2;
	const VOTING_RESULT_NO_DECISION = 3;

	const timestampsFinishAt = [moment().add(1, 'week').unix(), moment().add(1, '5 weeks').unix()];
	const minQuorumRate = 70;
	const minVoteRate = 70;
	const tokenHoldersCount = 5;

	let daico;
	let daiToken;
	let projectToken;

	beforeEach(async() => {
		daiToken = await MintableToken.new();
		projectToken = await MintableToken.new();
		await projectToken.mint(inverstorAddress, 1);
		await projectToken.mint(inverstorAddress2, 1);
		await projectToken.mint(inverstorAddress3, 1);
		await projectToken.mint(inverstorAddress4, 1);
		daico = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount);
	});

	describe("constructor()", () => {
		it("should revert if DAI token address is 0x00", async() => {
			await Daico.new(0x00, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if project token address is 0x00", async() => {
			await Daico.new(daiToken.address, 0x00, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if project owner address is 0x00", async() => {
			await Daico.new(daiToken.address, projectToken.address, 0x00, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if taps count is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 0, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if tap amounts array length not equal to taps count", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if tap timestamps finish at array length not equal to taps count", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], [], minVoteRate, minQuorumRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if min quorum rate is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, 0, minVoteRate, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if min vote rate is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minQuorumRate, 0, tokenHoldersCount).should.be.rejectedWith("revert");
		});

		it("should revert if token holders count is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minQuorumRate, minVoteRate, 0).should.be.rejectedWith("revert");
		});

		it("should set contract properties", async() => {
			const daicoNew = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], [3,4], 3, 4, 5).should.be.fulfilled;
			assert.equal(await daicoNew.daiToken(), daiToken.address);
			assert.equal(await daicoNew.projectToken(), projectToken.address);
			assert.equal(await daicoNew.projectOwner(), projectOwnerAddress);
			assert.equal(await daicoNew.tapsCount(), 2);
			assert.equal(await daicoNew.tapAmounts(0), 1);
			assert.equal(await daicoNew.tapAmounts(1), 2);
			assert.equal(await daicoNew.tapTimestampsFinishAt(0), 3);
			assert.equal(await daicoNew.tapTimestampsFinishAt(1), 4);
			assert.equal(await daicoNew.minQuorumRate(), 3);
			assert.equal(await daicoNew.minVoteRate(), 4);
			assert.equal(await daicoNew.tokenHoldersCount(), 5);
		});

		it("should create initial votings of type ReleaseTap", async() => {
			assert.equal(await daico.votingsCount(), 2);
			const voting = await daico.votings(0);
			assert.equal(voting[5].sub(voting[4]), 7 * 24 * 60 * 60);
			assert.equal(voting[6], VOTING_TYPE_RELEASE_TAP);
		});
	});

	describe("createVoting()", () => {
		it("should revert if quorum rate is 0", async() => {
			await daico.createVoting(0, 0, 1, 1, VOTING_TYPE_RELEASE_TAP).should.be.rejectedWith("revert");
		});

		it("should revert if created at is 0", async() => {
			await daico.createVoting(0, 1, 0, 1, VOTING_TYPE_RELEASE_TAP).should.be.rejectedWith("revert");
		});

		it("should revert if finish at is 0", async() => {
			await daico.createVoting(0, 1, 1, 0, VOTING_TYPE_RELEASE_TAP).should.be.rejectedWith("revert");
		});

		it("should create a new voting", async() => {
			await daico.createVoting(0, 1, 2, 3, VOTING_TYPE_RELEASE_TAP).should.be.fulfilled;
			const votingsCount = await daico.votingsCount();
			const voting = await daico.votings(votingsCount.sub(1));
			assert.equal(voting[0], 0);
			assert.equal(voting[3], 1);
			assert.equal(voting[4], 2);
			assert.equal(voting[5], 3);
			assert.equal(voting[6], VOTING_TYPE_RELEASE_TAP);
		});

		it("should update contract properties", async() => {
			const votingsCountBefore = (await daico.votingsCount()).toNumber();
			const tapVotingsCountBefore = (await daico.tapVotingsCount(0)).toNumber();

			await daico.createVoting(0, 1, 2, 3, VOTING_TYPE_RELEASE_TAP).should.be.fulfilled;

			const votingsCountAfter = (await daico.votingsCount()).toNumber();
			const tapVotingsCountAfter = (await daico.tapVotingsCount(0)).toNumber();

			assert.equal(await daico.tapVotings(0, tapVotingsCountAfter - 1), votingsCountAfter - 1);
			assert.equal(tapVotingsCountAfter - 1, tapVotingsCountBefore);
			assert.equal(votingsCountAfter - 1, votingsCountBefore);
		});
	});

	describe("createVotingByInvestor()", () => {
		it("should revert if voting type is not: ChangeRoadmap, ChangeRoadmapDecreasedQuorum, TerminateProject, TerminateProjectDecreasedQuorum", async() => {
			await daico.createVotingByInvestor(0, VOTING_TYPE_RELEASE_TAP, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if last voting is not finished", async() => {
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});
	});

	describe("createVotingByOwner()", () => {
		it("should revert if voting type is not release tap decreased quorum", async() => {
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if latest voting for particular tap is not finished", async() => {
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		// TODO: test 'require(latestVoting.votingType == VotingType.ReleaseTap || latestVoting.votingType == VotingType.ReleaseTapDecreasedQuorum);'

		// TODO: fix increaseTime issue
		// it("should revert if latest voting result is not quorum not reached", async() => {
		// 	await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		// 	await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
		// 	await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
		// 	await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
		// 	await increaseTime(7 * 24 * 60 * 60);
		// 	await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		// });

		// TODO: fix increaseTime issue
		// it("should create a new voting", async() => {
		// 	await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		// 	await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
		// 	await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
		// 	await increaseTime(7 * 24 * 60 * 60);
		// 	await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.fulfilled;
		// });
	});

	describe("getVotingResult()", () => {
		it("should return quorum not reached", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			assert.equal(await daico.getVotingResult(0), VOTING_RESULT_QUORUM_NOT_REACHED);
		});

		it("should return accept", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			assert.equal(await daico.getVotingResult(0), VOTING_RESULT_ACCEPT);
		});

		it("should return decline", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			assert.equal(await daico.getVotingResult(0), VOTING_RESULT_DECLINE);
		});

		it("should return no decision", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			assert.equal(await daico.getVotingResult(0), VOTING_RESULT_NO_DECISION);
		});
	});

	describe("isInvestorVoted()", () => {
		it("should revert if investor address is 0x00", async() => {
			await daico.isInvestorVoted(0, 0x00).should.be.rejectedWith("revert");
		});

		it("should return false if investor has not yet voted", async() => {
			assert.equal(await daico.isInvestorVoted(0, inverstorAddress), false);
		});

		it("should return true if investor has already voted", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			assert.equal(await daico.isInvestorVoted(0, inverstorAddress), true);
		});
	});

	describe("isTapWithdrawAcceptedByInvestors()", () => {
		it("should return false if investors have not accepted tap release", async() => {
			assert.equal(await daico.isTapWithdrawAcceptedByInvestors(0), false);
		});

		it("should return true if investors have accepted tap release", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			assert.equal(await daico.isTapWithdrawAcceptedByInvestors(0), true);
		});
	});

	describe("vote()", () => {
		it("should revert if it is too early to vote", async() => {
			await daico.vote(1, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		// TODO: fix increase time issue when timestampsFinishAt not in sync with current blockhain timestamp after 'increaseTime()'
		// it("should revert if it is too late to vote", async() => {
		// 	const daicoNew = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount);
		// 	await increaseTime(7 * 24 * 60 * 60);
		// 	await daicoNew.vote(0, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		// });

		// TODO: test 'require(!isProjectTerminated())'

		it("should revert if investor has already voted", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should mark investor as already voted", async() => {
			assert.equal(await daico.isInvestorVoted(0, inverstorAddress), false);
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			assert.equal(await daico.isInvestorVoted(0, inverstorAddress), true);
		});

		it("should update yes votes count", async() => {
			assert.equal((await daico.votings(0))[1], 0);
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			assert.equal((await daico.votings(0))[1], 1);
		});

		it("should update no votes count", async() => {
			assert.equal((await daico.votings(0))[2], 0);
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			assert.equal((await daico.votings(0))[2], 1);
		});
	});

});
