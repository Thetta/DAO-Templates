const CheckExceptions = require("./utils/checkexceptions");

const DaoBaseAuto = artifacts.require("DaoBaseAuto");
const DaoBaseWithUnpackers = artifacts.require("DaoBaseWithUnpackers");
const DaoStorage = artifacts.require("DaoStorage");
const GenericProposal = artifacts.require("GenericProposal");
const HierarchyDao = artifacts.require("HierarchyDao");
const InformalProposal = artifacts.require("InformalProposal");
const StdDaoToken = artifacts.require("StdDaoToken");

contract('HierarchyCompany', (accounts) => {

    const DEFAULT_GAS = 100000000;

	const boss = accounts[0];
	const manager = accounts[1];
    const employee = accounts[2];
    const outsiderWithTokens = accounts[3];
    const outsiderWithoutTokens = accounts[4];

    let company;
    let daoBase;
    let store;
    let aac;
    let informalProposal;
    let stdDaoToken;

	before(async () => {

        company = await HierarchyDao.new(boss, manager, employee, outsiderWithTokens, outsiderWithoutTokens, { gas: DEFAULT_GAS });

        const daoBaseAddress = await company.dao();
        daoBase = DaoBaseWithUnpackers.at(daoBaseAddress);

        const storeAddress = await daoBase.store();
        store = DaoStorage.at(storeAddress);

        const aacAddress = await company.aac();
        aac = DaoBaseAuto.at(aacAddress);

        const stdDaoTokenAddress = await company.token();
        stdDaoToken = StdDaoToken.at(stdDaoTokenAddress);

        informalProposal = await InformalProposal.new("ANY_TEXT");
	});

    it("boss should be a member of 2 groups: managers and employees", async () => {
        const isManager = await store.isGroupMember(web3.sha3("Managers"), boss);
        const isEmployee = await store.isGroupMember(web3.sha3("Employees"), boss);

        assert.isTrue(isManager, "boss should be in the managers group");
        assert.isTrue(isEmployee, "boss should be in the employees group");
    });

    it("boss should be able to issue new tokens", async() => {
        await daoBase.issueTokens(stdDaoToken.address, employee, 1, { from: boss });
    });

    it("manager should be able to add new proposal", async () => {
        await daoBase.addNewProposal(informalProposal.address, { from: manager });
    });

    it("manager should not be able to issue tokens", async() => {
        await CheckExceptions.checkContractThrows(
            daoBase.issueTokens, [stdDaoToken.address, employee, 1, { from: manager }]
        );
    });

    it("boss should be able to manage groups only by voting", async () => {
        await aac.addGroupMemberAuto("ANY_GROUP", employee, { from: boss });
    });

    it("manager should be able to manage groups only by voting", async () => {
        await aac.addGroupMemberAuto("ANY_OTHER_GROUP", employee, { from: manager });
    });

    it("outsider (not in groups) with tokens should not be able to add new proposal", async () => {
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
