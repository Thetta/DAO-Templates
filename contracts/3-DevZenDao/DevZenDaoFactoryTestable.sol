pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "./DevZenDaoFactory.sol";
import "./DevZenDaoTestable.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "./DevZenDaoWithUnpackersTestable.sol";
contract DevZenDaoFactoryTestable is DevZenDaoFactory {

	constructor(address _boss, address[] _devZenTeam) DevZenDaoFactory(_boss, _devZenTeam) public {}

	function createNewContract(IDaoBase _daoBase, address[] _tokens, DevZenDao.Params _defaultParams) internal {
		devZenDao = new DevZenDaoWithUnpackersTestable(_daoBase, _tokens, _defaultParams);
	}

}