const CheckExceptions = require("./utils/checkexceptions");
const should = require("./utils/helpers");

const DaoBaseAuto = artifacts.require("DaoBaseAuto");
const DaoStorage = artifacts.require("DaoStorage");
const DaoBaseWithUnpackers = artifacts.require("DaoBaseWithUnpackers");

const GenericProposal = artifacts.require("GenericProposal");
const HierarchyDao = artifacts.require("HierarchyDao");
const HierarchyDaoFactory = artifacts.require("HierarchyDaoFactory");
const InformalProposal = artifacts.require("InformalProposal");
const StdDaoToken = artifacts.require("StdDaoToken");

contract('HierarchyDaoFactory', (accounts) => {
	const boss = accounts[0];
	const manager1 = accounts[1];
	const manager2 = accounts[2];
	const employee1 = accounts[3];
	const employee2 = accounts[4];
	const outsiderWithTokens = accounts[5];
	const outsiderWithoutTokens = accounts[6];

	let hierarchyDaoFactory;
	let daoBase;
	let store;
	let hierarchyDaoAuto;
	let informalProposal;
	let stdDaoToken;

	before(async () => {
		hierarchyDaoFactory = await HierarchyDaoFactory.new(boss, [manager1, manager2], [employee1, employee2], [outsiderWithTokens, outsiderWithoutTokens]);
		daoBase = DaoBaseWithUnpackers.at(await hierarchyDaoFactory.daoBase());
		store = DaoStorage.at(await hierarchyDaoFactory.store());
		hierarchyDaoAuto = DaoBaseAuto.at(await hierarchyDaoFactory.hierarchyDaoAuto());
		stdDaoToken = StdDaoToken.at(await hierarchyDaoFactory.token());
		informalProposal = await InformalProposal.new("ANY_TEXT");
	});

	it("boss should be a member of 2 groups: managers and employees", async () => {
		const isManager = await daoBase.isGroupMember("Managers", boss);
		const isEmployee = await daoBase.isGroupMember("Employees", boss);

		assert.isTrue(isManager, "boss should be in the managers group");
		assert.isTrue(isEmployee, "boss should be in the employees group");
	});

	it("boss should be able to issue new tokens", async() => {
		await daoBase.issueTokens(stdDaoToken.address, employee1, 100, { from: boss }).should.be.fulfilled;
		const employee1Balance = await stdDaoToken.balanceOf(employee1);
		assert.equal(employee1Balance, 100);
	});

	it("manager should be able to add new proposal", async () => {
		await daoBase.addNewProposal(informalProposal.address, { from: manager1 }).should.be.fulfilled;
	});

	it("manager should not be able to issue tokens", async() => {
		await CheckExceptions.checkContractThrows(
			daoBase.issueTokens, [stdDaoToken.address, employee1, 100, { from: manager1 }]
		);
	});

	it("boss should be able to manage groups only by voting", async () => {
		await hierarchyDaoAuto.addGroupMemberAuto("ANY_GROUP", employee1, { from: boss }).should.be.fulfilled;
	});

	it("manager should be able to manage groups only by voting", async () => {
		await hierarchyDaoAuto.addGroupMemberAuto("ANY_OTHER_GROUP", employee1, { from: manager1 }).should.be.fulfilled;
	});

	it("outsider (not in groups) with tokens should not be able to add new proposal", async () => {
		await daoBase.issueTokens(stdDaoToken.address, outsiderWithTokens, 100, { from: boss }).should.be.fulfilled;
		await CheckExceptions.checkContractThrows(
			daoBase.addNewProposal, [informalProposal.address, { from: outsiderWithTokens }]
		);
	});

	it("outsider (not in groups) without tokens should not be able to add new proposal", async () => {
		await CheckExceptions.checkContractThrows(
			daoBase.addNewProposal, [informalProposal.address, { from: outsiderWithoutTokens }]
		);
	});
	
});
