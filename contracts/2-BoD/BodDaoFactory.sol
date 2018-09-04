pragma solidity ^0.4.24;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/DaoBaseWithUnpackers.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/DaoStorage.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "@thetta/core/contracts/utils/UtilsLib.sol";
import "@thetta/core/contracts/tasks/WeiGenericTask.sol";

import "./BodDao.sol";

contract BodDaoFactory {
	DaoBaseWithUnpackers public daoBase;
	DaoBaseAuto public bodDaoAuto;
	DaoStorage public store;
	StdDaoToken public token;
	BodDao public bodDao;

	address[] tokens;

	constructor(address _creator, address[] _directors, address[] _employees) public {
		createDao(_creator, _directors, _employees);
		setupBodDaoAuto();
		daoBase.renounceOwnership();
	}

	function createDao(address _creator, address[] _directors, address[] _employees) internal {
		// 1 - create
		token = new StdDaoToken("StdToken", "STDT", 18, true, true, 10**25);
		tokens.push(address(token));
		store = new DaoStorage(tokens);
		daoBase = new DaoBaseWithUnpackers(store);
		bodDao = new BodDao(IDaoBase(daoBase));

		store.allowActionByAddress(daoBase.MANAGE_GROUPS(), address(this));

		token.transferOwnership(daoBase);
		store.transferOwnership(daoBase);
		// 2 - setup

		// 1 - creator is in BoD initially
		daoBase.addGroupMember("BoD", _creator);
		daoBase.addGroupMember("Employees", _creator);

		// 2 - set BoD group permissions
		daoBase.allowActionByAnyMemberOfGroup(daoBase.ADD_NEW_PROPOSAL(), "BoD");

		// 4 - the rest is by voting only (requires addNewProposal permission)
		daoBase.allowActionByVoting(daoBase.MANAGE_GROUPS(), token);
		daoBase.allowActionByVoting(daoBase.ISSUE_TOKENS(), token);
		daoBase.allowActionByVoting(daoBase.UPGRADE_DAO_CONTRACT(), token);

		// 5 - populate groups
		uint i = 0;
		for(i = 0; i < _directors.length; ++i){
			daoBase.addGroupMember("BoD", _directors[i]);
		}

		for(i = 0; i < _employees.length; ++i){
			daoBase.addGroupMember("Employees", _employees[i]);
		}
	}

	function setupBodDaoAuto() internal {
		bodDaoAuto = new DaoBaseAuto(daoBase);

		uint VOTING_TYPE_1P1V = 1;
		bodDaoAuto.setVotingParams(daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("BoD"), bytes32(49), bytes32(49), 0);
		bodDaoAuto.setVotingParams(daoBase.ISSUE_TOKENS(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("BoD"), bytes32(49), bytes32(49), 0);
		bodDaoAuto.setVotingParams(daoBase.UPGRADE_DAO_CONTRACT(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("BoD"), bytes32(49), bytes32(49), 0);
		
		daoBase.allowActionByAddress(daoBase.MANAGE_GROUPS(), bodDaoAuto);
		daoBase.allowActionByAddress(daoBase.ISSUE_TOKENS(), bodDaoAuto);
		daoBase.allowActionByAddress(daoBase.ADD_NEW_PROPOSAL(), bodDaoAuto);

		bodDaoAuto.transferOwnership(msg.sender);
	}

}
