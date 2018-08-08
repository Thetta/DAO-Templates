pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "./DevZenDaoFactory.sol";
import "./DevZenDaoTestable.sol";

contract DevZenDaoFactoryTestable is DevZenDaoFactory {

	constructor(address _boss, address[] _devZenTeam) DevZenDaoFactory(_boss, _devZenTeam) public {}

	function createNewContract(address[] _tokens, DevZenDao.Params _defaultParams) internal {
		dao = new DevZenDaoTestable(_tokens, _defaultParams);
	}

}
