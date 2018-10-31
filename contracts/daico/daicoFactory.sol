pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
// pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoBase.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/DaoStorage.sol";
import "@thetta/core/contracts/DaoBaseAuto.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "@thetta/core/contracts/utils/UtilsLib.sol";

// import "./DaicoProject.sol";
// import "./Daico.sol";
import "./DaicoWithUnpackers.sol";
import "./DaicoAuto.sol";


contract DaicoFactory {
	DaicoWithUnpackers public daico;
	DaoBase public daoBase;
	DaoStorage public store;
	DaicoAuto public daicoAuto;

	constructor(address[] _investors) {
		createDaico(_investors);
		// setupAutoMethods();
		// daoBase.renounceOwnership();
	}

	function createDaico(address[] _investors) {
		StdDaoToken daicoToken = new StdDaoToken("DaicoToken", "DAICO", 18, true, true, 10**25);

		address[] tokens;
		tokens.push(address(daicoToken));
		// store = new DaoStorage(tokens);
		// daoBase = new DaoBase(store);

		// daico = new DaicoWithUnpackers(IDaoBase(daoBase), _investors);
		
		// store.allowActionByAddress(daoBase.MANAGE_GROUPS(),address(this));
		// store.allowActionByAddress(daoBase.ISSUE_TOKENS(),address(daico));
		// store.allowActionByAddress(daoBase.BURN_TOKENS(),address(daico));
		// store.transferOwnership(daoBase);

		// daicoToken.transferOwnership(daoBase);

		// for(uint i=0; i<_investors.length; ++i){
		// 	daoBase.addGroupMember("Investors", _investors[i]);
		// }

		// // 1 - set investors group permissions
		// daoBase.allowActionByAnyMemberOfGroup(daoBase.ADD_NEW_PROPOSAL(),"Investors");
		// daoBase.allowActionByVoting(daoBase.MANAGE_GROUPS(), daicoToken);

		// // 2 - set custom investors permissions
		// daoBase.allowActionByVoting(daico.NEXT_STAGE(), daico.daicoToken());
	}	

	function setupAutoMethods() internal {
		// TODO: add all custom actions to the DaoBaseAuto derived contract
		// daicoAuto = new DaicoAuto(IDaoBase(daoBase), daico);

		// daoBase.allowActionByAddress(daoBase.ADD_NEW_PROPOSAL(), daicoAuto);
		// daoBase.allowActionByAddress(daoBase.MANAGE_GROUPS(), daicoAuto);
		// daoBase.allowActionByAddress(daoBase.UPGRADE_DAO_CONTRACT(), daicoAuto);
		// // daoBase.allowActionByAddress(daico.NEXT_STAGE(), daicoAuto);

		// uint VOTING_TYPE_1P1V = 1;
		// daicoAuto.setVotingParams(daoBase.MANAGE_GROUPS(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("Investors"), bytes32(70), bytes32(70), bytes32(24*7));
		// daicoAuto.setVotingParams(daoBase.UPGRADE_DAO_CONTRACT(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("Investors"), bytes32(70), bytes32(70), bytes32(24*7));
		// daicoAuto.setVotingParams(daico.NEXT_STAGE(), VOTING_TYPE_1P1V, bytes32(0), UtilsLib.stringToBytes32("Investors"), bytes32(0), bytes32(0), bytes32(24*7));

		// daicoAuto.transferOwnership(daoBase);
	}
}