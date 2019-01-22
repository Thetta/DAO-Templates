const moment = require("moment");
const { increaseTime } = require("./utils/helpers");

const Daico = artifacts.require("DaicoTestable");
const MintableToken = artifacts.require("MintableToken");

contract("Daico unit tests", (accounts) => {
	const evercityMemberAddress = accounts[0];
	const projectOwnerAddress = accounts[1];
	const inverstorAddress = accounts[2];
	const inverstorAddress2 = accounts[3];
	const inverstorAddress3 = accounts[4];
	const inverstorAddress4 = accounts[5];
	const inverstorAddress5 = accounts[6];
	const returnAddress = accounts[7];
	const otherAddress = accounts[8];

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

	const minQuorumRate = 70;
	const minVoteRate = 70;

	let daico;
	let daiToken;
	let projectToken;
	let timestampsFinishAt;

	beforeEach(async() => {
		daiToken = await MintableToken.new();
		await daiToken.mint(evercityMemberAddress, 3);

		projectToken = await MintableToken.new();
		await projectToken.mint(inverstorAddress, 1);
		await projectToken.mint(inverstorAddress2, 1);
		await projectToken.mint(inverstorAddress3, 1);
		await projectToken.mint(inverstorAddress4, 1);
		
		timestampsFinishAt = [
			moment.unix(web3.eth.getBlock("latest").timestamp).add(1, 'week').unix(),
			moment.unix(web3.eth.getBlock("latest").timestamp).add(5, 'weeks').unix()
		];
		daico = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate);
		await daiToken.transfer(daico.address, 3, {from: evercityMemberAddress});
	});

	describe("constructor()", () => {
		it("should revert if DAI token address is 0x00", async() => {
			await Daico.new(0x00, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if project token address is 0x00", async() => {
			await Daico.new(daiToken.address, 0x00, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if project owner address is 0x00", async() => {
			await Daico.new(daiToken.address, projectToken.address, 0x00, returnAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if taps count is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 0, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if tap amounts array length not equal to taps count", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [], timestampsFinishAt, minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if tap timestamps finish at array length not equal to taps count", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], [], minVoteRate, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should revert if min quorum rate is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, 0, minVoteRate).should.be.rejectedWith("revert");
		});

		it("should revert if min vote rate is 0", async() => {
			await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, 0, minQuorumRate).should.be.rejectedWith("revert");
		});

		it("should set contract properties", async() => {
			const daicoNew = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], [3,4], 3, 4).should.be.fulfilled;
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

		it("should create a new voting (daico.createVoting)", async() => {
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

		it("should revert on ChangeRoadmap voting type when last voting is not: ReleaseTap, ReleaseTapDecreasedQuorum, TerminateProject, TerminateProjectDecreasedQuorum", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(28 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert on ChangeRoadmap voting type when last voting is ReleaseTap or ReleaseTapDecreasedQuorum with voting result not NoDecision", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert on ChangeRoadmap voting type when last voting is TerminateProject or TerminateProjectDecreasedQuorum with voting result not Decline", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(28 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new voting of type ChangeRoadmap", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.fulfilled;
		});

		it("should revert on ChangeRoadmapDecreasedQuorum voting type when last voting is not ChangeRoadmap or ChangeRoadmapDecreasedQuorum", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP_DECREASED_QUORUM, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert on ChangeRoadmapDecreasedQuorum voting type when last voting result is not QuorumNotReached or NoDecision", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(21 * 24 * 60 * 60);
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(28 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP_DECREASED_QUORUM, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new voting of type ChangeRoadmapDecreasedQuorum", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(21 * 24 * 60 * 60);
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(28 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_CHANGE_ROADMAP_DECREASED_QUORUM, {from: inverstorAddress}).should.be.fulfilled;
		});

		it("should revert on TerminateProject voting type when last voting is not: ReleaseTap, ReleaseTapDecreasedQuorum, ChangeRoadmap, ChangeRoadmapDecreasedQuorum", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(14 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert on TerminateProject voting type when last voting result is not Decline", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new voting of type TerminateProject", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
		});

		it("should revert on TerminateProjectDecreasedQuorum voting type when last voting is not TerminateProject or TerminateProjectDecreasedQuorum", async() => {
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT_DECREASED_QUORUM, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert on TerminateProjectDecreasedQuorum voting type when last voting result is not QuorumReached or NoDecision", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(14 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT_DECREASED_QUORUM, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new voting of type TerminateProjectDecreasedQuorum", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(2, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(14 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT_DECREASED_QUORUM, {from: inverstorAddress}).should.be.fulfilled;
		});
	});

	describe("createVotingByOwner()", () => {
		it("should revert if voting type is not release tap decreased quorum", async() => {
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if latest voting for particular tap is not finished", async() => {
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if latest voting is not ReleaseTap or ReleaseTapDecreasedQuorum", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await increaseTime(14 * 24 * 60 * 60);
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if latest voting result is not quorum not reached", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new voting createVotingByOwner", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByOwner(0, VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM, {from: evercityMemberAddress}).should.be.fulfilled;
		});
	});

	describe("getVotingResult()", () => {
		it("should return quorum not reached", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			assert.equal(new web3.BigNumber(await daico.getVotingResult(0)).toNumber(), VOTING_RESULT_QUORUM_NOT_REACHED);
		});

		it("should return accept", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			assert.equal(new web3.BigNumber(await daico.getVotingResult(0)).toNumber(), VOTING_RESULT_ACCEPT);
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

	describe("isProjectTerminated()", () => {
		it("should return false if project is not terminated", async() => {
			assert.equal(await daico.isProjectTerminated(), false);
		});

		it("should return true if project is terminated", async() => {
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress3}).should.be.fulfilled;
			assert.equal(await daico.isProjectTerminated(), true);
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

		it("should revert if it is too late to vote", async() => {
			const daicoNew = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, returnAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate);
			await increaseTime(7 * 24 * 60 * 60);
			await daicoNew.vote(0, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if project is terminated", async() => {
			// terminate project
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress3}).should.be.fulfilled;

			await daico.vote(2, false, {from: inverstorAddress5}).should.be.rejectedWith("revert");
		});

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

	describe("withdrawFunding()", () => {
		it("should revert if project is not terminated", async() => {
			await daico.withdrawFunding({from: evercityMemberAddress}).should.be.rejectedWith("revert");
		});

		it("should withdraw DAI tokens", async() => {
			// terminate project
			await daico.vote(0, false, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, false, {from: inverstorAddress3}).should.be.fulfilled;
			await increaseTime(7 * 24 * 60 * 60);
			await daico.createVotingByInvestor(0, VOTING_TYPE_TERMINATE_PROJECT, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstorAddress3}).should.be.fulfilled;
			// withdraw DAI tokens
			assert.equal(await daiToken.balanceOf(returnAddress), 0);
			await daico.withdrawFunding({from: evercityMemberAddress}).should.be.fulfilled;
			assert.equal(await daiToken.balanceOf(returnAddress), 3);
		});
	});

	describe("withdrawTapPayment()", () => {
		it("should revert if caller is not project owner", async() => {
			await daico.withdrawTapPayment(0, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if tap release is not accepted by investors", async() => {
			await daico.withdrawTapPayment(0, {from: projectOwnerAddress}).should.be.rejectedWith("revert");
		});

		it("should revert if tap is already withdrawn", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			await daico.withdrawTapPayment(0, {from: projectOwnerAddress}).should.be.fulfilled;
			await daico.withdrawTapPayment(0, {from: projectOwnerAddress}).should.be.rejectedWith("revert");
		});

		it("should create a new tap payment", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;
			await daico.withdrawTapPayment(0, {from: projectOwnerAddress}).should.be.fulfilled;
			
			const tapPayment = await daico.tapPayments(0);
			assert.equal(tapPayment[0], 1);
			assert.notEqual(tapPayment[1], 0);
			assert.equal(tapPayment[2], true);
		});

		it("should transfer DAI tokens to project owner", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress2}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress3}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstorAddress4}).should.be.fulfilled;

			assert.equal(await daiToken.balanceOf(projectOwnerAddress), 0);
			await daico.withdrawTapPayment(0, {from: projectOwnerAddress}).should.be.fulfilled;
			assert.equal(await daiToken.balanceOf(projectOwnerAddress), 1);
		});
	});

	describe("onlyInvestor()", () => {
		it("should revert if method is called not by investor", async() => {
			await daico.vote(0, true, {from: otherAddress}).should.be.rejectedWith("revert");
		});

		it("should call method that can be executed only by investor", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		});
	});

	describe("validTapIndex()", () => {
		it("should revert if tap index does not exist", async() => {
			await daico.isTapWithdrawAcceptedByInvestors(2).should.be.rejectedWith("revert");
		});

		it("should call method with valid tap index", async() => {
			await daico.isTapWithdrawAcceptedByInvestors(1).should.be.fulfilled;
		});
	});

	describe("validVotingIndex()", () => {
		it("should revert if voting index does not exist", async() => {
			await daico.vote(2, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should call method with valid tap index", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		});
	});	

});
