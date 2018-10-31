pragma solidity ^0.4.24;

import "@thetta/core/contracts/utils/GenericCaller.sol";
import "./DaicoWithUnpackers.sol";


contract DaicoAuto is GenericCaller {
	DaicoWithUnpackers public daico;

	constructor(IDaoBase _daoBase, DaicoWithUnpackers _daico) public GenericCaller(_daoBase){
		daico = _daico;
	}

	function nextStageAuto(uint _projectNum) public returns(address) {
		// require(projects[_projectNum].projectState()==DaicoProject.ProjectState.Basic);
		bytes32[] memory params = new bytes32[](1);
		params[0] = bytes32(_projectNum);
		return doAction(daico.NEXT_STAGE(), daico, msg.sender, "nextStageGeneric(bytes32[])", params);
	}
}