pragma solidity ^0.4.24;

import "@thetta/core/contracts/utils/GenericCaller.sol";
import "./DaicoWithUnpackers.sol";

contract DaicoAuto is GenericCaller {
	DaicoWithUnpackers public daico;

	constructor(IDaoBase _daoBase, DaicoWithUnpackers _daico) public GenericCaller(_daoBase){
		daico = _daico;
	}
}