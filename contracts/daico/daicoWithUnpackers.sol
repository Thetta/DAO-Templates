pragma solidity ^0.4.24;

import "./Daico.sol";


contract DaicoWithUnpackers is Daico {

	constructor(IDaoBase _daoBase, address[] _investors) Daico(_daoBase, _investors) {

	}	
	
}