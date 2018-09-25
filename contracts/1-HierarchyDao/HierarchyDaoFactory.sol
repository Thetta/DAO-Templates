pragma solidity ^0.4.24;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoBaseWithUnpackers.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/DaoStorage.sol";
import "@thetta/core/contracts/utils/UtilsLib.sol";
import "@thetta/core/contracts/governance/InformalProposal.sol";
import "./HierarcyDao.sol";

contract HierarchyDaoFactory {
	DaoStorage public store;
	StdDaoToken public token;
	DaoBaseWithUnpackers public daoBase;
	HierarchyDao public hierarcyDao;
	DaoBaseAuto public hierarchyDaoAuto;

	constructor(
		address _boss, 
		address[] _managers, 
		address[] _employees, 
		address[] _outsiders
	) public {
		createDao(_boss, _managers, _employees, _outsiders);
		setupHierarchyDaoAuto();
		daoBase.renounceOwnership();
	}
	
	function createDao(
		address _boss, 
		address[] _managers,
		address[] _employees,
		address[] _outsiders
	) internal {
		// 1 - create
		token = new StdDaoToken("StdToken", "STDT", 18, true, false, 10**25);
		address[] tokens;
		tokens.push(address(token));
		store = new DaoStorage(tokens);
		daoBase = new DaoBaseWithUnpackers(store);
		hierarcyDao = new HierarchyDao(IDaoBase(daoBase));

		store.allowActionByAddress(daoBase.MANAGE_GROUPS(), address(this));
		store.transferOwnership(daoBase);
		token.transferOwnership(daoBase);

		setPermissions(_boss, _managers, _employees);
	}

	function setPermissions(address _boss, address[] _managers, address[] _employees) internal {

		// 1 - grant all permissions to the boss
		daoBase.addGroupMember("Managers", _boss);
		daoBase.addGroupMember("Employees", _boss);

		daoBase.allowActionByAddress(daoBase.ISSUE_TOKENS(), _boss); 
		daoBase.allowActionByAddress(daoBase.UPGRADE_DAO_CONTRACT(), _boss);

		// 2 - set managers group permission
		daoBase.allowActionByAnyMemberOfGroup(daoBase.ADD_NEW_PROPOSAL(), "Managers");

		// 4 - the rest is by voting only (requires addNewProposal permission)
		// so accessable by Managers only even with voting
		daoBase.allowActionByVoting(daoBase.MANAGE_GROUPS(), token);

		// 5 - populate groups
		uint i = 0;
		for(i = 0; i < _managers.length; ++i) {
			daoBase.addGroupMember("Managers", _managers[i]);
		}
		for(i = 0; i < _employees.length; ++i){
			daoBase.addGroupMember("Employees", _employees[i]);
		}

	}

	function setupHierarchyDaoAuto() internal {
		hierarchyDaoAuto = new DaoBaseAuto(daoBase);

		// set voring params 1 person 1 vote
		uint8 VOTING_TYPE_1P1V = 1;
		hierarchyDaoAuto.setVotingParams(daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("Managers"), bytes32(50), bytes32(50), 0);

		daoBase.allowActionByAddress(daoBase.ADD_NEW_PROPOSAL(), hierarchyDaoAuto);
		daoBase.allowActionByAddress(daoBase.MANAGE_GROUPS(), hierarchyDaoAuto);

		hierarchyDaoAuto.transferOwnership(msg.sender);
	}
}