pragma solidity ^0.4.24;
// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/utils/GenericCaller.sol";

import "./DevZenDao.sol";
import "./DevZenDaoCore.sol";
import "./DevZenDaoWithUnpackers.sol";

contract DevZenDaoAuto is GenericCaller{
	event UpdateDaoParamsAuto();
	event WithdrawEtherAuto();
	event SelectNextHostAuto();
	event ChangeTheGuestAuto();
	event Emergency_ChangeTheGuestAuto();
	event MoveToNextEpisodeAuto();
	event BurnGuestStakeAuto();

	DevZenDaoWithUnpackers devZenDao;
	constructor(IDaoBase _dao, DevZenDaoWithUnpackers _devZenDao) public GenericCaller(_dao){
		devZenDao = _devZenDao;
	}

	// function updateDaoParamsAuto(DevZenDao.Params _params) public returns(address proposalOut) {
	// emit UpdateDaoParamsAuto();
	// 	bytes32[] memory params = new bytes32[](1);
	// 	params[0] = bytes32(_params);
	//	return doAction(devZenDao.DEV_ZEN_UPDATE_DAO_PARAMS(), dao, msg.sender, "updateDaoParamsGeneric(bytes32[])", params);
	// }

	function withdrawEtherAuto(address _output) public returns(address proposalOut) {
		emit WithdrawEtherAuto();
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_output);
		return doAction(devZenDao.DEV_ZEN_WITHDRAW_ETHER(), devZenDao, msg.sender, "withdrawEtherGeneric(bytes32[])", params);
	}

	function selectNextHostAuto(address _nextHost) public returns(address proposalOut) {
		emit SelectNextHostAuto();
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_nextHost);
		return doAction(devZenDao.DEV_ZEN_SELECT_NEXT_HOST(), devZenDao, msg.sender, "selectNextHostGeneric(bytes32[])", params);
	}

	function changeTheGuestAuto(address _guest) public returns(address proposalOut) {
		emit ChangeTheGuestAuto();
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);
		return doAction(devZenDao.DEV_ZEN_CHANGE_GUEST(), devZenDao, msg.sender, "changeTheGuestGeneric(bytes32[])", params);
	}

	function emergency_ChangeTheGuestAuto(address _guest) public returns(address proposalOut) {
		emit Emergency_ChangeTheGuestAuto();
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_guest);
		return doAction(devZenDao.DEV_ZEN_EMERGENCY_CHANGE_GUEST(), devZenDao, msg.sender, "emergency_ChangeTheGuestGeneric(bytes32[])", params);
	}

	function moveToNextEpisodeAuto(bool _guestHasCome) public returns(address proposalOut) {
		emit MoveToNextEpisodeAuto();
		bytes32[] memory params = new bytes32[](1);
		if(_guestHasCome){
			params[0] = bytes32(1);
		}else{
			params[0] = bytes32(0);
		}
		return doAction(devZenDao.DEV_ZEN_MOVE_TO_NEXT_EPISODE(), devZenDao, msg.sender, "moveToNextEpisodeGeneric(bytes32[])", params);
	}

	function burnGuestStakeAuto() public returns(address proposalOut) {
		emit BurnGuestStakeAuto();
		bytes32[] memory params = new bytes32[](0);
		return doAction(devZenDao.DEV_ZEN_BURN_GUEST_STAKE(), devZenDao, msg.sender, "burnGuestStakeGeneric(bytes32[])", params);
	}
}
