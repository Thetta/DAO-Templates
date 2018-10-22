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
	let devZenDaoAuto;
	let daoBase;

	beforeEach(async () => {
		devZenDaoFactory = await DevZenDaoFactory.new(boss, [teamMember1, teamMember2]);
		devZenDao = DevZenDao.at(await devZenDaoFactory.devZenDao());
		daoBase = DaoBase.at(await devZenDaoFactory.daoBase());
		devZenToken = StdDaoToken.at(await devZenDao.devZenToken());
		repToken = StdDaoToken.at(await devZenDao.repToken());
		devZenDaoAuto = DevZenDaoAuto.at(await devZenDaoFactory.devZenDaoAuto());
	});

	describe("addGroupMemberAuto()", () => {
		it("should add group member after successful voting", async() => {
			await devZenDaoAuto.addGroupMemberAuto("DevZenTeam", guest1, {from: boss}).should.be.fulfilled;
			
			const proposalAddress = await daoBase.getProposalAtIndex(0);
			const proposal = await IProposal.at(proposalAddress);
			const votingAddress = await proposal.getVoting();
			const voting = await IVoting.at(votingAddress);

			await voting.vote(true, {from: teamMember1});

			let members = await daoBase.getGroupMembers("DevZenTeam");
			console.log(members);
		});
	});

});