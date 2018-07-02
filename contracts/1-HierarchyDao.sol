pragma solidity ^0.4.24;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";

contract HierarchyDao {

	StdDaoToken public token;
	DaoStorage store;

	DaoBaseWithUnpackers public dao;
	DaoBaseAuto public aac;

	address[] tokens;

	constructor(
		address _boss, 
		address[] _managers, 
		address[] _employees, 
		address[] _outsiders
	) public {
		createDao(_boss, _managers, _employees, _outsiders);
		setupAac();
	}
	
	function createDao(
		address _boss, 
		address[] _managers,
		address[] _employees,
		address[] _outsiders
	) internal returns(address) {

		// create token
		token = new StdDaoToken("StdToken", "STDT", 18);
		tokens.push(address(token));
		
		// create dao
		store = new DaoStorage(tokens);
		dao = new DaoBaseWithUnpackers(store);

		store.allowActionByAddress(keccak256("manageGroups"), address(this));

		token.transferOwnership(dao);
		store.transferOwnership(dao);

		// set permissions
		setPermissions(_boss, _managers, _employees);

		// return dao address
		dao.transferOwnership(msg.sender);
		return dao;
	}

	function setPermissions(address _boss, address[] _managers, address[] _employees) internal {

		// 1 - grant all permissions to the boss
		dao.addGroupMember("Managers", _boss);
		dao.addGroupMember("Employees", _boss);

		// 2 - set boss permissons
		dao.allowActionByAddress("issueTokens", _boss); 
		dao.allowActionByAddress("upgradeDaoContract", _boss);

		// 3 - set managers group permission
		dao.allowActionByAnyMemberOfGroup("addNewProposal", "Managers");
		dao.allowActionByAnyMemberOfGroup("addNewTask", "Managers");
		dao.allowActionByAnyMemberOfGroup("startTask", "Managers");
		dao.allowActionByAnyMemberOfGroup("startBounty", "Managers");

		// 4 - set employees group permissions
		dao.allowActionByAnyMemberOfGroup("startTask", "Employees");
		dao.allowActionByAnyMemberOfGroup("startBounty", "Employees");

		// 5 - the rest is by voting only (requires addNewProposal permission)
		// so accessable by Managers only even with voting
		dao.allowActionByVoting("manageGroups", token);

		// 6 - populate groups
		uint i = 0;
		for(i = 0; i < _managers.length; ++i) {
			dao.addGroupMember("Managers", _managers[i]);
		}
		for(i = 0; i < _employees.length; ++i){
			dao.addGroupMember("Employees", _employees[i]);
		}

	}

	function setupAac() internal {

		aac = new DaoBaseAuto(dao);

		// set voring params 1 person 1 vote
		uint8 VOTING_TYPE_1P1V = 1;
		aac.setVotingParams("manageGroups", VOTING_TYPE_1P1V, bytes32(0), "Managers", bytes32(50), bytes32(50), 0);

		dao.allowActionByAddress("addNewProposal", aac);
		dao.allowActionByAddress("manageGroups", aac);

		aac.transferOwnership(msg.sender);
	}
	
}