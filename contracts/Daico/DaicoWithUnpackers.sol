pragma solidity ^0.4.24;

import "./DaicoOld.sol";


contract DaicoWithUnpackers is DaicoOld {

	constructor(IDaoBase _daoBase, address[] _investors) DaicoOld(_daoBase, _investors) {

	}	
	
	function nextStageGeneric(bytes32[] _params) {
		address voting;
		uint projNum = uint(_params[0]);
		require(_params.length==2);

		voting = address(_params[1]);
		(uint yes, uint no, uint total) = IVoting(voting).getVotingStats();
		uint yesPercent = (yes*100)/total;
		
		if(yesPercent>70) {
			projects[projNum].goToNextStage();
		}else if(yesPercent>20) {
			uint blockUntil = uint(now) + 30*24*3600*1000;
			projects[projNum].setBlock(blockUntil);
		} else {
			projects[projNum].removeProject();
		}
	}
}