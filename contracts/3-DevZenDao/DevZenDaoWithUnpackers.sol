pragma solidity ^0.4.22;
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/utils/UtilsLib.sol";
import "@thetta/core/contracts/DaoBase.sol";
import "./DevZenDao.sol";

contract DevZenDaoWithUnpackers is DevZenDao {
	constructor(address[] _tokens, Params _params) public 
	DevZenDao(_tokens, _params){}

	// function updateDaoParamsGeneric(bytes32[] _params) external {
	// 	address params = address(_params[0]);
	// 	updateDaoParams(params);
	// }

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

	function burnGuestStakeGeneric(bytes32[] _params) external {
		burnGuestStake();
	}


}
