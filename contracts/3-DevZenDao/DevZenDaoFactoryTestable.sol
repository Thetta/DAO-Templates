pragma solidity ^0.4.22;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "./DevZenDaoFactory.sol";
import "./DevZenDaoTestable.sol";

contract DevZenDaoFactoryTestable is DevZenDaoFactory {

	constructor(address _boss, address[] _devZenTeam) DevZenDaoFactory(_boss, _devZenTeam) public {}

	function createNewContract(StdDaoToken _devZenToken, StdDaoToken _repToken, DaoStorage _store, DevZenDao.Params _defaultParams) internal {
		dao = new DevZenDaoTestable(_devZenToken, _repToken, _store, _defaultParams);
	}

}
