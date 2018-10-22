pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/utils/UtilsLib.sol";
import "@thetta/core/contracts/DaoBase.sol";
import "./DevZenDao.sol";

contract DevZenDaoWithUnpackers is DevZenDao {
	constructor(IDaoBase _daoBase, address[] _tokens) public 
	DevZenDao(_daoBase, _tokens){}

	function updateDaoParamsGeneric(bytes32[] _params) external {
		bytes32 param = _params[0];
		uint value = uint(_params[1]);
		setParam(param, value);
	}

	function withdrawEtherGeneric(bytes32[] _params) external {
		address output = address(_params[0]);
		withdrawEther(output);
	}

	function selectNextHostGeneric(bytes32[] _params) external {
		address nextHost = address(_params[0]);
		selectNextHost(nextHost);
	}

	function changeTheGuestGeneric(bytes32[] _params) external {
		address guest = address(_params[0]);
		changeTheGuest(guest);
	}

	function emergency_ChangeTheGuestGeneric(bytes32[] _params) external {
		address guest = address(_params[0]);
		emergency_ChangeTheGuest(guest);
	}

	function moveToNextEpisodeGeneric(bytes32[] _params) external {
		uint guestHasCome = uint(_params[0]); // TypeError: Explicit type conversion not allowed from "bytes32" to "bool"
		moveToNextEpisode(guestHasCome==1);
	}

	function addGroupMemberGeneric(bytes32[] _params) external {
		string memory _groupName = UtilsLib.bytes32ToString(_params[0]);
		address a = address(_params[1]);
		_addGroupMember(_groupName, a);
	}
}
