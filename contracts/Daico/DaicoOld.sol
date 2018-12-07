pragma solidity ^0.4.24;

// to enable Params passing to constructor and method
pragma experimental ABIEncoderV2;

import "@thetta/core/contracts/DaoClient.sol";
import "@thetta/core/contracts/IDaoBase.sol";
import "@thetta/core/contracts/tokens/StdDaoToken.sol";
import "./DaicoProject.sol";


contract DaicoOld is DaoClient {
	mapping(uint => DaicoProject) public projects;
	uint projectsCount;
	address[] public investors;

	bytes32 public NEXT_STAGE = keccak256("nextStage");

	constructor(IDaoBase _daoBase, address[] _investors) DaoClient(_daoBase) {
		investors = _investors;
	}

	function addNewProject(uint _stagesCount, uint _stageAmount) {
		DaicoProject project = new DaicoProject(_stagesCount, _stageAmount, msg.sender, address(this));
		projects[projectsCount] = project;
		projectsCount++;
	}

	function addAmountToFund() public payable {}

}