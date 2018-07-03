const CheckExceptions = require("./utils/checkexceptions");
const should = require("./utils/helpers");

const BodDaoFactory = artifacts.require("BodDaoFactory");
const DaoBaseAuto = artifacts.require("DaoBaseAuto");
const DaoBaseWithUnpackers = artifacts.require("DaoBaseWithUnpackers");
const DaoStorage = artifacts.require("DaoStorage");
const GenericProposal = artifacts.require("GenericProposal");
const InformalProposal = artifacts.require("InformalProposal");
const Voting_1p1v = artifacts.require("Voting_1p1v");
const WeiTask = artifacts.require("WeiTask");

contract("BodDaoFactory", (accounts) => {

	const creator = accounts[0];
	const director1 = accounts[1];
	const director2 = accounts[2];
	const director3 = accounts[3];
	const employee1 = accounts[4];
	const employee2 = accounts[5];

	let bodDaoFactory;
	let store;
	let daoBase;
	let aac;
	let informalProposal;
	let weiTask;
	let voting;

	beforeEach(async () => {
		
		bodDaoFactory = await BodDaoFactory.new(creator, [director1, director2, director3], [employee1, employee2]);

		const daoBaseAddress = await bodDaoFactory.daoBase();
		daoBase = DaoBaseWithUnpackers.at(daoBaseAddress);

		const storeAddress = await bodDaoFactory.store();
		store = DaoStorage.at(storeAddress);

		const daoBaseAutoAddress = await bodDaoFactory.aac();
		aac = DaoBaseAuto.at(daoBaseAutoAddress);

		informalProposal = await InformalProposal.new("ANY_TEXT");
		
		weiTask = await WeiTask.new(daoBase.address, "ANY_CAPTION", "ANY_DESC", true, false, 100, Math.floor(Date.now() / 1000));

		// adding test proposal which creates a voting
		await aac.addGroupMemberAuto("ANY_GROUP", employee1, { from: director1 }).should.be.fulfilled;
		const proposalsCount = await store.getProposalsCount();
		const proposalAddress = await store.getProposalAtIndex(proposalsCount - 1);
		const genericProposal = GenericProposal.at(proposalAddress);
		const votingAddress = await genericProposal.getVoting();
		voting = Voting_1p1v.at(votingAddress);
	});

	it("BoD member should be able to add new proposal", async () => {
		await daoBase.addNewProposal(informalProposal.address, { from: director1 }).should.be.fulfilled;
	});

	it("employee should not be able to add new proposal", async () => {
		await CheckExceptions.checkContractThrows(
			daoBase.addNewProposal, [informalProposal.address, { from: employee1 }]
		);
	});

	it("employee should be able to start a new task", async () => {
		await weiTask.startTask(employee1, { from: employee1 }).should.be.fulfilled;
	});

	it("BoD member should be able to manage groups only by voting", async () => {
		await aac.addGroupMemberAuto("ANY_GROUP", employee1, { from: director1 }).should.be.fulfilled;
	});

	it("BoD member should be able to vote", async () => {
		await voting.vote(true, 0, { from: director2 }).should.be.fulfilled;
	});

	it("employee should not be able to vote", async () => {
		await CheckExceptions.checkContractThrows(
			voting.vote, [true, 0, { from: employee1 }]
		);
	});

	it("50% of persons in a group are required to vote to finish the voting", async () => {

		let isFinished = await voting.isFinished();
		assert.isFalse(isFinished, "half of the users in group has not voted yet");

		await voting.vote(false, 0, { from: director2 }).should.be.fulfilled;

		isFinished = await voting.isFinished();
		assert.isTrue(isFinished, "half of the users should have voted");
	});

	it("50% of 'yes' required to finish the voting with 'yes' result", async () => {

		let isYes = await voting.isYes();
		assert.isFalse(isYes, "half of the users in group has not voted for yes");

		await voting.vote(true, 0, { from: director2 }).should.be.fulfilled;

		isYes = await voting.isYes();
		assert.isTrue(isYes, "half of the users should have voted for yes");
	});

});
