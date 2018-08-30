pragma solidity ^0.4.24;
// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/utils/GenericCaller.sol";

import "./DevZenDao.sol";
import "./DevZenDaoCore.sol";

contract DevZenDaoAuto is GenericCaller{
	DevZenDaoCore devZenDao;
	constructor(IDaoBase _dao, DevZenDaoCore _devZenDao) public GenericCaller(_dao){
		devZenDao = _devZenDao;
	}

	bytes32 UPDATE_DAO_PARAMS = keccak256("updateDaoParams");
	bytes32 WITHDRAW_ETHER = keccak256("withdrawEther");
	bytes32 SELECT_NEXT_HOST = keccak256("selectNextHost");
	bytes32 CHANGE_GUEST = keccak256("changeGuest");
	bytes32 EMERGENCY_CHANGE_GUEST = keccak256("emergencyChangeGuest");
	bytes32 MOVE_TO_NEXT_EXPISODE = keccak256("moveToNextExpisode");

	// function updateDaoParamsAuto(DevZenDao.Params _params) public returns(address proposalOut) {
	// 	bytes32[] memory params = new bytes32[](1);
	// 	params[0] = bytes32(_params);
	//	return doAction(UPDATE_DAO_PARAMS, dao, msg.sender, "updateDaoParamsGeneric(bytes32[])", params);
	// }

	function withdrawEtherAuto(address _output) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_output);
		return doAction(WITHDRAW_ETHER, devZenDao, msg.sender, "withdrawEtherGeneric(bytes32[])", params);
	}

	function selectNextHostAuto(address _nextHost) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_nextHost);
		return doAction(SELECT_NEXT_HOST, devZenDao, msg.sender, "selectNextHostGeneric(bytes32[])", params);
	}

	function changeTheGuestAuto(address _guest) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);
		return doAction(CHANGE_GUEST, devZenDao, msg.sender, "changeTheGuestGeneric(bytes32[])", params);
	}

	function emergency_ChangeTheGuestAuto(address _guest) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);
		return doAction(EMERGENCY_CHANGE_GUEST, devZenDao, msg.sender, "emergency_ChangeTheGuestGeneric(bytes32[])", params);
	}

	function moveToNextEpisodeAuto(bool _guestHasCome) public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](1);
		if(_guestHasCome){
			params[0] = bytes32(1);
		}else{
			params[0] = bytes32(0);
		}
		return doAction(MOVE_TO_NEXT_EXPISODE, devZenDao, msg.sender, "moveToNextExpisodeGeneric(bytes32[])", params);
	}

	function burnGuestStakeAuto() isCanDo("DevZen_burnGuestStake") public returns(address proposalOut) {
		bytes32[] memory params = new bytes32[](0);
		return doAction(MOVE_TO_NEXT_EXPISODE, devZenDao, msg.sender, "moveToNextExpisodeGeneric(bytes32[])", params);
	}
}
