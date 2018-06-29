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
        address _manager, 
        address _employee, 
        address _outsiderWithTokens, 
        address _outsiderWithoutTokens
    ) public {
		createDao(_boss, _manager, _employee, _outsiderWithTokens, _outsiderWithoutTokens);
        setupAac();
	}
    
	function createDao(
        address _boss, 
        address _manager, 
        address _employee, 
        address _outsiderWithTokens, 
        address _outsiderWithoutTokens
    ) internal returns(address) {

		// create token
		token = new StdDaoToken("StdToken", "STDT", 18);
		tokens.push(address(token));

        // send outsider some tokens for testing purposes
        token.mint(_outsiderWithTokens, 1);
		
        // create dao
		store = new DaoStorage(tokens);
		dao = new DaoBaseWithUnpackers(store);

		store.allowActionByAddress(keccak256("manageGroups"), address(this));

		token.transferOwnership(dao);
		store.transferOwnership(dao);

		// set permissions
		setPermissions(_boss, _manager, _employee);

		// return dao address
		dao.transferOwnership(msg.sender);
		return dao;
	}

	function setPermissions(address _boss, address _manager, address _employee) internal {

		dao.addGroupMember("Managers", _boss);
		dao.addGroupMember("Employees", _boss);
        dao.addGroupMember("Managers", _manager);
        dao.addGroupMember("Employees", _employee);

        dao.allowActionByAddress("issueTokens", _boss); 
        dao.allowActionByAnyMemberOfGroup("addNewProposal", "Managers");

        dao.allowActionByVoting("manageGroups", token);
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